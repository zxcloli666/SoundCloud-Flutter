//! Прямые запросы к «сырому» SoundCloud (анонимный apiv2): резолв трека,
//! поиск, выбор и скачивание потока (HLS/progressive). Отдельный крейт, потому
//! что это чужой нестабильный контракт — изолируем его от остального ядра.
//!
//! Всё ходит через транспорт [`sc-net`](../sc_net) ([`NetClient`]), поэтому
//! роутинг, прокси и пробив блокировок работают и здесь. Сырые потоки могут
//! быть не-AAC — их забирает `sc-cache` и приводит к m4a (m4a-инвариант там).

mod client;
mod client_id;
mod error;
mod hls;
mod types;

pub use client::RawClient;
pub use error::RawError;
pub use types::{AudioPreset, SearchPage, StreamProtocol, StreamSource};

/// Колбэк прогресса скачки: доля готовности 0..1, зовётся по мере чтения тела
/// (progressive — по байтам, HLS — по сегментам). Заимствуется на время вызова,
/// поэтому без `Arc`. `Send + Sync` — скачка может ехать на любом worker-потоке.
pub type Progress<'a> = &'a (dyn Fn(f64) + Send + Sync);
