//! Аудио-движок: воспроизведение, перемотка, скорость, громкость, события.
//!
//! Принципиальное упрощение: **играем только m4a/AAC**. Формат гарантирует
//! [`sc-cache`](../sc_cache) (отдаёт готовый m4a), поэтому здесь один декодер
//! (symphonia aac+isomp4), без зоопарка форматов.
//!
//! Вывод (cpal-устройство, `!Send`) живёт на выделенном потоке `audio-output`;
//! управление — через общий [`rodio::mixer::Mixer`] и `Player` (Send+Sync), так
//! что `play/pause/seek/stop` неблокирующие и синхронные. Позиция/окончание —
//! через [`AudioEvent`] (poller ~10 Гц).
//!
//! EQ (10 полос, biquad), A-B-луп, source-time-интегратор скорости, нормализация
//! громкости (gated-RMS + `.gain`-кэш), спектр-анализатор (rustfft) и смена
//! аудиовыхода (перечисление + переезд трека на новое устройство) портированы
//! 1:1 с Tauri `audio/*`. lyrics/comments-таймлайны и hover-preview — отдельным
//! портом (большие подсистемы со своими потоками/зависимостями).

mod analyser;
mod device;
mod engine;
mod engine_device;
mod engine_reload;
mod eq;
mod output;
mod types;

pub use device::DeviceInfo;
pub use engine::{AudioEngine, AudioEvent};
pub use types::EQ_BANDS;

#[derive(Debug, thiserror::Error)]
pub enum AudioError {
    #[error("decode: {0}")]
    Decode(String),
    #[error("device: {0}")]
    Device(String),
}
