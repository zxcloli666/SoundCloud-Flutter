//! Кэш треков и нормализация формата к m4a.
//!
//! Инвариант: на выход — всегда валидный m4a/AAC ([`M4aFile`], выдаётся только
//! отсюда). Если источник уже AAC и в mp4-контейнере (ftyp) — пишем как есть,
//! ffmpeg не зовём; иначе транскодируем (stream-copy для AAC, перекодирование
//! для прочего). `sc-audio` получает только готовый m4a и держит один декодер.

mod cache;
mod inventory;
mod manage;
mod transcode;

pub use cache::{M4aFile, StreamingConfig, TrackCache};
pub use manage::LikesProgress;
pub use sc_domain::CacheEntry;

#[derive(Debug, thiserror::Error)]
pub enum CacheError {
    #[error(transparent)]
    Raw(#[from] sc_raw::RawError),
    #[error("io: {0}")]
    Io(String),
    #[error("transcode: {0}")]
    Transcode(String),
    #[error("invalid m4a output")]
    InvalidOutput,
    /// Ни один источник не отдал трек — агрегат причин по всей цепочке. Не
    /// глотаем: всплывает в мост/UI, чтобы «не играет» показывало почему.
    #[error("no playable source: {0}")]
    NoSource(String),
}
