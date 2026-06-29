//! Управление кэшем: лимит (LRU-вытеснение), очистка, защищённый кэш лайков и
//! его bulk-наполнение с прогрессом. Защищённый кэш (`liked/`) живёт отдельно и
//! НЕ вытесняется лимитом — это инвариант 1:1 с легаси (`liked_dir`).

use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, Ordering};
use std::time::UNIX_EPOCH;

use sc_domain::Urn;

use crate::CacheError;
use crate::cache::TrackCache;
use crate::inventory::parse_cache_name;

/// Состояние bulk-кэша лайков: идёт ли и запрошена ли отмена. Шарится между
/// вызовом `cache_likes` и `cancel_cache_likes`/`cache_likes_running`.
#[derive(Default)]
pub(crate) struct LikesState {
    running: AtomicBool,
    cancel: AtomicBool,
}

/// Прогресс bulk-кэша лайков для индикатора в настройках.
#[derive(Clone, Copy, Debug)]
pub struct LikesProgress {
    pub done: usize,
    pub failed: usize,
    pub total: usize,
    pub finished: bool,
}

impl TrackCache {
    /// Размер защищённого кэша лайков (байты).
    pub fn liked_bytes(&self) -> Result<i64, CacheError> {
        let read = match std::fs::read_dir(self.liked_dir()) {
            Ok(rd) => rd,
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => return Ok(0),
            Err(e) => return Err(io(e)),
        };
        let mut total = 0i64;
        for entry in read.flatten() {
            if let Some(name) = entry.file_name().to_str() {
                if parse_cache_name(name).is_some() {
                    total += entry.metadata().map(|m| m.len() as i64).unwrap_or(0);
                }
            }
        }
        Ok(total)
    }

    /// Вытеснить старейшие треки обычного кэша, пока он не уложится в лимит.
    /// Защищённый кэш лайков (`liked/`) не трогаем. LRU по времени доступа
    /// (фолбэк — mtime). `limit_mb == 0` — без лимита.
    pub fn enforce_limit(&self, limit_mb: u64) {
        if limit_mb == 0 {
            return;
        }
        let limit = limit_mb * 1024 * 1024;

        let Ok(read) = std::fs::read_dir(self.dir()) else {
            return;
        };
        let mut files: Vec<(PathBuf, u64, std::time::SystemTime)> = Vec::new();
        let mut total = 0u64;
        for entry in read.flatten() {
            let Some(name) = entry.file_name().to_str().map(str::to_owned) else {
                continue;
            };
            if parse_cache_name(&name).is_none() {
                continue; // .part/.tmp/.src и подкаталог liked/ — пропускаем
            }
            let Ok(meta) = entry.metadata() else { continue };
            if !meta.is_file() {
                continue;
            }
            let accessed = meta
                .accessed()
                .or_else(|_| meta.modified())
                .unwrap_or(UNIX_EPOCH);
            total += meta.len();
            files.push((entry.path(), meta.len(), accessed));
        }

        if total <= limit {
            return;
        }
        files.sort_by_key(|f| f.2); // старейшие первыми
        for (path, size, _) in files {
            if total <= limit {
                break;
            }
            if std::fs::remove_file(&path).is_ok() {
                total -= size;
            }
        }
    }

    /// Очистить обычный кэш (canonical m4a). Защищённый кэш лайков не трогаем.
    pub fn clear(&self) -> Result<(), CacheError> {
        let read = match std::fs::read_dir(self.dir()) {
            Ok(rd) => rd,
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => return Ok(()),
            Err(e) => return Err(io(e)),
        };
        for entry in read.flatten() {
            if let Some(name) = entry.file_name().to_str() {
                if parse_cache_name(name).is_some() {
                    let _ = std::fs::remove_file(entry.path());
                }
            }
        }
        Ok(())
    }

    /// Очистить защищённый кэш лайков целиком.
    pub fn clear_liked(&self) -> Result<(), CacheError> {
        match std::fs::remove_dir_all(self.liked_dir()) {
            Ok(()) => Ok(()),
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(()),
            Err(e) => Err(io(e)),
        }
    }

    pub fn cache_likes_running(&self) -> bool {
        self.likes.running.load(Ordering::SeqCst)
    }

    /// Запросить отмену текущего bulk-кэша лайков (проверяется между треками).
    pub fn cancel_cache_likes(&self) {
        self.likes.cancel.store(true, Ordering::SeqCst);
    }

    /// Скачать все [`urns`] в защищённый кэш лайков, отдавая прогресс. Уже
    /// закэшированные пропускаем. Отменяемо между треками. Повторный запуск, пока
    /// один идёт, — no-op (защита от дублей).
    pub async fn cache_likes(
        &self,
        urns: Vec<Urn>,
        report: &(dyn Fn(LikesProgress) + Send + Sync),
    ) -> Result<(), CacheError> {
        if self.likes.running.swap(true, Ordering::SeqCst) {
            return Ok(());
        }
        self.likes.cancel.store(false, Ordering::SeqCst);

        let total = urns.len();
        let mut done = 0usize;
        let mut failed = 0usize;
        report(LikesProgress { done, failed, total, finished: false });

        for urn in urns {
            if self.likes.cancel.load(Ordering::SeqCst) {
                break;
            }
            if self.liked_path(&urn).is_file() {
                done += 1;
            } else {
                match self.ensure_liked(&urn, None).await {
                    Ok(_) => done += 1,
                    Err(_) => failed += 1,
                }
            }
            report(LikesProgress { done, failed, total, finished: false });
        }

        self.likes.running.store(false, Ordering::SeqCst);
        report(LikesProgress { done, failed, total, finished: true });
        Ok(())
    }
}

fn io(error: std::io::Error) -> CacheError {
    CacheError::Io(error.to_string())
}
