use std::sync::Arc;
use std::time::Duration;

use tokio::sync::{broadcast, watch};

use sc_audio::{AudioEngine, AudioEvent};
use sc_auth::{Session, SessionStore};
use sc_bff::{BffClient, PayClient};
use sc_cache::{LikesProgress, StreamingConfig, TrackCache};
use sc_domain::{Track, Urn};
use sc_net::{
    HostId, HostPool, HostStatus, HttpRequest, Mode, NetClient, NetConfig, NoSession, RetryPolicy,
    ScCredentials, SessionSource,
};
use sc_raw::RawClient;
use sc_wallpapers::WallpaperStore;

use crate::ports::{MediaControls, NoopMediaControls};
use crate::{CoreError, ScConfig};

const DEFAULT_USER_AGENT: &str =
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36";

/// Бэкенд-хосты приложения: основной и STAR-резерв (для премиум-failover).
const MAIN_API: &str = "https://api.scdinternal.site";
const STAR_API: &str = "https://api-star.scdinternal.site";

/// Период фоновой перепроверки подписки и health-пробинга хостов.
const SUBSCRIPTION_REFRESH: Duration = Duration::from_secs(30);
const HEALTH_PROBE_INTERVAL: Duration = Duration::from_secs(15);
/// Период опроса системного выхода по умолчанию (follow-default).
const DEFAULT_OUTPUT_POLL: Duration = Duration::from_secs(3);
/// Сколько промахов `/health` подряд, чтобы активно объявить хост `down` (один
/// промах — блип; пассивный путь роняет вердикт по своим правилам).
const PROBE_CONFIRM: u32 = 2;

/// Критические события ядра (без потерь). Высокочастотная позиция идёт отдельно,
/// через `watch` ([`ScRuntime::position_watch`]).
#[derive(Clone, Debug)]
pub enum CoreEvent {
    TrackEnded,
    TrackChanged { urn: String },
}

/// Прогресс скачки текущего трека (доля 0..1). Транскод не считается — процент
/// отражает только фазу скачивания (как в Tauri `track:download-progress`).
#[derive(Clone, Debug)]
pub struct DownloadProgress {
    pub urn: String,
    pub fraction: f64,
}

struct Inner {
    net: Arc<NetClient>,
    pool: Arc<HostPool>,
    raw: Arc<RawClient>,
    bff: Arc<BffClient>,
    pay: Arc<PayClient>,
    cache: TrackCache,
    wallpapers: WallpaperStore,
    audio: AudioEngine,
    session: Arc<SessionStore>,
    media: Arc<dyn MediaControls>,
    position_tx: watch::Sender<f64>,
    events_tx: broadcast::Sender<CoreEvent>,
    progress_tx: broadcast::Sender<DownloadProgress>,
    likes_progress_tx: broadcast::Sender<LikesProgress>,
}

/// Фасад ядра. Клонируемый дескриптор (`Arc<Inner>`) — мост и фоновые задачи
/// держат его без Arc-циклов.
#[derive(Clone)]
pub struct ScRuntime(Arc<Inner>);

impl ScRuntime {
    pub fn builder(config: ScConfig) -> ScRuntimeBuilder {
        ScRuntimeBuilder {
            config,
            media: None,
        }
    }

    pub async fn new(config: ScConfig) -> Result<Self, CoreError> {
        Self::builder(config).build().await
    }

    // --- запросы ---

    /// Поиск треков — через BFF (`/search/db/tracks`), реальный путь приложения.
    pub async fn search(
        &self,
        query: &str,
        limit: u32,
        offset: u32,
    ) -> Result<Vec<Track>, CoreError> {
        Ok(self.0.bff.search_tracks(query, limit, offset).await?.items)
    }

    /// Резолв трека для воспроизведения — через сырой SC (apiv2 даёт media).
    pub async fn resolve(&self, urn: &Urn) -> Result<Option<Track>, CoreError> {
        Ok(self.0.raw.resolve_track(urn).await?)
    }

    /// Поиск онлайн-обоев (Wallhaven/Pinterest/Konachan/Safebooru) — анонимно
    /// через наш транспорт (роутинг/пробив работают).
    pub async fn wallpaper_search(
        &self,
        query: sc_wallpapers::WallpaperQuery,
    ) -> Result<sc_wallpapers::WallpaperPage, CoreError> {
        let client = sc_wallpapers::WallpaperClient::new(self.0.net.clone());
        Ok(client.search(&query).await?)
    }

    /// Скачать обоину по URL в локальное хранилище — абсолютный путь файла.
    pub async fn wallpaper_download(&self, url: &str) -> Result<String, CoreError> {
        Ok(self.0.wallpapers.download(url).await?)
    }

    /// Импортировать локальный файл (file-picker) в хранилище обоев.
    pub async fn wallpaper_import(&self, src_path: &str) -> Result<String, CoreError> {
        Ok(self.0.wallpapers.import(src_path).await?)
    }

    /// Абсолютные пути всех сохранённых обоев.
    pub async fn wallpaper_list(&self) -> Vec<String> {
        self.0.wallpapers.list().await
    }

    /// Удалить обоину по абсолютному пути.
    pub async fn wallpaper_remove(&self, path: &str) -> Result<(), CoreError> {
        Ok(self.0.wallpapers.remove(path).await?)
    }

    /// BFF-клиент для слоя данных ([`crate::data`]).
    pub(crate) fn bff(&self) -> &BffClient {
        &self.0.bff
    }

    /// Сырой SoundCloud-клиент (apiv2) — для живого SC-поиска/резолва.
    pub(crate) fn raw(&self) -> &RawClient {
        &self.0.raw
    }

    /// Кэш треков для оффлайн-интроспекции ([`crate::cache`]).
    pub(crate) fn cache(&self) -> &TrackCache {
        &self.0.cache
    }

    /// Платёжный клиент STAR ([`crate::pay`]).
    pub(crate) fn pay(&self) -> &PayClient {
        &self.0.pay
    }

    /// Есть ли локальный токен (Rust-owned сессия). Используется auth-гейтом.
    pub(crate) fn has_local_session(&self) -> bool {
        self.0.session.token().is_some()
    }

    // --- воспроизведение (в плеер только через cache → валидный m4a) ---

    pub async fn play_track(&self, urn: &Urn) -> Result<(), CoreError> {
        // Останавливаем текущий ДО загрузки нового: иначе старый трек доиграет во
        // время (долгой) скачки+транскода нового и пошлёт Ended → очередь прыгнет
        // на следующий, пока пользователь ждёт выбранный.
        self.0.audio.stop();
        // Прогресс скачки текущего трека → broadcast (мост раздаёт в NowBar).
        let progress_tx = self.0.progress_tx.clone();
        let urn_str = urn.as_str().to_owned();
        let report = move |fraction: f64| {
            let _ = progress_tx.send(DownloadProgress {
                urn: urn_str.clone(),
                fraction,
            });
        };
        let m4a = self.0.cache.ensure(urn, Some(&report)).await?;
        // Самолечение: если кэш-файл не декодится (битый/несовместимый контейнер),
        // сносим и перекачиваем один раз — не «зависаем» на битом файле навсегда.
        if let Err(error) = self.0.audio.load_file(m4a.path()).await {
            if matches!(error, sc_audio::AudioError::Decode(_)) {
                let _ = self.0.cache.remove(urn).await;
                let m4a = self.0.cache.ensure(urn, Some(&report)).await?;
                self.0.audio.load_file(m4a.path()).await?;
            } else {
                return Err(error.into());
            }
        }
        self.0.audio.play();
        self.0.media.set_playing(true);
        let _ = self
            .0
            .events_tx
            .send(CoreEvent::TrackChanged {
                urn: urn.as_str().to_owned(),
            });
        Ok(())
    }

    /// Hover-превью трека: дожать кэш (тихо, без прогресс-отчёта) и проиграть на
    /// отдельном превью-плеере. Гейт «не поверх играющего» — на слое выше (UI).
    pub async fn preview_play(&self, urn: &Urn, volume: f64) -> Result<(), CoreError> {
        let m4a = self.0.cache.ensure(urn, None).await?;
        self.0.audio.preview_play(m4a.path(), volume).await?;
        Ok(())
    }

    /// Снять hover-превью (фейд, мс).
    pub fn preview_stop(&self, fade_ms: u64) {
        self.0.audio.preview_stop(fade_ms);
    }

    pub fn pause(&self) {
        self.0.audio.pause();
        self.0.media.set_playing(false);
    }

    pub fn resume(&self) {
        self.0.audio.play();
        self.0.media.set_playing(true);
    }

    pub fn stop(&self) {
        self.0.audio.stop();
        self.0.media.clear();
    }

    pub fn seek(&self, position_secs: f64) -> Result<(), CoreError> {
        Ok(self.0.audio.seek(position_secs)?)
    }

    pub fn set_volume(&self, volume: f64) {
        self.0.audio.set_volume(volume);
    }

    pub fn set_speed(&self, speed: f64) {
        self.0.audio.set_speed(speed);
    }

    pub fn set_eq(&self, enabled: bool, gains: &[f64]) {
        self.0.audio.set_eq(enabled, gains);
    }

    pub fn set_ab_loop(&self, a: Option<f64>, b: Option<f64>) {
        self.0.audio.set_ab_loop(a, b);
    }

    /// Доступные выходные аудиоустройства (для пикера в настройках).
    pub fn audio_output_devices(&self) -> Vec<sc_audio::DeviceInfo> {
        self.0.audio.output_devices()
    }

    /// Переключить аудиовыход (`None` — системный по умолчанию). Текущий трек
    /// переезжает на новое устройство с сохранением позиции/состояния.
    pub fn set_audio_output(&self, name: Option<String>) -> Result<(), CoreError> {
        Ok(self.0.audio.set_output_device(name)?)
    }

    /// Поток лог-полос спектра (~30 Гц). Считается только при наличии подписчика.
    pub fn spectrum(&self) -> broadcast::Receiver<Vec<f32>> {
        self.0.audio.subscribe_spectrum()
    }

    pub fn position_secs(&self) -> f64 {
        self.0.audio.position_secs()
    }

    pub fn is_playing(&self) -> bool {
        self.0.audio.is_playing()
    }

    // --- сессия ---

    pub fn session(&self) -> Session {
        self.0.session.session()
    }

    pub fn set_session(&self, token: Option<String>) -> Result<(), CoreError> {
        Ok(self.0.session.set_session(token)?)
    }

    // --- статус хостов (failover main ⇄ star) ---

    /// Поток статуса хостов (вердикты main/star + premium) для UI-модалок.
    /// Эмитит при каждом изменении; `watch` отдаёт последнее значение сразу.
    pub fn host_status_watch(&self) -> watch::Receiver<HostStatus> {
        self.0.pool.subscribe()
    }

    /// Текущий снимок статуса хостов.
    pub fn host_status(&self) -> HostStatus {
        self.0.pool.snapshot()
    }

    /// Внеочередная перепроверка (кнопка «Проверить снова»): будит рефрешер →
    /// `/me/subscription` бьёт по хостам и обновляет вердикты (живой → `up`).
    pub fn request_host_recheck(&self) {
        self.0.pool.request_recheck();
    }

    // --- подписки ---

    /// Текущая позиция (latest-wins, без потерь критики).
    pub fn position_watch(&self) -> watch::Receiver<f64> {
        self.0.position_tx.subscribe()
    }

    /// Критические события (Ended/TrackChanged).
    pub fn events(&self) -> broadcast::Receiver<CoreEvent> {
        self.0.events_tx.subscribe()
    }

    /// Прогресс скачки текущего трека (доля 0..1). Считается только при наличии
    /// подписчика; на каждый `play_track` идёт серия событий для его `urn`.
    pub fn download_progress(&self) -> broadcast::Receiver<DownloadProgress> {
        self.0.progress_tx.subscribe()
    }

    /// Прогресс bulk-кэша лайков ({done,failed,total,finished}).
    pub fn likes_progress(&self) -> broadcast::Receiver<LikesProgress> {
        self.0.likes_progress_tx.subscribe()
    }

    /// Сендер прогресса лайков — для [`crate::cache`].
    pub(crate) fn likes_progress_tx(&self) -> broadcast::Sender<LikesProgress> {
        self.0.likes_progress_tx.clone()
    }

    /// Мост `sc-audio` → разведённые каналы. Держит только сендеры + приёмник
    /// аудио, не сам рантайм — цикла нет.
    fn spawn_event_bridge(&self) {
        let mut audio_rx = self.0.audio.subscribe();
        let position_tx = self.0.position_tx.clone();
        let events_tx = self.0.events_tx.clone();
        tokio::spawn(async move {
            loop {
                match audio_rx.recv().await {
                    Ok(AudioEvent::Tick { position_secs }) => {
                        let _ = position_tx.send(position_secs);
                    }
                    Ok(AudioEvent::Ended) => {
                        let _ = events_tx.send(CoreEvent::TrackEnded);
                    }
                    Err(broadcast::error::RecvError::Lagged(_)) => continue,
                    Err(broadcast::error::RecvError::Closed) => break,
                }
            }
        });
    }

    /// Фоновый мониторинг хостов: перепроверка подписки (кормит premium в пул) и
    /// health-пробинг (recovery/обнаружение падений). Source of truth статуса —
    /// пул, UI только читает [`ScRuntime::host_status_watch`].
    fn spawn_host_monitor(&self) {
        self.spawn_subscription_refresh();
        self.spawn_health_prober();
        self.spawn_default_output_follow();
    }

    /// Следить за системным выходом по умолчанию: пока выбран дефолт (`None`),
    /// при смене дефолта ОС переезжаем на новый (легаси `pactl subscribe` /
    /// follow-default). Текущий трек переезжает с сохранением позиции.
    fn spawn_default_output_follow(&self) {
        let rt = self.clone();
        tokio::spawn(async move {
            let mut last = rt.0.audio.current_default_output();
            loop {
                tokio::time::sleep(DEFAULT_OUTPUT_POLL).await;
                let current = rt.0.audio.current_default_output();
                if rt.0.audio.is_following_default()
                    && current.is_some()
                    && current != last
                {
                    let _ = rt.0.audio.set_output_device(None);
                }
                last = current;
            }
        });
    }

    /// Периодически (+ по нотификации от STAR-403) тянет `/me/subscription` и
    /// кладёт premium в пул. На сетевой ошибке premium НЕ трогаем — держим кэш
    /// (иначе премиум мигал бы при флапе).
    fn spawn_subscription_refresh(&self) {
        let rt = self.clone();
        let recheck = self.0.pool.recheck_handle();
        tokio::spawn(async move {
            let mut tick = tokio::time::interval(SUBSCRIPTION_REFRESH);
            loop {
                tokio::select! {
                    _ = tick.tick() => {}
                    _ = recheck.notified() => {}
                }
                if !rt.has_local_session() {
                    continue;
                }
                if let Ok(premium) = rt.0.bff.me_subscription().await {
                    rt.0.pool.set_premium(premium);
                }
            }
        });
    }

    /// Пингует `/health` обоих хостов: успех → `up` (recovery мгновенный), 2
    /// промаха подряд → активно `down`. Параллельно с пассивными вердиктами из
    /// failover-перебора.
    fn spawn_health_prober(&self) {
        let rt = self.clone();
        tokio::spawn(async move {
            let mut main_misses = 0u32;
            let mut star_misses = 0u32;
            loop {
                probe(&rt, HostId::Main, MAIN_API, &mut main_misses).await;
                probe(&rt, HostId::Star, STAR_API, &mut star_misses).await;
                tokio::time::sleep(HEALTH_PROBE_INTERVAL).await;
            }
        });
    }
}

/// Один цикл health-пробинга хоста: `<base>/health`, статус <500 = жив.
async fn probe(rt: &ScRuntime, host: HostId, base: &str, misses: &mut u32) {
    let req = HttpRequest::get(format!("{base}/health"));
    let alive = matches!(
        rt.0.net.request_with(req, &RetryPolicy::none()).await,
        Ok(resp) if resp.status < 500
    );
    if alive {
        *misses = 0;
        rt.0.pool.mark_probe(host, true);
    } else {
        *misses = misses.saturating_add(1);
        if *misses >= PROBE_CONFIRM {
            rt.0.pool.mark_probe(host, false);
        }
    }
}

pub struct ScRuntimeBuilder {
    config: ScConfig,
    media: Option<Arc<dyn MediaControls>>,
}

impl ScRuntimeBuilder {
    /// Подключить реальные медиа-контролы (иначе — Noop).
    pub fn media_controls(mut self, media: Arc<dyn MediaControls>) -> Self {
        self.media = Some(media);
        self
    }

    pub async fn build(self) -> Result<ScRuntime, CoreError> {
        let session = Arc::new(SessionStore::load(self.config.data_dir.join("session.json")));

        let streaming = StreamingConfig::default();
        let user_agent = self
            .config
            .net
            .user_agent
            .clone()
            .unwrap_or_else(|| DEFAULT_USER_AGENT.to_owned());
        // Хосты стрима/хранилища всегда Direct (и следуют 3xx redirect на S3) —
        // даже если глобальный режим прокси/пробив; иначе сырые аудио-байты
        // потащит через лишний хоп. (PROD-PORT P0-1.)
        let mut net_config = pin_streaming_direct(self.config.net, &streaming);
        // DPI-обход как fallback: при блокировке Direct хост добивается через
        // TLS-фрагментацию (включается настройкой пользователя).
        if self.config.dpi_bypass {
            net_config = net_config.with_bypass_fallback();
        }
        // sc-net — тупой транспорт: декоратор добавляет только User-Agent, БЕЗ
        // токенов. Сессию (x-session-id) навешивают слои, которым она нужна:
        // API (sc-bff/pay) и наш стрим (sc-cache). На SC (sc-raw) и чужие сайты
        // (sc-wallpapers) токен не уходит.
        let session_src: Arc<dyn SessionSource> = Arc::new(AuthSessionSource(session.clone()));
        let decorator = Arc::new(ScCredentials::new(Arc::new(NoSession), user_agent));
        let net = Arc::new(NetClient::with_decorator(net_config, decorator).await?);

        // Пул хостов с failover (main ⇄ star). Стрим-базы — из StreamingConfig
        // (single source of truth), api-базы — деплой-константы.
        let pool = Arc::new(HostPool::new(
            MAIN_API,
            STAR_API,
            streaming.stream_base.clone(),
            streaming.stream_premium_base.clone(),
        ));

        let raw = Arc::new(RawClient::new(net.clone()));
        let bff = Arc::new(BffClient::new(net.clone(), pool.clone(), session_src.clone()));
        let pay = Arc::new(PayClient::new(net.clone(), session_src.clone()));
        // Обои анонимны — тот же транспорт (роутинг/пробив), но без токена сессии.
        let wallpapers = WallpaperStore::new(net.clone(), self.config.cache_dir.join("wallpapers"));
        let cache = TrackCache::new(
            net.clone(),
            raw.clone(),
            self.config.cache_dir,
            streaming,
            session_src.clone(),
        );
        // Прогреть ffmpeg на старте, не блокируя первый play (Tauri acquire_ffmpeg).
        cache.prepare();
        let audio = AudioEngine::new().await?;
        let media = self.media.unwrap_or_else(|| Arc::new(NoopMediaControls));

        let (position_tx, _) = watch::channel(0.0);
        let (events_tx, _) = broadcast::channel(64);
        let (progress_tx, _) = broadcast::channel(64);
        let (likes_progress_tx, _) = broadcast::channel(64);

        let runtime = ScRuntime(Arc::new(Inner {
            net,
            pool,
            raw,
            bff,
            pay,
            cache,
            wallpapers,
            audio,
            session,
            media,
            position_tx,
            events_tx,
            progress_tx,
            likes_progress_tx,
        }));
        runtime.spawn_event_bridge();
        runtime.spawn_host_monitor();
        Ok(runtime)
    }
}

/// Закрепить хосты стрима/хранилища на Direct (3xx-редиректы на S3 следуют сами).
/// Уже заданный пользователем override для хоста не трогаем.
fn pin_streaming_direct(mut config: NetConfig, streaming: &StreamingConfig) -> NetConfig {
    let bases = [
        &streaming.storage_base,
        &streaming.stream_base,
        &streaming.stream_premium_base,
    ];
    for base in bases {
        if let Some(host) = host_of(base) {
            let already_set = config.host_overrides.iter().any(|(h, _)| *h == host);
            if !already_set {
                config = config.route_host(host, Mode::Direct);
            }
        }
    }
    config
}

/// Хост из `https://host[:port]/path` (без зависимости от `url`).
fn host_of(base: &str) -> Option<String> {
    let after_scheme = base.split_once("://").map(|(_, rest)| rest).unwrap_or(base);
    let host_port = after_scheme.split(['/', '?', '#']).next().unwrap_or(after_scheme);
    let host = host_port.split(':').next().unwrap_or(host_port);
    if host.is_empty() {
        None
    } else {
        Some(host.to_owned())
    }
}

/// Мост сессии в сетевой декоратор: отдаёт текущий токен как `x-session-id`.
struct AuthSessionSource(Arc<SessionStore>);

impl SessionSource for AuthSessionSource {
    fn session_id(&self) -> Option<String> {
        self.0.token()
    }
}
