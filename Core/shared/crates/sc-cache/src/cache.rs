use std::future::Future;
use std::path::{Path, PathBuf};
use std::pin::Pin;
use std::sync::Arc;
use std::sync::atomic::{AtomicU64, Ordering};

use crate::manage::LikesState;

use bytes::{Bytes, BytesMut};
use futures::StreamExt;

use sc_domain::Urn;
use sc_net::{HttpRequest, NetClient, NetStream, SessionSource};
use sc_raw::{Progress, RawClient};

use crate::CacheError;
use crate::inventory::{CACHE_EXT, CACHE_PREFIX};
use crate::transcode;

/// Источник-кандидат в гонке `/stream` (premium ∥ public).
type BytesFuture<'a> = Pin<Box<dyn Future<Output = Result<Bytes, String>> + Send + 'a>>;

/// Базовые URL наших стриминговых сервисов. По умолчанию — прод scdinternal.
#[derive(Clone, Debug)]
pub struct StreamingConfig {
    pub storage_base: String,
    pub stream_base: String,
    pub stream_premium_base: String,
    pub hq: bool,
}

impl Default for StreamingConfig {
    fn default() -> Self {
        Self {
            storage_base: "https://storage.scdinternal.site".to_owned(),
            stream_base: "https://stream.scdinternal.site".to_owned(),
            stream_premium_base: "https://stream-star.scdinternal.site".to_owned(),
            hq: false,
        }
    }
}

/// Доказательство, что на диске лежит валидный m4a. Выдаётся только кэшем.
pub struct M4aFile {
    path: PathBuf,
}

impl M4aFile {
    pub fn path(&self) -> &Path {
        &self.path
    }
}

pub struct TrackCache {
    net: Arc<NetClient>,
    raw: Arc<RawClient>,
    dir: PathBuf,
    streaming: StreamingConfig,
    /// Токен API для НАШИХ стрим/storage-хостов (премиум-гейтинг). sc-net токенов
    /// не знает — навешиваем здесь, только на свои хосты (не на anon SC).
    session: Arc<dyn SessionSource>,
    pub(crate) likes: Arc<LikesState>,
}

impl TrackCache {
    pub fn new(
        net: Arc<NetClient>,
        raw: Arc<RawClient>,
        cache_dir: impl Into<PathBuf>,
        streaming: StreamingConfig,
        session: Arc<dyn SessionSource>,
    ) -> Self {
        Self {
            net,
            raw,
            dir: cache_dir.into(),
            streaming,
            session,
            likes: Arc::new(LikesState::default()),
        }
    }

    /// Локальный m4a для воспроизведения: защищённый кэш лайков → обычный кэш →
    /// скачать (наши источники → anon SC) и привести к m4a. [`progress`] (опц.)
    /// получает долю скачки 0..1 — транскод прогресса не даёт (как в Tauri).
    pub async fn ensure(
        &self,
        urn: &Urn,
        progress: Option<Progress<'_>>,
    ) -> Result<M4aFile, CacheError> {
        let liked = self.liked_path(urn);
        if is_valid_m4a(&liked).await {
            return Ok(M4aFile { path: liked });
        }
        self.ensure_at(urn, self.cache_path(urn), progress).await
    }

    /// Скачать трек в защищённый кэш лайков (`liked/`) — он не вытесняется
    /// лимитом аудиокэша ([`enforce_limit`]). Для bulk-кэша лайков.
    pub async fn ensure_liked(
        &self,
        urn: &Urn,
        progress: Option<Progress<'_>>,
    ) -> Result<M4aFile, CacheError> {
        self.ensure_at(urn, self.liked_path(urn), progress).await
    }

    async fn ensure_at(
        &self,
        urn: &Urn,
        output: PathBuf,
        progress: Option<Progress<'_>>,
    ) -> Result<M4aFile, CacheError> {
        if is_valid_m4a(&output).await {
            return Ok(M4aFile { path: output });
        }
        let bytes = self.fetch_source(urn, progress).await?;
        self.materialize(&bytes, &output).await?;
        // Инвариант m4a-only: sc-audio (symphonia) падает «format not recognized»
        // на не-mp4. Гарантируем валидный m4a ПЕРЕД отдачей, иначе внятная ошибка.
        if !is_valid_m4a(&output).await {
            let _ = tokio::fs::remove_file(&output).await;
            return Err(CacheError::InvalidOutput);
        }
        Ok(M4aFile { path: output })
    }

    /// Прогреть ffmpeg в фоне на старте — чтобы первое воспроизведение не
    /// блокировалось загрузкой бинарника посреди стрима (как в Tauri:
    /// `acquire_ffmpeg` зовётся на init). Идемпотентно, не падает.
    pub fn prepare(&self) {
        tokio::task::spawn_blocking(|| {
            if let Err(e) = transcode::ensure_ffmpeg() {
                eprintln!("[sc-cache] ffmpeg prefetch failed (will retry on first transcode): {e}");
            }
        });
    }

    /// Путь к каноничному файлу трека (`soundcloud_tracks_<id>.m4a`).
    pub(crate) fn cache_path(&self, urn: &Urn) -> PathBuf {
        self.dir.join(format!("{CACHE_PREFIX}{}{CACHE_EXT}", urn.bare()))
    }

    /// Каталог защищённого кэша лайков (`<cache>/liked`) — не вытесняется лимитом.
    pub(crate) fn liked_dir(&self) -> PathBuf {
        self.dir.join("liked")
    }

    /// Путь к файлу трека в защищённом кэше лайков.
    pub(crate) fn liked_path(&self, urn: &Urn) -> PathBuf {
        self.liked_dir()
            .join(format!("{CACHE_PREFIX}{}{CACHE_EXT}", urn.bare()))
    }

    pub(crate) fn dir(&self) -> &Path {
        &self.dir
    }

    /// Цепочка источников 1:1 с Tauri `track_cache/state.rs::download_with_fallback`
    /// (storage `/redirect` 307→S3 → storage stream → `/stream` premium ∥ public →
    /// anon SC). Первый успех выигрывает; иначе агрегированная ошибка всплывает
    /// (НЕ глотаем). `x-session-id` навешивает декоратор `sc-net`.
    async fn fetch_source(
        &self,
        urn: &Urn,
        progress: Option<Progress<'_>>,
    ) -> Result<Bytes, CacheError> {
        let full = urn.as_str();
        let storage_file = full.replace(':', "_");
        let encoded = urlencoding::encode(full);
        let hq = self.streaming.hq;
        let mut errors: Vec<String> = Vec::new();

        // Порядок как в Tauri: сперва наш storage (если трек залит на S3 — мгновенно),
        // затем anon-SC напрямую (быстрый путь для НЕ-залитых треков), и только в
        // конце медленный /stream (там бэк сам качает с SC — может быть минуты).

        // 1. storage redirect: быстрый 307 на presigned S3 (если трек залит).
        let redirect = format!("{}/redirect/{storage_file}.m4a", self.streaming.storage_base);
        match self.download_url(&redirect, progress).await {
            Ok(bytes) => return Ok(bytes),
            Err(e) => errors.push(format!("storage-redirect: {e}")),
        }

        // 2. anon SoundCloud напрямую (apiv2): для треков НЕ на S3 — быстрый путь
        //    (десктоп достаёт SC сам), РАНЬШЕ медленного /stream.
        match self.fetch_anon(urn, progress).await {
            Ok(bytes) => return Ok(bytes),
            Err(e) => errors.push(format!("anon: {e}")),
        }

        // 3. storage stream: проксируем байты через storage-сервер.
        let stream = format!("{}/{storage_file}.m4a", self.streaming.storage_base);
        match self.download_url(&stream, progress).await {
            Ok(bytes) => return Ok(bytes),
            Err(e) => errors.push(format!("storage-stream: {e}")),
        }

        // 4. /stream premium ∥ public — гонка (бэк сам резолвит права и качает с
        //    SC, может быть долго) — последний резерв.
        let premium = format!("{}/stream/{encoded}?hq={hq}", self.streaming.stream_premium_base);
        let public = format!("{}/stream/{encoded}?hq={hq}", self.streaming.stream_base);
        match self.race_streams(&premium, &public, progress).await {
            Ok(bytes) => return Ok(bytes),
            Err(e) => errors.push(format!("stream: {e}")),
        }

        Err(CacheError::NoSource(errors.join("; ")))
    }

    /// Один источник-URL потоком: 2xx с непустым телом → байты (с прогрессом по
    /// `content-length`), иначе ошибка с причиной.
    async fn download_url(
        &self,
        url: &str,
        progress: Option<Progress<'_>>,
    ) -> Result<Bytes, String> {
        // Наши стрим/storage-хосты гейтят премиум по x-session-id — навешиваем
        // токен здесь (sc-net его не знает). На anon SC (через sc-raw) не идёт.
        let mut req = HttpRequest::get(url.to_owned());
        if let Some(token) = self.session.session_id() {
            req = req.header("x-session-id", token);
        }
        let stream = self.net.download(req).await.map_err(|e| e.to_string())?;
        collect_stream(stream, progress).await
    }

    /// Гонка premium ∥ public `/stream`: первый успех побеждает, проигравший
    /// дропается (reqwest рвёт соединение). Зеркалит `direct_download::try_download`
    /// (`select_all`). Оба провалились — последняя причина.
    async fn race_streams(
        &self,
        premium: &str,
        public: &str,
        progress: Option<Progress<'_>>,
    ) -> Result<Bytes, String> {
        let mut futures: Vec<BytesFuture<'_>> = vec![
            Box::pin(self.download_url(premium, progress)),
            Box::pin(self.download_url(public, progress)),
        ];
        let mut last_err = String::from("no stream candidates");
        while !futures.is_empty() {
            let (result, _idx, remaining) = futures::future::select_all(futures).await;
            match result {
                Ok(bytes) => return Ok(bytes),
                Err(e) => last_err = e,
            }
            futures = remaining;
        }
        Err(last_err)
    }

    async fn fetch_anon(
        &self,
        urn: &Urn,
        progress: Option<Progress<'_>>,
    ) -> Result<Bytes, String> {
        let source = self.raw.resolve_stream(urn).await.map_err(|e| e.to_string())?;
        self.raw
            .fetch_stream(&source, progress)
            .await
            .map_err(|e| e.to_string())
    }

    /// Привести скачанные байты к валидному m4a на диске. ВСЕГДА через ffmpeg —
    /// даже mp4-с-ftyp от SC бывает фрагментирован/HLS и не декодится rodio.
    /// ffmpeg (stream-copy → faststart, иначе перекод в AAC) даёт чистый
    /// не-фрагментированный m4a с moov впереди — единый формат для плеера.
    async fn materialize(&self, bytes: &[u8], output: &Path) -> Result<(), CacheError> {
        let parent = output.parent().unwrap_or(&self.dir);
        tokio::fs::create_dir_all(parent).await.map_err(io)?;

        // Уникальные времянки на вызов: rapid-клики/preload могут запустить два
        // транскода одного трека — с фиксированными именами они дрались бы за
        // общий `.src`/`.tmp` и портили бы файл. На финальный путь файл попадает
        // только атомарным переносом полностью готового и провалидированного.
        let uniq = unique_suffix();
        let input = with_suffix(output, &format!("{uniq}.src"));
        let output_tmp = with_suffix(output, &format!("{uniq}.m4a.tmp"));

        atomic_write(&input, bytes).await?;
        let (input_owned, output_owned) = (input.clone(), output_tmp.clone());
        let transcoded = tokio::task::spawn_blocking(move || {
            transcode::to_m4a_blocking(&input_owned, &output_owned)
        })
        .await
        .map_err(|e| CacheError::Transcode(e.to_string()))?;

        let _ = tokio::fs::remove_file(&input).await;
        if let Err(error) = transcoded {
            let _ = tokio::fs::remove_file(&output_tmp).await;
            return Err(error);
        }
        commit(&output_tmp, output).await
    }
}

/// Уникальный суффикс времянки (pid + счётчик) — разводит конкурентные транскоды.
fn unique_suffix() -> String {
    static SEQ: AtomicU64 = AtomicU64::new(0);
    format!("{}.{}", std::process::id(), SEQ.fetch_add(1, Ordering::Relaxed))
}

/// Путь с добавленным суффиксом (в том же каталоге — rename атомарен).
fn with_suffix(path: &Path, suffix: &str) -> PathBuf {
    let mut name = path.as_os_str().to_owned();
    name.push(format!(".{suffix}"));
    PathBuf::from(name)
}

/// Атомарно внести готовый файл на место: быстрый `rename`; при кросс-девайс
/// (времянка и кэш на разных ФС) — `copy` + удаление времянки.
async fn commit(tmp: &Path, output: &Path) -> Result<(), CacheError> {
    if tokio::fs::rename(tmp, output).await.is_ok() {
        return Ok(());
    }
    let copied = tokio::fs::copy(tmp, output).await;
    let _ = tokio::fs::remove_file(tmp).await;
    copied.map(|_| ()).map_err(io)
}

/// Слить тело потока в байты, отдавая долю по `content-length` (если известна).
/// Пустое тело — ошибка (источник «успешен», но молчит → пробуем следующий).
async fn collect_stream(stream: NetStream, progress: Option<Progress<'_>>) -> Result<Bytes, String> {
    let total = stream.content_length.unwrap_or(0);
    let mut body = stream.body;
    let mut buffer = BytesMut::new();
    let mut downloaded = 0u64;
    while let Some(chunk) = body.next().await {
        let chunk = chunk.map_err(|e| e.to_string())?;
        downloaded += chunk.len() as u64;
        buffer.extend_from_slice(&chunk);
        if let (Some(report), true) = (progress, total > 0) {
            report((downloaded as f64 / total as f64).clamp(0.0, 1.0));
        }
    }
    if buffer.is_empty() {
        return Err("empty body".to_owned());
    }
    Ok(buffer.freeze())
}

/// Синхронная проверка результата ffmpeg (вызывается из блокирующего транскода).
pub(crate) fn has_ftyp_file(path: &Path) -> bool {
    use std::io::Read;
    let Ok(mut file) = std::fs::File::open(path) else {
        return false;
    };
    let mut head = [0u8; 12];
    matches!(file.read(&mut head), Ok(read) if read >= 8 && &head[4..8] == b"ftyp")
}

async fn is_valid_m4a(path: &Path) -> bool {
    use tokio::io::AsyncReadExt;
    let Ok(mut file) = tokio::fs::File::open(path).await else {
        return false;
    };
    let mut head = [0u8; 12];
    matches!(file.read(&mut head).await, Ok(read) if read >= 8 && &head[4..8] == b"ftyp")
}

async fn atomic_write(path: &Path, bytes: &[u8]) -> Result<(), CacheError> {
    let tmp = path.with_extension("part");
    tokio::fs::write(&tmp, bytes).await.map_err(io)?;
    tokio::fs::rename(&tmp, path).await.map_err(io)?;
    Ok(())
}

fn io(error: std::io::Error) -> CacheError {
    CacheError::Io(error.to_string())
}
