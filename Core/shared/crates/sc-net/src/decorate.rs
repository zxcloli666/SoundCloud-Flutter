//! Декоратор исходящих запросов: общие реквизиты (User-Agent, x-session-id) на
//! каждый запрос. Работает на нашем `HttpRequest` — reqwest наружу не течёт.
//! Источник сессии инъектируется (порт к `sc-auth`), не зашит.

use std::sync::Arc;

use crate::request::HttpRequest;

pub trait RequestDecorator: Send + Sync {
    fn decorate(&self, req: HttpRequest) -> HttpRequest;
}

/// Порт к владельцу сессии (реализуется в `sc-auth`).
pub trait SessionSource: Send + Sync {
    fn session_id(&self) -> Option<String>;
}

/// Аноним — сессии нет.
pub struct NoSession;

impl SessionSource for NoSession {
    fn session_id(&self) -> Option<String> {
        None
    }
}

/// Ничего не меняет.
pub struct NoopDecorator;

impl RequestDecorator for NoopDecorator {
    fn decorate(&self, req: HttpRequest) -> HttpRequest {
        req
    }
}

/// Добавляет User-Agent (если не задан) и x-session-id (если сессия активна).
/// client_id здесь НЕ добавляем — он специфичен для сырого SC и живёт в `sc-raw`.
pub struct ScCredentials {
    session: Arc<dyn SessionSource>,
    user_agent: String,
}

impl ScCredentials {
    pub fn new(session: Arc<dyn SessionSource>, user_agent: impl Into<String>) -> Self {
        Self {
            session,
            user_agent: user_agent.into(),
        }
    }
}

impl RequestDecorator for ScCredentials {
    fn decorate(&self, mut req: HttpRequest) -> HttpRequest {
        if !has_header(&req, "user-agent") {
            req.headers
                .push(("User-Agent".to_owned(), self.user_agent.clone()));
        }
        if let Some(session_id) = self.session.session_id()
            && !has_header(&req, "x-session-id")
        {
            req.headers.push(("x-session-id".to_owned(), session_id));
        }
        req
    }
}

fn has_header(req: &HttpRequest, name: &str) -> bool {
    req.headers
        .iter()
        .any(|(key, _)| key.eq_ignore_ascii_case(name))
}
