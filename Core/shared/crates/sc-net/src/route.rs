use std::collections::HashMap;
use std::sync::Arc;

use tracing::warn;

use crate::error::NetError;
use crate::request::{HttpRequest, HttpResponse, NetStream};
use crate::retry::{RetryPolicy, Retryable, is_retryable, is_retryable_status};
use crate::transport::Transport;

/// Упорядоченная цепочка транспортов: пробуем по очереди, пока один не пробьёт.
#[derive(Clone)]
pub struct Route {
    transports: Vec<Arc<dyn Transport>>,
}

impl Route {
    pub fn new(transports: Vec<Arc<dyn Transport>>) -> Self {
        Self { transports }
    }

    pub fn single(transport: Arc<dyn Transport>) -> Self {
        Self {
            transports: vec![transport],
        }
    }
}

/// Карта «host → как доставлять» + политика повторов. Сердце кастомизации сети.
pub struct Router {
    default: Route,
    by_host: HashMap<String, Route>,
    retry: RetryPolicy,
}

impl Router {
    pub fn new(default: Route) -> Self {
        Self::with_retry(default, RetryPolicy::default())
    }

    pub fn with_retry(default: Route, retry: RetryPolicy) -> Self {
        Self {
            default,
            by_host: HashMap::new(),
            retry,
        }
    }

    pub fn route_host(&mut self, host: impl Into<String>, route: Route) {
        self.by_host.insert(host.into(), route);
    }

    fn route_for(&self, req: &HttpRequest) -> &Route {
        req.host()
            .and_then(|host| self.by_host.get(&host))
            .unwrap_or(&self.default)
    }

    pub async fn execute(&self, req: &HttpRequest) -> Result<HttpResponse, NetError> {
        self.execute_with(req, &self.retry).await
    }

    /// Исполнить с конкретной политикой: backoff поверх цепочки транспортов.
    /// Повтор — на сетевую ошибку ([`is_retryable`]) ИЛИ на повторяемый статус
    /// успешного ответа ([`is_retryable_status`]: 429/5xx).
    pub async fn execute_with(
        &self,
        req: &HttpRequest,
        policy: &RetryPolicy,
    ) -> Result<HttpResponse, NetError> {
        let mut with_timeout;
        let req = if req.timeout.is_none() && policy.request_timeout.is_some() {
            with_timeout = req.clone();
            with_timeout.timeout = policy.request_timeout;
            &with_timeout
        } else {
            req
        };

        let route = self.route_for(req);
        let max_attempts = policy.max_attempts();
        let mut attempt: u32 = 1;
        loop {
            let result = Self::try_chain(route, req).await;
            let retryable = match &result {
                Ok(resp) => is_retryable_status(resp.status),
                Err(error) => is_retryable(error),
            };
            if matches!(retryable, Retryable::No) || attempt >= max_attempts {
                return match result {
                    Err(error) if attempt > 1 => {
                        Err(NetError::RetriesExhausted(attempt, Box::new(error)))
                    }
                    other => other,
                };
            }
            let delay = policy.delay_for(attempt + 1);
            if !delay.is_zero() {
                tokio::time::sleep(delay).await;
            }
            attempt += 1;
        }
    }

    /// Скачать тело потоком (для прогресса) по тому же маршруту. Без retry-обёртки:
    /// повтор посреди тела бессмыслен, фолбэк источников живёт уровнем выше
    /// (`sc-cache`). Один проход по цепочке: первый открывшийся транспорт побеждает.
    pub async fn download(&self, req: &HttpRequest) -> Result<NetStream, NetError> {
        let route = self.route_for(req);
        let mut last_error = None;
        for transport in &route.transports {
            match transport.execute_stream(req).await {
                Ok(stream) => return Ok(stream),
                Err(error) => {
                    warn!(kind = ?transport.kind(), %error, "stream transport failed, trying next");
                    last_error = Some(error);
                }
            }
        }
        Err(last_error.unwrap_or_else(|| NetError::Exhausted(req.host().unwrap_or_default())))
    }

    /// Один проход по цепочке: первый успех или последняя ошибка.
    async fn try_chain(route: &Route, req: &HttpRequest) -> Result<HttpResponse, NetError> {
        let mut last_error = None;
        for transport in &route.transports {
            match transport.execute(req).await {
                Ok(resp) => return Ok(resp),
                Err(error) => {
                    warn!(kind = ?transport.kind(), %error, "transport failed, trying next");
                    last_error = Some(error);
                }
            }
        }
        Err(last_error.unwrap_or_else(|| NetError::Exhausted(req.host().unwrap_or_default())))
    }
}
