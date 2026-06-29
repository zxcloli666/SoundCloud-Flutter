//! Интроспекция оффлайн-кэша: что лежит на диске, сколько весит, удалить.
//!
//! Каноничное имя файла — `soundcloud_tracks_<id>.m4a` (S3-canon), поэтому
//! id трека восстанавливается из имени без побочного индекса.

use sc_domain::{CacheEntry, Urn};

use crate::cache::TrackCache;
use crate::CacheError;

pub(crate) const CACHE_PREFIX: &str = "soundcloud_tracks_";
pub(crate) const CACHE_EXT: &str = ".m4a";

impl TrackCache {
    /// Список закэшированных треков с размерами. Несуществующий каталог → пусто.
    pub fn inventory(&self) -> Result<Vec<CacheEntry>, CacheError> {
        let read_dir = match std::fs::read_dir(self.dir()) {
            Ok(rd) => rd,
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => return Ok(Vec::new()),
            Err(e) => return Err(io(e)),
        };

        let mut entries = Vec::new();
        for dir_entry in read_dir {
            let dir_entry = dir_entry.map_err(io)?;
            let name = dir_entry.file_name();
            let Some(name) = name.to_str() else { continue };
            let Some(sc_id) = parse_cache_name(name) else { continue };
            let bytes = dir_entry.metadata().map_err(io)?.len() as i64;
            entries.push(CacheEntry {
                urn: Urn::new(format!("soundcloud:tracks:{sc_id}")),
                sc_id,
                path: dir_entry.path().to_string_lossy().into_owned(),
                bytes,
            });
        }
        Ok(entries)
    }

    pub fn total_bytes(&self) -> Result<i64, CacheError> {
        Ok(self.inventory()?.iter().map(|e| e.bytes).sum())
    }

    pub fn is_cached(&self, urn: &Urn) -> bool {
        self.cache_path(urn).is_file() || self.liked_path(urn).is_file()
    }

    /// Удалить файл трека из кэша. Отсутствие файла — не ошибка.
    pub async fn remove(&self, urn: &Urn) -> Result<(), CacheError> {
        match tokio::fs::remove_file(self.cache_path(urn)).await {
            Ok(()) => Ok(()),
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(()),
            Err(e) => Err(io(e)),
        }
    }
}

/// `soundcloud_tracks_<id>.m4a` → `<id>`. Прочие файлы (`.part`, `.tmp`, `.src`,
/// нецелочисленный id) — `None`.
pub(crate) fn parse_cache_name(name: &str) -> Option<i64> {
    name.strip_prefix(CACHE_PREFIX)?
        .strip_suffix(CACHE_EXT)?
        .parse::<i64>()
        .ok()
}

fn io(error: std::io::Error) -> CacheError {
    CacheError::Io(error.to_string())
}

#[cfg(test)]
mod tests {
    use super::parse_cache_name;

    #[test]
    fn parses_canonical_only() {
        assert_eq!(parse_cache_name("soundcloud_tracks_233409064.m4a"), Some(233409064));
        assert_eq!(parse_cache_name("soundcloud_tracks_1.m4a.tmp"), None);
        assert_eq!(parse_cache_name("soundcloud_tracks_abc.m4a"), None);
        assert_eq!(parse_cache_name("other.m4a"), None);
        assert_eq!(parse_cache_name("soundcloud_tracks_1.src"), None);
    }
}
