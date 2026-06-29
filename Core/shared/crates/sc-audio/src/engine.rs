use std::io::Cursor;
use std::path::Path;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex, MutexGuard, RwLock};
use std::time::Duration;

use rodio::mixer::Mixer;
use rodio::{Decoder, Player, Source};
use tokio::sync::broadcast;

use crate::AudioError;
use crate::analyser::{AnalyserBuffer, AnalyserSource, start_fft_thread};
use crate::eq::{EqSource, GainSource};
use crate::types::{EQ_BANDS, EqParams};

const TICK_INTERVAL: Duration = Duration::from_millis(100);
const VOLUME_MAX: f32 = 2.0;
const SPEED_MIN: f32 = 0.5;
const SPEED_MAX: f32 = 2.0;

/// События движка. Tick — высокочастотный (позиция), Ended — критичный (двигает
/// очередь). Слой выше при желании разводит их по разным каналам.
#[derive(Clone, Debug)]
pub enum AudioEvent {
    Tick { position_secs: f64 },
    Ended,
}

/// Воспроизведение одного m4a за раз. Управление синхронно и неблокирующе.
/// EQ/A-B-луп/скорость/нормализация/спектр портированы 1:1 с Tauri `audio/*`.
/// Клонируемый дескриптор (поля — `Arc`/`Mixer`/`Sender`); фоновые задачи держат
/// копию без Arc-циклов.
#[derive(Clone)]
pub struct AudioEngine {
    /// Общий mixer текущего устройства. Свопается при смене аудиовыхода
    /// ([`crate::output::Output::switch`]), поэтому за Mutex.
    pub(crate) mixer: Arc<Mutex<Mixer>>,
    /// Владелец cpal-устройства (на своём потоке); умеет переоткрыться.
    pub(crate) output: Arc<crate::output::Output>,
    pub(crate) player: Arc<Mutex<Option<Player>>>,
    /// Hover-превью: отдельный плеер на том же миксере (не трогает основной).
    /// Сэмплируем трек под курсором, гасим фейдом на уход. `preview_vol` — стартовая
    /// громкость для расчёта фейда.
    preview: Arc<Mutex<Option<Player>>>,
    preview_vol: Arc<Mutex<f32>>,
    /// Сырые байты текущего трека — для пересоздания плеера на seek/EQ/скорость.
    pub(crate) source_bytes: Arc<Mutex<Option<Vec<u8>>>>,
    pub(crate) eq_params: Arc<RwLock<EqParams>>,
    /// (a, b) границы A-B-лупа в source-секундах.
    ab_loop: Arc<Mutex<Option<(f64, f64)>>>,
    /// Скорость воспроизведения (rodio output-time = source/rate).
    pub(crate) playback_rate: Arc<Mutex<f32>>,
    /// Интегратор source-времени: (source_anchor, output_anchor). Точен через
    /// смены скорости — каждый constant-rate сегмент закрывается в anchor.
    pub(crate) pos_anchor: Arc<Mutex<(f64, f64)>>,
    /// PCM-кран для FFT-анализатора + broadcast лог-полос наружу.
    pub(crate) analyser: Arc<AnalyserBuffer>,
    spectrum: broadcast::Sender<Vec<f32>>,
    active: Arc<AtomicBool>,
    events: broadcast::Sender<AudioEvent>,
    /// Идём ли за системным выходом по умолчанию (выбран `None`-выход). При смене
    /// дефолта ОС следящая задача переоткрывает новый. `false` — закреплён конкретный.
    pub(crate) following_default: Arc<AtomicBool>,
}

impl AudioEngine {
    pub async fn new() -> Result<Self, AudioError> {
        let (output, mixer) = crate::output::Output::open(None)?;
        let (events, _) = broadcast::channel(64);
        let (spectrum, _) = broadcast::channel(8);
        let analyser = AnalyserBuffer::new();
        start_fft_thread(analyser.clone(), spectrum.clone());
        let engine = Self {
            mixer: Arc::new(Mutex::new(mixer)),
            output: Arc::new(output),
            player: Arc::new(Mutex::new(None)),
            preview: Arc::new(Mutex::new(None)),
            preview_vol: Arc::new(Mutex::new(0.0)),
            source_bytes: Arc::new(Mutex::new(None)),
            eq_params: Arc::new(RwLock::new(EqParams::default())),
            ab_loop: Arc::new(Mutex::new(None)),
            playback_rate: Arc::new(Mutex::new(1.0)),
            pos_anchor: Arc::new(Mutex::new((0.0, 0.0))),
            analyser,
            spectrum,
            active: Arc::new(AtomicBool::new(false)),
            events,
            following_default: Arc::new(AtomicBool::new(true)),
        };
        engine.spawn_poller();
        Ok(engine)
    }

    /// Загрузить m4a-файл (декод в spawn_blocking). Возвращает длительность.
    /// Стартует на паузе — воспроизведение запускает [`AudioEngine::play`].
    /// Старт всегда на gain 1.0; нормализация (если вкл) считается в фоне и
    /// применяется релоадом — не блокирует первый play.
    pub async fn load_file(&self, path: &Path) -> Result<Option<f64>, AudioError> {
        let path = path.to_owned();
        let mixer = self.current_mixer();
        let eq = self.eq_params.clone();
        let analyser = self.analyser.clone();
        let bytes = tokio::task::spawn_blocking({
            let path = path.clone();
            move || std::fs::read(&path)
        })
        .await
        .map_err(|e| AudioError::Decode(e.to_string()))?
        .map_err(|e| AudioError::Decode(e.to_string()))?;

        let (player, duration) = tokio::task::spawn_blocking({
            let bytes = bytes.clone();
            move || build_player(&bytes, &mixer, 1.0, eq, analyser, true)
        })
        .await
        .map_err(|e| AudioError::Decode(e.to_string()))??;

        apply_rate(&player, *lock(&self.playback_rate));
        {
            let mut guard = lock(&self.player);
            if let Some(previous) = guard.take() {
                previous.stop();
            }
            *guard = Some(player);
        }
        *lock(&self.source_bytes) = Some(bytes);
        *lock(&self.pos_anchor) = (0.0, 0.0);
        self.active.store(true, Ordering::Release);
        Ok(duration)
    }

    pub fn play(&self) {
        self.with_player(Player::play);
    }

    pub fn pause(&self) {
        self.with_player(Player::pause);
    }

    pub fn stop(&self) {
        if let Some(player) = lock(&self.player).take() {
            player.stop();
        }
        *lock(&self.source_bytes) = None;
        self.active.store(false, Ordering::Release);
    }

    pub fn set_volume(&self, volume: f64) {
        let volume = (volume as f32).clamp(0.0, VOLUME_MAX);
        self.with_player(|player| player.set_volume(volume));
    }

    /// Hover-превью: проиграть файл на отдельном плеере того же миксера (поверх
    /// основного НЕ зовём — гейтит слой выше). Снимает предыдущую превью-ноту.
    pub async fn preview_play(&self, path: &Path, volume: f64) -> Result<(), AudioError> {
        let path = path.to_owned();
        let bytes = tokio::task::spawn_blocking(move || std::fs::read(&path))
            .await
            .map_err(|e| AudioError::Decode(e.to_string()))?
            .map_err(|e| AudioError::Decode(e.to_string()))?;
        let mixer = self.current_mixer();
        let vol = (volume as f32).clamp(0.0, VOLUME_MAX);
        let player = tokio::task::spawn_blocking(move || build_preview_player(&bytes, &mixer, vol))
            .await
            .map_err(|e| AudioError::Decode(e.to_string()))??;
        if let Some(previous) = lock(&self.preview).take() {
            previous.stop();
        }
        *lock(&self.preview_vol) = vol;
        *lock(&self.preview) = Some(player);
        Ok(())
    }

    /// Снять превью: `fade_ms>0` — плавно гасим (плеер уходит во владение задачи,
    /// чтобы новое превью не мешало), иначе мгновенно.
    pub fn preview_stop(&self, fade_ms: u64) {
        let Some(player) = lock(&self.preview).take() else {
            return;
        };
        if fade_ms == 0 {
            player.stop();
            return;
        }
        let start = *lock(&self.preview_vol);
        tokio::spawn(async move {
            const STEPS: u32 = 16;
            let step = Duration::from_millis((fade_ms / STEPS as u64).max(1));
            for i in 1..=STEPS {
                player.set_volume((start * (1.0 - i as f32 / STEPS as f32)).max(0.0));
                tokio::time::sleep(step).await;
            }
            player.stop();
        });
    }

    /// Смена скорости. Закрывает текущий constant-rate сегмент в интегратор
    /// ПЕРЕД переключением — source-время остаётся точным (Tauri set_playback_rate).
    pub fn set_speed(&self, speed: f64) {
        let value = (speed as f32).clamp(SPEED_MIN, SPEED_MAX);
        let guard = lock(&self.player);
        if let Some(player) = guard.as_ref() {
            let old_rate = (*lock(&self.playback_rate) as f64).max(0.01);
            let out = player.get_pos().as_secs_f64();
            {
                let mut anchor = lock(&self.pos_anchor);
                anchor.0 += (out - anchor.1) * old_rate;
                anchor.1 = out;
            }
            *lock(&self.playback_rate) = value;
            player.set_speed(value);
        } else {
            *lock(&self.playback_rate) = value;
        }
    }

    /// Seek в source-секундах. try_seek работает в output-time = source/rate.
    pub fn seek(&self, position_secs: f64) -> Result<(), AudioError> {
        let rate = (*lock(&self.playback_rate) as f64).max(0.01);
        let output_target = (position_secs / rate).max(0.0);
        let target = Duration::try_from_secs_f64(output_target)
            .map_err(|_| AudioError::Decode("invalid seek position".into()))?;
        match lock(&self.player).as_ref() {
            Some(player) => {
                player.try_seek(target).map_err(|e| AudioError::Decode(format!("seek: {e}")))?;
                *lock(&self.pos_anchor) = (position_secs.max(0.0), output_target);
                Ok(())
            }
            // Нет трека — seek это no-op, а не ошибка (не спамим тост «no track loaded»).
            None => Ok(()),
        }
    }

    /// Позиция в source-секундах (интегрирована из output-time get_pos).
    pub fn position_secs(&self) -> f64 {
        let rate = (*lock(&self.playback_rate) as f64).max(0.01);
        let (src_anchor, out_anchor) = *lock(&self.pos_anchor);
        lock(&self.player)
            .as_ref()
            .map_or(0.0, |player| {
                (src_anchor + (player.get_pos().as_secs_f64() - out_anchor) * rate).max(0.0)
            })
    }

    pub fn is_playing(&self) -> bool {
        lock(&self.player)
            .as_ref()
            .is_some_and(|player| !player.is_paused() && !player.empty())
    }

    /// Включить/выключить EQ и задать гейны полос (дБ, клампятся ±12).
    pub fn set_eq(&self, enabled: bool, gains: &[f64]) {
        if let Ok(mut params) = self.eq_params.write() {
            params.enabled = enabled;
            for (index, &gain) in gains.iter().enumerate().take(EQ_BANDS) {
                params.gains[index] = gain.clamp(-12.0, 12.0);
            }
        }
    }

    /// Задать/снять A-B-луп (source-секунды). Валиден, если `b > a + 0.05`.
    pub fn set_ab_loop(&self, a: Option<f64>, b: Option<f64>) {
        let value = match (a, b) {
            (Some(a), Some(b)) if b > a + 0.05 => Some((a.max(0.0), b)),
            _ => None,
        };
        *lock(&self.ab_loop) = value;
    }

    pub fn subscribe(&self) -> broadcast::Receiver<AudioEvent> {
        self.events.subscribe()
    }

    /// Подписаться на поток лог-полос спектра (~30 Гц). FFT считается только пока
    /// есть подписчик (CPU-idle иначе).
    pub fn subscribe_spectrum(&self) -> broadcast::Receiver<Vec<f32>> {
        self.spectrum.subscribe()
    }

    /// Текущий mixer активного устройства (клон-ручка).
    pub(crate) fn current_mixer(&self) -> Mixer {
        lock(&self.mixer).clone()
    }

    fn with_player(&self, action: impl FnOnce(&Player)) {
        if let Some(player) = lock(&self.player).as_ref() {
            action(player);
        }
    }

    fn spawn_poller(&self) {
        let player = self.player.clone();
        let active = self.active.clone();
        let events = self.events.clone();
        let ab_loop = self.ab_loop.clone();
        let rate = self.playback_rate.clone();
        let anchor = self.pos_anchor.clone();
        tokio::spawn(async move {
            let mut interval = tokio::time::interval(TICK_INTERVAL);
            loop {
                interval.tick().await;
                if !active.load(Ordering::Acquire) {
                    continue;
                }
                let r = (*lock(&rate) as f64).max(0.01);
                let (src_anchor, out_anchor) = *lock(&anchor);
                let (position_secs, finished) = {
                    let guard = lock(&player);
                    match guard.as_ref() {
                        Some(p) => (
                            (src_anchor + (p.get_pos().as_secs_f64() - out_anchor) * r).max(0.0),
                            p.empty(),
                        ),
                        None => (0.0, true),
                    }
                };

                // A-B-луп: перескочили B → откат к A (Tauri tick.rs enforce).
                if let Some((a, b)) = *lock(&ab_loop)
                    && position_secs >= b
                {
                    let out_target = (a / r).max(0.0);
                    if let Some(p) = lock(&player).as_ref()
                        && let Ok(target) = Duration::try_from_secs_f64(out_target)
                        && p.try_seek(target).is_ok()
                    {
                        *lock(&anchor) = (a.max(0.0), out_target);
                    }
                    let _ = events.send(AudioEvent::Tick { position_secs: a });
                    continue;
                }

                let _ = events.send(AudioEvent::Tick { position_secs });
                if finished {
                    active.store(false, Ordering::Release);
                    // Ended — только при реальном доигрывании. Пустой/битый декод
                    // делает player.empty() сразу (position≈0): это не «конец»,
                    // а провал воспроизведения — НЕ авто-продолжаем (иначе прыжок
                    // на следующий трек), ошибка всплывёт отдельно.
                    if position_secs > 0.5 {
                        let _ = events.send(AudioEvent::Ended);
                    }
                }
            }
        });
    }
}

/// Собрать плеер: decoder → GainSource(норм) → EqSource → AnalyserSource (кран
/// PCM для FFT). m4a-only (symphonia). Порядок цепи 1:1 с Tauri `decode.rs`.
pub(crate) fn build_player(
    bytes: &[u8],
    mixer: &Mixer,
    gain: f32,
    eq: Arc<RwLock<EqParams>>,
    analyser: Arc<AnalyserBuffer>,
    start_paused: bool,
) -> Result<(Player, Option<f64>), AudioError> {
    let decoder =
        Decoder::new(Cursor::new(bytes.to_vec())).map_err(|e| AudioError::Decode(e.to_string()))?;
    let duration = decoder.total_duration().map(|d| d.as_secs_f64());
    let player = Player::connect_new(mixer);
    if start_paused {
        player.pause();
    }
    player.append(AnalyserSource::new(
        EqSource::new(GainSource::new(decoder, gain), eq),
        analyser,
    ));
    Ok((player, duration))
}

/// Плеер превью: чистый декод на миксер (без EQ/анализатора), играет сразу.
fn build_preview_player(bytes: &[u8], mixer: &Mixer, volume: f32) -> Result<Player, AudioError> {
    let decoder = Decoder::new(Cursor::new(bytes.to_vec()))
        .map_err(|e| AudioError::Decode(e.to_string()))?;
    let player = Player::connect_new(mixer);
    player.set_volume(volume);
    player.append(decoder);
    Ok(player)
}

pub(crate) fn apply_rate(player: &Player, rate: f32) {
    if (rate - 1.0).abs() > f32::EPSILON {
        player.set_speed(rate);
    }
}

pub(crate) fn lock<T>(slot: &Mutex<T>) -> MutexGuard<'_, T> {
    slot.lock().unwrap_or_else(|poison| poison.into_inner())
}
