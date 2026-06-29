//! Локальное хранилище обоев (скачка/импорт/список/удаление). Файлы лежат в
//! `<cache>/wallpapers/`, наружу отдаём абсолютные пути — Flutter рисует их
//! `Image.file` напрямую (локальный HTTP-сервер, как в Tauri, не нужен).
//! Скачка идёт через наш транспорт с браузерным UA (Wallhaven/Konachan 403-ят
//! не-браузер) и пишется атомарно (temp → rename), чтобы убитая запись не
//! оставила битый файл.

use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::sync::atomic::{AtomicU64, Ordering};
use std::time::{SystemTime, UNIX_EPOCH};

use sc_net::{HttpRequest, NetClient};

use crate::{BROWSER_UA, WallpaperError};

const IMAGE_EXTS: &[&str] = &["jpg", "jpeg", "png", "webp", "gif", "avif", "bmp"];

/// Дисковое хранилище обоев поверх [`NetClient`].
pub struct WallpaperStore {
    net: Arc<NetClient>,
    dir: PathBuf,
    seq: AtomicU64,
}

impl WallpaperStore {
    pub fn new(net: Arc<NetClient>, dir: impl Into<PathBuf>) -> Self {
        Self {
            net,
            dir: dir.into(),
            seq: AtomicU64::new(0),
        }
    }

    /// Скачать обоину по URL и сохранить. Возвращает абсолютный путь файла.
    pub async fn download(&self, url: &str) -> Result<String, WallpaperError> {
        let req = HttpRequest::get(url.to_owned())
            .header("User-Agent", BROWSER_UA)
            .header("Accept", "image/*");
        let resp = self.net.request(req).await?;
        if !resp.is_success() {
            return Err(WallpaperError::Http(resp.status));
        }
        let ext = ext_from_content_type(content_type(&resp.headers));
        self.write_atomic(ext, &resp.body).await
    }

    /// Импортировать локальный файл (из file-picker) в хранилище. Возвращает путь
    /// в хранилище (исходник не трогаем).
    pub async fn import(&self, src: &str) -> Result<String, WallpaperError> {
        let ext = ext_of(Path::new(src)).unwrap_or("jpg");
        let bytes = tokio::fs::read(src)
            .await
            .map_err(|e| WallpaperError::Decode(e.to_string()))?;
        self.write_atomic(ext, &bytes).await
    }

    /// Абсолютные пути всех сохранённых обоев (только картинки).
    pub async fn list(&self) -> Vec<String> {
        let mut out = Vec::new();
        let Ok(mut rd) = tokio::fs::read_dir(&self.dir).await else {
            return out;
        };
        while let Ok(Some(entry)) = rd.next_entry().await {
            let path = entry.path();
            if ext_of(&path).is_some_and(is_image_ext)
                && let Some(s) = path.to_str()
            {
                out.push(s.to_owned());
            }
        }
        out.sort();
        out
    }

    /// Удалить обоину по абсолютному пути. Удаляем только внутри хранилища.
    pub async fn remove(&self, path: &str) -> Result<(), WallpaperError> {
        let p = Path::new(path);
        if p.parent() != Some(self.dir.as_path()) {
            return Err(WallpaperError::Decode("path outside wallpaper store".to_owned()));
        }
        tokio::fs::remove_file(p)
            .await
            .map_err(|e| WallpaperError::Decode(e.to_string()))?;
        Ok(())
    }

    async fn write_atomic(&self, ext: &str, bytes: &[u8]) -> Result<String, WallpaperError> {
        tokio::fs::create_dir_all(&self.dir)
            .await
            .map_err(|e| WallpaperError::Decode(e.to_string()))?;
        let stem = self.unique_stem();
        let final_path = self.dir.join(format!("{stem}.{ext}"));
        let temp_path = self.dir.join(format!("{stem}.{ext}.part"));
        tokio::fs::write(&temp_path, bytes)
            .await
            .map_err(|e| WallpaperError::Decode(e.to_string()))?;
        if let Err(e) = tokio::fs::rename(&temp_path, &final_path).await {
            let _ = tokio::fs::remove_file(&temp_path).await;
            return Err(WallpaperError::Decode(e.to_string()));
        }
        final_path
            .to_str()
            .map(str::to_owned)
            .ok_or_else(|| WallpaperError::Decode("non-utf8 path".to_owned()))
    }

    /// Имя файла без расширения, уникальное между конкурентными скачками
    /// (монотонный наносекундный штамп + локальный счётчик).
    fn unique_stem(&self) -> String {
        let nanos = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map(|d| d.as_nanos())
            .unwrap_or(0);
        let n = self.seq.fetch_add(1, Ordering::Relaxed);
        format!("wallpaper_{nanos}_{n}")
    }
}

fn content_type(headers: &[(String, String)]) -> &str {
    headers
        .iter()
        .find(|(k, _)| k.eq_ignore_ascii_case("content-type"))
        .map(|(_, v)| v.as_str())
        .unwrap_or("")
}

fn ext_from_content_type(ct: &str) -> &'static str {
    let ct = ct.to_ascii_lowercase();
    if ct.contains("png") {
        "png"
    } else if ct.contains("webp") {
        "webp"
    } else if ct.contains("gif") {
        "gif"
    } else if ct.contains("avif") {
        "avif"
    } else {
        "jpg"
    }
}

fn ext_of(path: &Path) -> Option<&str> {
    path.extension().and_then(|e| e.to_str())
}

fn is_image_ext(ext: &str) -> bool {
    let lower = ext.to_ascii_lowercase();
    IMAGE_EXTS.contains(&lower.as_str())
}
