//! Повторы и таймауты — кросс-cutting политика поверх выбора маршрута, а не
//! внутри транспортов. Транспорт остаётся «тупой трубой».
//!
//! Backoff — явное расписание задержек (не float-экспонента): так нет риска
//! паники `Duration::from_secs_f64` на inf/NaN (критично под `panic = abort`).

use std::time::Duration;

use crate::error::NetError;

/// Расписание повторов: задержки между попытками + дефолтный per-attempt таймаут.
#[derive(Clone, Debug)]
pub struct RetryPolicy {
    /// Задержки перед 2-й, 3-й, … попытками. `len` повторов → `len + 1` попыток.
    pub backoff: Vec<Duration>,
    /// Таймаут одной попытки, если в запросе не задан свой.
    pub request_timeout: Option<Duration>,
}

impl Default for RetryPolicy {
    fn default() -> Self {
        // Из легаси (load_url): 300/800/2000 мс между попытками.
        Self {
            backoff: vec![
                Duration::from_millis(300),
                Duration::from_millis(800),
                Duration::from_millis(2000),
            ],
            request_timeout: Some(Duration::from_secs(30)),
        }
    }
}

impl RetryPolicy {
    /// Без повторов и без навязанного таймаута — для стримов/больших сегментов,
    /// где повтор делает слой выше.
    pub fn none() -> Self {
        Self {
            backoff: Vec::new(),
            request_timeout: None,
        }
    }

    /// Всего попыток (1 = без повторов).
    pub fn max_attempts(&self) -> u32 {
        self.backoff.len() as u32 + 1
    }

    /// Задержка перед попыткой `attempt` (1-based). Первая попытка — без задержки.
    pub fn delay_for(&self, attempt: u32) -> Duration {
        if attempt < 2 {
            return Duration::ZERO;
        }
        self.backoff
            .get((attempt - 2) as usize)
            .copied()
            .unwrap_or_else(|| self.backoff.last().copied().unwrap_or(Duration::ZERO))
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Retryable {
    Yes,
    No,
}

/// 429 и 5xx — повторяемы; остальное — нет.
pub fn is_retryable_status(status: u16) -> Retryable {
    if status == 429 || (500..=599).contains(&status) {
        Retryable::Yes
    } else {
        Retryable::No
    }
}

/// Классификация ошибки транспорта. Таймауты/обрывы соединения/неудачные
/// запросы — повторяемы; ошибки парсинга/4xx (кроме 429) — нет.
pub fn is_retryable(err: &NetError) -> Retryable {
    match err {
        NetError::Io(_) => Retryable::Yes,
        NetError::Reqwest(e) => {
            if e.is_timeout() || e.is_connect() || e.is_request() {
                Retryable::Yes
            } else {
                Retryable::No
            }
        }
        NetError::Status(status) => is_retryable_status(*status),
        _ => Retryable::No,
    }
}
