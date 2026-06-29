//! Спектр-анализатор (порт `src-tauri/audio/analyser.rs` 1:1): таппит PCM в цепи
//! декода, FFT на выделенном потоке, лог-полосы наружу ~30 Гц.
//!
//! Hot-path (`AnalyserSource::next`): без аллокаций/логарифмов/блокировок —
//! усредняем каналы в моно и пушим в кольцевой буфер под `try_lock` (занят FFT —
//! роняем кадр). FFT-поток шлёт `Vec<f32>` в broadcast; когда подписчиков нет —
//! спит, не считая (CPU-idle).

use std::collections::VecDeque;
use std::sync::atomic::{AtomicBool, AtomicU32, Ordering};
use std::sync::{Arc, Mutex};
use std::time::Duration;

use rodio::Source;
use rodio::source::SeekError;
use rustfft::FftPlanner;
use rustfft::num_complex::Complex;
use tokio::sync::broadcast;

use crate::types::{ChannelCount, SampleRate};

const FFT_SIZE: usize = 1024;
const RING_CAPACITY: usize = 4096;
const FFT_INTERVAL_MS: u64 = 33;
pub const NUM_BINS: usize = 64;
const MIN_FREQ_HZ: f32 = 50.0;

pub(crate) struct AnalyserBuffer {
    samples: Mutex<VecDeque<f32>>,
    sample_rate: AtomicU32,
    running: AtomicBool,
}

impl AnalyserBuffer {
    pub(crate) fn new() -> Arc<Self> {
        Arc::new(Self {
            samples: Mutex::new(VecDeque::with_capacity(RING_CAPACITY)),
            sample_rate: AtomicU32::new(44_100),
            running: AtomicBool::new(true),
        })
    }
}

pub(crate) struct AnalyserSource<S: Source<Item = f32>> {
    source: S,
    buffer: Arc<AnalyserBuffer>,
    channels: ChannelCount,
    sample_rate: SampleRate,
    cur_channel: u16,
    accum: f32,
}

impl<S: Source<Item = f32>> AnalyserSource<S> {
    pub(crate) fn new(source: S, buffer: Arc<AnalyserBuffer>) -> Self {
        let channels = source.channels();
        let sample_rate = source.sample_rate();
        buffer.sample_rate.store(sample_rate.get(), Ordering::Relaxed);
        Self {
            source,
            buffer,
            channels,
            sample_rate,
            cur_channel: 0,
            accum: 0.0,
        }
    }
}

impl<S: Source<Item = f32>> Iterator for AnalyserSource<S> {
    type Item = f32;

    fn next(&mut self) -> Option<f32> {
        let sample = self.source.next()?;
        self.accum += sample;
        self.cur_channel += 1;

        // Once per audio frame (all channels seen), push the mono mix.
        if self.cur_channel >= self.channels.get() {
            let mono = self.accum / self.channels.get() as f32;
            self.cur_channel = 0;
            self.accum = 0.0;

            // try_lock — if FFT thread is reading, just drop this frame.
            if let Ok(mut q) = self.buffer.samples.try_lock() {
                if q.len() >= RING_CAPACITY {
                    let drop_n = q.len() - RING_CAPACITY + 1;
                    q.drain(0..drop_n);
                }
                q.push_back(mono);
            }
        }
        Some(sample)
    }
}

impl<S: Source<Item = f32>> Source for AnalyserSource<S> {
    fn current_span_len(&self) -> Option<usize> {
        self.source.current_span_len()
    }
    fn channels(&self) -> ChannelCount {
        self.channels
    }
    fn sample_rate(&self) -> SampleRate {
        self.sample_rate
    }
    fn total_duration(&self) -> Option<Duration> {
        self.source.total_duration()
    }
    fn try_seek(&mut self, pos: Duration) -> Result<(), SeekError> {
        self.source.try_seek(pos)
    }
}

/// FFT-поток на всё время жизни приложения. Дёшев, когда нет подписчиков
/// (broadcast пуст) или нет свежих сэмплов (пауза/загрузка): спит и пропускает.
pub(crate) fn start_fft_thread(buffer: Arc<AnalyserBuffer>, tx: broadcast::Sender<Vec<f32>>) {
    let _ = std::thread::Builder::new()
        .name("audio-fft".into())
        .spawn(move || run_fft_loop(buffer, tx));
}

fn run_fft_loop(buffer: Arc<AnalyserBuffer>, tx: broadcast::Sender<Vec<f32>>) {
    let mut planner = FftPlanner::<f32>::new();
    let fft = planner.plan_fft_forward(FFT_SIZE);

    // Pre-compute Hann window once.
    let mut window = vec![0.0f32; FFT_SIZE];
    for (i, w) in window.iter_mut().enumerate() {
        *w = 0.5 * (1.0 - (2.0 * std::f32::consts::PI * i as f32 / (FFT_SIZE - 1) as f32).cos());
    }

    let mut fft_buf = vec![Complex::new(0.0f32, 0.0); FFT_SIZE];
    let mut bins_smooth = vec![0.0f32; NUM_BINS];
    let mut silence_skips: u32 = 0;
    let mut prev_emit_was_silent = true;

    loop {
        std::thread::sleep(Duration::from_millis(FFT_INTERVAL_MS));
        if !buffer.running.load(Ordering::Relaxed) {
            break;
        }
        // Никто не слушает — не считаем (CPU-idle, как требует контракт).
        if tx.receiver_count() == 0 {
            continue;
        }

        let snapshot: Option<Vec<f32>> = {
            let Ok(q) = buffer.samples.lock() else {
                continue;
            };
            if q.len() < FFT_SIZE {
                None
            } else {
                let start = q.len() - FFT_SIZE;
                Some(q.iter().skip(start).copied().collect())
            }
        };

        let Some(samples) = snapshot else {
            silence_skips = silence_skips.saturating_add(1);
            if !prev_emit_was_silent && silence_skips >= 4 {
                let _ = tx.send(vec![0.0f32; NUM_BINS]);
                prev_emit_was_silent = true;
            }
            continue;
        };

        let peak = samples.iter().fold(0.0f32, |p, &s| p.max(s.abs()));
        if peak < 1e-4 {
            silence_skips = silence_skips.saturating_add(1);
            if !prev_emit_was_silent {
                let _ = tx.send(vec![0.0f32; NUM_BINS]);
                prev_emit_was_silent = true;
            }
            continue;
        }
        silence_skips = 0;

        for (i, slot) in fft_buf.iter_mut().enumerate() {
            *slot = Complex::new(samples[i] * window[i], 0.0);
        }
        fft.process(&mut fft_buf);

        let bins = bucket_bins(&fft_buf, buffer.sample_rate.load(Ordering::Relaxed) as f32);
        for (i, smooth) in bins_smooth.iter_mut().enumerate() {
            *smooth = *smooth * 0.55 + bins[i] * 0.45;
        }
        if tx.send(bins_smooth.clone()).is_ok() {
            prev_emit_was_silent = false;
        }
    }
}

/// Лог-разнос FFT-магнитуд по `NUM_BINS` полосам (max в полосе) + лог-компрессия
/// и нормировка. Эмпирика Tauri: магнитуды бьют ~32 на full-scale music с Hann.
fn bucket_bins(fft_buf: &[Complex<f32>], sample_rate: f32) -> Vec<f32> {
    let nyquist = (sample_rate * 0.5).max(1.0);
    let mag_count = FFT_SIZE / 2;
    let log_min = MIN_FREQ_HZ.ln();
    let log_max = nyquist.ln();
    let log_range = (log_max - log_min).max(1e-3);

    let mut bins = vec![0.0f32; NUM_BINS];
    let nbins = NUM_BINS as f32;
    for (i, c) in fft_buf.iter().take(mag_count).enumerate() {
        let freq = (i as f32) * nyquist / (mag_count as f32);
        if freq < MIN_FREQ_HZ {
            continue;
        }
        let pos = ((freq.ln() - log_min) / log_range).clamp(0.0, 0.999);
        let idx = (pos * nbins) as usize;
        let mag = (c.re * c.re + c.im * c.im).sqrt();
        if mag > bins[idx] {
            bins[idx] = mag;
        }
    }

    let inv_log9 = 1.0 / 10.0_f32.ln();
    for bin in bins.iter_mut() {
        let v = (*bin / 32.0).min(1.0);
        *bin = (1.0 + v * 9.0).ln() * inv_log9;
    }
    bins
}

#[cfg(test)]
mod tests {
    use super::{FFT_SIZE, NUM_BINS, bucket_bins};
    use rustfft::FftPlanner;
    use rustfft::num_complex::Complex;

    /// FFT синуса 1кГц → NUM_BINS полос, и в спектре есть ненулевая энергия.
    /// Доказывает, что FFT-конвейер реально считает спектр.
    #[test]
    fn fft_of_tone_yields_bins_with_energy() {
        let sr = 44_100.0f32;
        let mut buf: Vec<Complex<f32>> = (0..FFT_SIZE)
            .map(|i| {
                let t = i as f32 / sr;
                Complex::new((2.0 * std::f32::consts::PI * 1000.0 * t).sin(), 0.0)
            })
            .collect();
        let fft = FftPlanner::<f32>::new().plan_fft_forward(FFT_SIZE);
        fft.process(&mut buf);
        let bins = bucket_bins(&buf, sr);
        assert_eq!(bins.len(), NUM_BINS);
        assert!(bins.iter().any(|&b| b > 0.0), "tone must produce spectral energy");
    }
}
