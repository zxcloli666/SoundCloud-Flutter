//! Пул бэкенд-хостов с failover (main ⇄ star) — общий для десктопа и телефона.
//!
//! Держит базовые URL обоих хостов, per-host health-вердикты с экспоненциальным
//! бэкоффом и подтверждением, и отдаёт упорядоченный список баз под класс
//! запроса ([`Plane`]). Чистая логика: исполнение запросов и `/health`-пробинг —
//! на вызывающем (`sc-bff`); пул только решает «куда и в каком порядке» и копит
//! вердикты. Source of truth статуса хостов и premium — здесь, не в UI.

use std::sync::Arc;
use std::sync::Mutex;
use std::time::{Duration, Instant};

use tokio::sync::{Notify, watch};

/// Идентификатор бэкенда.
#[derive(Clone, Copy, PartialEq, Eq, Debug, Hash)]
pub enum HostId {
    Main,
    Star,
}

/// Текущий вердикт по хосту (для UI и выбора порядка).
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Verdict {
    Up,
    Down,
    Unknown,
}

/// Класс запроса — определяет порядок перебора хостов.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Plane {
    /// `/auth/*` — один хост, без fallback-ретрая (токены per-host/одноразовые).
    Control,
    /// Идемпотентные GET/HEAD — премиум на STAR с деградацией на MAIN.
    Data,
    /// `/me/subscription` — пробуем оба (статус нужен даже на одном живом).
    Subscription,
    /// POST/PUT/DELETE — приоритет как Data, но резерв ТОЛЬКО при [`FailKind::Connect`].
    Mutation,
    /// Аудио-стрим — премиум на STAR-stream с деградацией на MAIN-stream.
    Stream,
}

/// Род провала запроса. Мутации уходят на резерв ТОЛЬКО при `Connect`
/// (ответа не было) — иначе риск двойного применения.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum FailKind {
    /// Соединение не состоялось (DNS/connect/TLS/обрыв) — ответа не было.
    Connect,
    /// Таймаут запроса.
    Timeout,
    /// Хост ответил 5xx.
    ServerError,
}

impl FailKind {
    /// Безопасно ли ретраить мутацию на резервном хосте после такого провала.
    pub fn mutation_retryable(self) -> bool {
        matches!(self, FailKind::Connect)
    }
}

/// Снимок состояния для UI (через мост): вердикты + premium.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct HostStatus {
    pub main: Verdict,
    pub star: Verdict,
    pub premium: bool,
}

/// Сколько хост считается нездоровым после провала (экспоненциальный бэкофф).
fn backoff(step: u32) -> Duration {
    Duration::from_secs(match step {
        0 => 5,
        1 => 10,
        2 => 20,
        3 => 40,
        _ => 60,
    })
}

/// Нужно 2 подряд провала (или подтверждённый dead-пробинг), чтобы вердикт упал
/// в `Down` — один промах не роняет (флап ≠ смерть).
const CONFIRM_FAILS: u32 = 2;

#[derive(Clone, Copy)]
struct Health {
    verdict: Verdict,
    cooldown_until: Option<Instant>,
    consecutive_fails: u32,
    backoff_step: u32,
}

impl Health {
    const fn new() -> Self {
        Self {
            verdict: Verdict::Unknown,
            cooldown_until: None,
            consecutive_fails: 0,
            backoff_step: 0,
        }
    }

    fn cooled(&self, now: Instant) -> bool {
        self.cooldown_until.is_some_and(|t| now < t)
    }
}

struct Inner {
    main: Health,
    star: Health,
    premium: bool,
}

impl Inner {
    fn get(&self, id: HostId) -> &Health {
        match id {
            HostId::Main => &self.main,
            HostId::Star => &self.star,
        }
    }

    fn get_mut(&mut self, id: HostId) -> &mut Health {
        match id {
            HostId::Main => &mut self.main,
            HostId::Star => &mut self.star,
        }
    }
}

/// Пул хостов: базы + health + premium. Потокобезопасен (внутренний `Mutex`),
/// дёргается из любого числа задач. Меняется состояние — эмитит [`HostStatus`]
/// в `watch` ([`HostPool::subscribe`]): UI реагирует без поллинга.
pub struct HostPool {
    main_api: String,
    star_api: String,
    main_stream: String,
    star_stream: String,
    inner: Mutex<Inner>,
    status_tx: watch::Sender<HostStatus>,
    recheck: Arc<Notify>,
}

impl HostPool {
    pub fn new(
        main_api: impl Into<String>,
        star_api: impl Into<String>,
        main_stream: impl Into<String>,
        star_stream: impl Into<String>,
    ) -> Self {
        let initial = HostStatus {
            main: Verdict::Unknown,
            star: Verdict::Unknown,
            premium: false,
        };
        Self {
            main_api: main_api.into(),
            star_api: star_api.into(),
            main_stream: main_stream.into(),
            star_stream: star_stream.into(),
            inner: Mutex::new(Inner {
                main: Health::new(),
                star: Health::new(),
                premium: false,
            }),
            status_tx: watch::channel(initial).0,
            recheck: Arc::new(Notify::new()),
        }
    }

    /// Подписаться на изменения статуса хостов (для моста → UI-модалок).
    pub fn subscribe(&self) -> watch::Receiver<HostStatus> {
        self.status_tx.subscribe()
    }

    /// Запросить внеочередную перепроверку подписки (STAR ответил 403 на
    /// премиум-claim — возможно, подписка истекла). Будит рефрешер в `sc-core`.
    pub fn request_recheck(&self) {
        self.recheck.notify_one();
    }

    /// Хэндл нотификации перепроверки — рефрешер ждёт на нём (см. `request_recheck`).
    pub fn recheck_handle(&self) -> Arc<Notify> {
        self.recheck.clone()
    }

    /// Premium-статус (из подписки) — открывает STAR для data/stream.
    pub fn set_premium(&self, premium: bool) {
        {
            self.lock().premium = premium;
        }
        self.emit();
    }

    pub fn is_premium(&self) -> bool {
        self.lock().premium
    }

    /// Упорядоченные базы под класс запроса: не-остывшие раньше остывших,
    /// приоритет класса сохраняется. Перебирать по порядку до первого успеха.
    pub fn order(&self, plane: Plane) -> Vec<(HostId, String)> {
        let inner = self.lock();
        let now = Instant::now();
        let mut prio = match plane {
            Plane::Control => Self::control_prio(&inner),
            Plane::Subscription => Self::sub_prio(&inner),
            Plane::Data | Plane::Mutation | Plane::Stream => {
                if inner.premium {
                    vec![HostId::Star, HostId::Main]
                } else {
                    vec![HostId::Main]
                }
            }
        };
        // Остывшие (нездоровые) — в хвост; среди равных порядок класса сохраняется.
        prio.sort_by_key(|h| inner.get(*h).cooled(now));
        prio.into_iter()
            .map(|h| (h, self.base(h, plane).to_owned()))
            .collect()
    }

    /// Зафиксировать успех: хост `Up`, бэкофф/счётчики сброшены.
    pub fn record_success(&self, host: HostId) {
        {
            *self.lock().get_mut(host) = Health::new().up();
        }
        self.emit();
    }

    /// Зафиксировать провал: бэкофф растёт; после [`CONFIRM_FAILS`] → `Down`.
    pub fn record_failure(&self, host: HostId, _kind: FailKind) {
        {
            let mut inner = self.lock();
            let h = inner.get_mut(host);
            h.consecutive_fails = h.consecutive_fails.saturating_add(1);
            h.cooldown_until = Some(Instant::now() + backoff(h.backoff_step));
            h.backoff_step = h.backoff_step.saturating_add(1);
            if h.consecutive_fails >= CONFIRM_FAILS {
                h.verdict = Verdict::Down;
            }
        }
        self.emit();
    }

    /// Результат `/health`-пробинга: подтверждает `Up`/`Down` напрямую.
    pub fn mark_probe(&self, host: HostId, alive: bool) {
        {
            let mut inner = self.lock();
            let h = inner.get_mut(host);
            if alive {
                *h = Health::new().up();
            } else {
                h.verdict = Verdict::Down;
                h.cooldown_until = Some(Instant::now() + backoff(h.backoff_step));
                h.backoff_step = h.backoff_step.saturating_add(1);
            }
        }
        self.emit();
    }

    pub fn verdict(&self, host: HostId) -> Verdict {
        self.lock().get(host).verdict
    }

    pub fn snapshot(&self) -> HostStatus {
        let inner = self.lock();
        HostStatus {
            main: inner.main.verdict,
            star: inner.star.verdict,
            premium: inner.premium,
        }
    }

    // --- внутреннее ---

    fn base(&self, host: HostId, plane: Plane) -> &str {
        match (plane, host) {
            (Plane::Stream, HostId::Main) => &self.main_stream,
            (Plane::Stream, HostId::Star) => &self.star_stream,
            (_, HostId::Main) => &self.main_api,
            (_, HostId::Star) => &self.star_api,
        }
    }

    /// Control: MAIN, если не `down`; иначе STAR если `up`; иначе всё равно MAIN.
    fn control_prio(inner: &Inner) -> Vec<HostId> {
        if inner.main.verdict != Verdict::Down {
            vec![HostId::Main]
        } else if inner.star.verdict == Verdict::Up {
            vec![HostId::Star]
        } else {
            vec![HostId::Main]
        }
    }

    /// Subscription: оба; первым — живой MAIN, иначе STAR.
    fn sub_prio(inner: &Inner) -> Vec<HostId> {
        if inner.main.verdict == Verdict::Down {
            vec![HostId::Star, HostId::Main]
        } else {
            vec![HostId::Main, HostId::Star]
        }
    }

    fn lock(&self) -> std::sync::MutexGuard<'_, Inner> {
        self.inner.lock().unwrap_or_else(|p| p.into_inner())
    }

    /// Опубликовать текущий снимок подписчикам (без лишних будоражений — `watch`
    /// сам схлопывает равные значения у получателя).
    fn emit(&self) {
        let snapshot = self.snapshot();
        let _ = self.status_tx.send(snapshot);
    }
}

impl Health {
    fn up(mut self) -> Self {
        self.verdict = Verdict::Up;
        self
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn pool() -> HostPool {
        HostPool::new(
            "https://api.example",
            "https://api-star.example",
            "https://stream.example",
            "https://stream-star.example",
        )
    }

    #[test]
    fn non_premium_data_is_main_only() {
        let p = pool();
        let order = p.order(Plane::Data);
        assert_eq!(order.len(), 1);
        assert_eq!(order[0].0, HostId::Main);
    }

    #[test]
    fn premium_data_prefers_star_then_main() {
        let p = pool();
        p.set_premium(true);
        let ids: Vec<_> = p.order(Plane::Data).into_iter().map(|(h, _)| h).collect();
        assert_eq!(ids, vec![HostId::Star, HostId::Main]);
    }

    #[test]
    fn subscription_tries_both() {
        let p = pool();
        let ids: Vec<_> = p
            .order(Plane::Subscription)
            .into_iter()
            .map(|(h, _)| h)
            .collect();
        assert_eq!(ids, vec![HostId::Main, HostId::Star]);
    }

    #[test]
    fn confirm_before_down() {
        let p = pool();
        p.record_failure(HostId::Main, FailKind::ServerError);
        assert_eq!(p.verdict(HostId::Main), Verdict::Unknown); // один промах не роняет
        p.record_failure(HostId::Main, FailKind::ServerError);
        assert_eq!(p.verdict(HostId::Main), Verdict::Down);
    }

    #[test]
    fn success_clears_down() {
        let p = pool();
        p.record_failure(HostId::Star, FailKind::Connect);
        p.record_failure(HostId::Star, FailKind::Connect);
        assert_eq!(p.verdict(HostId::Star), Verdict::Down);
        p.record_success(HostId::Star);
        assert_eq!(p.verdict(HostId::Star), Verdict::Up);
    }

    #[test]
    fn cooled_host_sinks_to_tail() {
        let p = pool();
        p.set_premium(true);
        // STAR остыл после провала → MAIN должен идти первым.
        p.record_failure(HostId::Star, FailKind::Timeout);
        let ids: Vec<_> = p.order(Plane::Data).into_iter().map(|(h, _)| h).collect();
        assert_eq!(ids, vec![HostId::Main, HostId::Star]);
    }

    #[test]
    fn stream_uses_stream_bases() {
        let p = pool();
        p.set_premium(true);
        let order = p.order(Plane::Stream);
        assert_eq!(order[0].1, "https://stream-star.example");
        assert_eq!(order[1].1, "https://stream.example");
    }

    #[test]
    fn mutation_retry_only_on_connect() {
        assert!(FailKind::Connect.mutation_retryable());
        assert!(!FailKind::ServerError.mutation_retryable());
        assert!(!FailKind::Timeout.mutation_retryable());
    }
}
