//! Пересоздание плеера текущего трека с сохранением позиции/паузы/скорости
//! (Tauri `reload_current_track`). Нужно для переезда на другой аудиовыход
//! (см. [`crate::engine_device`]) — берёт mixer активного устройства.

use std::time::Duration;

use crate::AudioError;
use crate::engine::{AudioEngine, apply_rate, build_player, lock};

impl AudioEngine {
    /// Пересоздать плеер текущего трека на текущем mixer'е, сохранив позицию,
    /// паузу и скорость. `gain` — линейный множитель источника (1.0 = как есть;
    /// громкость нормализуется на транскоде, поэтому здесь обычно 1.0).
    pub(crate) fn reload_with_gain(&self, gain: f32) -> Result<(), AudioError> {
        let bytes = lock(&self.source_bytes).clone();
        let Some(bytes) = bytes else {
            return Ok(());
        };
        let rate = (*lock(&self.playback_rate) as f64).max(0.01);
        let (source_position, was_paused) = {
            let guard = lock(&self.player);
            let Some(player) = guard.as_ref() else {
                return Ok(());
            };
            let (src_anchor, out_anchor) = *lock(&self.pos_anchor);
            (
                (src_anchor + (player.get_pos().as_secs_f64() - out_anchor) * rate).max(0.0),
                player.is_paused(),
            )
        };

        let (player, _) = build_player(
            &bytes,
            &self.current_mixer(),
            gain,
            self.eq_params.clone(),
            self.analyser.clone(),
            was_paused,
        )?;
        let output_target = source_position / rate;
        apply_rate(&player, *lock(&self.playback_rate));
        if source_position > 0.0 {
            player.try_seek(Duration::from_secs_f64(output_target)).ok();
        }
        let mut guard = lock(&self.player);
        if let Some(old) = guard.take() {
            old.stop();
        }
        *guard = Some(player);
        *lock(&self.pos_anchor) = (source_position, output_target);
        Ok(())
    }
}
