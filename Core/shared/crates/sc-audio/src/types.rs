//! Аудио-константы и параметры (порт `src-tauri/audio/types.rs`, m4a-релевантная
//! часть; opus/medina-каналы Tauri в Core не нужны — один декодер).

use std::num::NonZero;

pub(crate) type ChannelCount = NonZero<u16>;
pub(crate) type SampleRate = NonZero<u32>;

pub const EQ_BANDS: usize = 10;
pub(crate) const EQ_FREQS: [f64; EQ_BANDS] = [
    32.0, 64.0, 125.0, 250.0, 500.0, 1000.0, 2000.0, 4000.0, 8000.0, 16000.0,
];
pub(crate) const EQ_Q: f64 = 1.414;

// Нормализация громкости больше не считается в движке — все треки приводятся к
// единому уровню на транскоде (ffmpeg loudnorm в `sc-cache`), громкость крутится
// поверх. Прежние RMS-константы удалены.

/// 10-полосный параметрический EQ + признак включения. Делится между
/// управлением (`set_eq`) и аудио-потоком (`EqSource`) через `RwLock`.
pub(crate) struct EqParams {
    pub enabled: bool,
    pub gains: [f64; EQ_BANDS],
}

impl Default for EqParams {
    fn default() -> Self {
        Self {
            enabled: false,
            gains: [0.0; EQ_BANDS],
        }
    }
}
