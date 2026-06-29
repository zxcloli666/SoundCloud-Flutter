//! Параметрический 10-полосный EQ поверх rodio Source (порт
//! `src-tauri/audio/eq.rs` 1:1). `GainSource` — нормализационный множитель;
//! `EqSource` — biquad-каскад (low-shelf / peaking / high-shelf) с горячим
//! пересчётом коэффициентов при смене гейнов.

use std::sync::{Arc, RwLock};
use std::time::Duration;

use biquad::{Biquad, Coefficients, DirectForm1, Hertz, Q_BUTTERWORTH_F64, ToHertz, Type};
use rodio::Source;
use rodio::source::SeekError;

use crate::types::{ChannelCount, EQ_BANDS, EQ_FREQS, EQ_Q, EqParams, SampleRate};

pub(crate) struct GainSource<S: Source<Item = f32>> {
    source: S,
    gain: f32,
}

impl<S: Source<Item = f32>> GainSource<S> {
    pub(crate) fn new(source: S, gain: f32) -> Self {
        Self { source, gain }
    }
}

impl<S: Source<Item = f32>> Iterator for GainSource<S> {
    type Item = f32;

    fn next(&mut self) -> Option<f32> {
        self.source.next().map(|sample| (sample * self.gain).clamp(-1.0, 1.0))
    }
}

impl<S: Source<Item = f32>> Source for GainSource<S> {
    fn current_span_len(&self) -> Option<usize> {
        self.source.current_span_len()
    }

    fn channels(&self) -> ChannelCount {
        self.source.channels()
    }

    fn sample_rate(&self) -> SampleRate {
        self.source.sample_rate()
    }

    fn total_duration(&self) -> Option<Duration> {
        self.source.total_duration()
    }

    fn try_seek(&mut self, pos: Duration) -> Result<(), SeekError> {
        self.source.try_seek(pos)
    }
}

pub(crate) struct EqSource<S: Source<Item = f32>> {
    source: S,
    params: Arc<RwLock<EqParams>>,
    filters_l: [DirectForm1<f64>; EQ_BANDS],
    filters_r: [DirectForm1<f64>; EQ_BANDS],
    channels: ChannelCount,
    sample_rate: SampleRate,
    current_channel: u16,
    cached_gains: [f64; EQ_BANDS],
    cached_enabled: bool,
}

impl<S: Source<Item = f32>> EqSource<S> {
    pub(crate) fn new(source: S, params: Arc<RwLock<EqParams>>) -> Self {
        let sample_rate = source.sample_rate();
        let channels = source.channels();
        Self {
            source,
            params,
            filters_l: make_filters(sample_rate, &[0.0; EQ_BANDS]),
            filters_r: make_filters(sample_rate, &[0.0; EQ_BANDS]),
            channels,
            sample_rate,
            current_channel: 0,
            cached_gains: [0.0; EQ_BANDS],
            cached_enabled: false,
        }
    }

    fn update_coefficients(&mut self, gains: &[f64; EQ_BANDS]) {
        let fs: Hertz<f64> = (self.sample_rate.get() as f64).hz();
        for (i, &gain) in gains.iter().enumerate() {
            if (gain - self.cached_gains[i]).abs() >= 0.01
                && let Ok(coeffs) = band_coeffs(fs, i, gain)
            {
                self.filters_l[i] = DirectForm1::<f64>::new(coeffs);
                self.filters_r[i] = DirectForm1::<f64>::new(coeffs);
            }
        }
        self.cached_gains = *gains;
    }
}

fn band_coeffs(
    fs: Hertz<f64>,
    band: usize,
    gain: f64,
) -> Result<Coefficients<f64>, biquad::Errors> {
    let filter_type = if band == 0 {
        Type::LowShelf(gain)
    } else if band == EQ_BANDS - 1 {
        Type::HighShelf(gain)
    } else {
        Type::PeakingEQ(gain)
    };
    let q = if band == 0 || band == EQ_BANDS - 1 {
        Q_BUTTERWORTH_F64
    } else {
        EQ_Q
    };
    Coefficients::<f64>::from_params(filter_type, fs, EQ_FREQS[band].hz(), q)
}

fn make_filters(sample_rate: SampleRate, gains: &[f64; EQ_BANDS]) -> [DirectForm1<f64>; EQ_BANDS] {
    let fs: Hertz<f64> = (sample_rate.get() as f64).hz();
    std::array::from_fn(|i| {
        let coeffs = band_coeffs(fs, i, gains[i])
            .unwrap_or_else(|_| flat_coeffs(fs, EQ_FREQS[i]));
        DirectForm1::<f64>::new(coeffs)
    })
}

/// Прозрачный фильтр (gain 0) — фолбэк, если коэффициенты не посчитались.
fn flat_coeffs(fs: Hertz<f64>, freq: f64) -> Coefficients<f64> {
    Coefficients::<f64>::from_params(Type::PeakingEQ(0.0), fs, freq.hz(), EQ_Q)
        .unwrap_or(Coefficients {
            a1: 0.0,
            a2: 0.0,
            b0: 1.0,
            b1: 0.0,
            b2: 0.0,
        })
}

impl<S: Source<Item = f32>> Iterator for EqSource<S> {
    type Item = f32;

    fn next(&mut self) -> Option<f32> {
        let sample = self.source.next()?;
        let ch = self.current_channel;
        self.current_channel = (ch + 1) % self.channels.get();

        let snapshot = self.params.try_read().ok().map(|p| (p.enabled, p.gains));
        if let Some((enabled, gains)) = snapshot
            && (enabled != self.cached_enabled || gains != self.cached_gains)
        {
            if enabled {
                self.update_coefficients(&gains);
            }
            self.cached_enabled = enabled;
        }

        if !self.cached_enabled {
            return Some(sample);
        }

        let mut out = sample as f64;
        let filters = if ch == 0 {
            &mut self.filters_l
        } else {
            &mut self.filters_r
        };
        for filter in filters.iter_mut() {
            out = Biquad::run(filter, out);
        }
        Some(out.clamp(-1.0, 1.0) as f32)
    }
}

impl<S: Source<Item = f32>> Source for EqSource<S> {
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
