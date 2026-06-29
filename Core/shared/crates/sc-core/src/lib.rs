//! Композиционный корень ядра: собирает сеть/raw/кэш/аудио/auth в один фасад
//! [`ScRuntime`] и владеет их временем жизни. Здесь связываются конкретные
//! реализации (DI) — крейты ниже знают только трейты.
//!
//! Единственная точка, которую дёргает мост в Flutter (`sc-bridge`).
//! Платформенное (медиа-контролы) подключается через порты ([`ports`]), а не
//! зашито внутрь. m4a-инвариант держится конструктивно: путь к плееру —
//! только через `sc-cache` (валидный m4a).

mod auth;
mod cache;
mod config;
mod data;
mod data_social;
mod pay;
pub mod ports;
mod runtime;

pub use config::ScConfig;
pub use runtime::{CoreEvent, DownloadProgress, ScRuntime, ScRuntimeBuilder};
pub use sc_audio::DeviceInfo;
pub use sc_cache::LikesProgress;
pub use sc_net::{HostStatus, Verdict};
pub use sc_wallpapers::{WallpaperHit, WallpaperPage, WallpaperQuery};

#[derive(Debug, thiserror::Error)]
pub enum CoreError {
    #[error(transparent)]
    Net(#[from] sc_net::NetError),
    #[error(transparent)]
    Raw(#[from] sc_raw::RawError),
    #[error(transparent)]
    Bff(#[from] sc_bff::BffError),
    #[error(transparent)]
    Cache(#[from] sc_cache::CacheError),
    #[error(transparent)]
    Audio(#[from] sc_audio::AudioError),
    #[error(transparent)]
    Auth(#[from] sc_auth::AuthError),
    #[error(transparent)]
    Wallpaper(#[from] sc_wallpapers::WallpaperError),
    #[error("init: {0}")]
    Init(String),
}
