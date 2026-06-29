//! Сетевое ядро: **весь** трафик приложения идёт отсюда.
//!
//! Слои сверху вниз:
//! - [`HttpRequest`]/[`HttpResponse`] — транспортно-независимые значения.
//! - [`Transport`] — *как* доставить: [`DirectTransport`], [`ProxyTransport`],
//!   [`BypassTransport`] (пробив DPI), [`RelayTransport`] (через наш edge).
//!   Реализации взаимозаменяемы.
//! - [`Router`] — *куда какой* трафик: карта `host → цепочка транспортов` +
//!   политика повторов ([`RetryPolicy`]). Не пробил/5xx — следующий/повтор.
//! - [`RequestDecorator`] — общие реквизиты (User-Agent, x-session-id) на каждый
//!   запрос; источник сессии инъектируется ([`SessionSource`]).
//! - [`NetConfig`] — декларативная настройка. Меняешь конфиг — весь трафик едет
//!   иначе (другой домен / VPN / прокси / relay / пробив), вызовы не трогаются.
//! - [`NetClient`] — фасад. Доменные методы (поиск/resolve/стрим) строятся
//!   поверх него в `sc-raw`/`sc-core`: `sc-net` остаётся транспортом.

pub mod api;
pub mod storage;
pub mod host;
pub mod stream;

mod client;
mod config;
mod decorate;
mod dispatch;
mod error;
mod request;
mod retry;
mod route;
mod transport;

pub use client::NetClient;
pub use config::{Mode, NetConfig, RelayConfig};
pub use decorate::{NoSession, NoopDecorator, RequestDecorator, ScCredentials, SessionSource};
pub use error::NetError;
pub use host::{FailKind, HostId, HostPool, HostStatus, Plane, Verdict};
pub use request::{HttpRequest, HttpResponse, Method, NetStream};
pub use retry::{RetryPolicy, Retryable, is_retryable, is_retryable_status};
pub use route::{Route, Router};
pub use transport::{
    BypassTransport, DirectTransport, ProxyTransport, RelayTransport, Transport, TransportKind,
};
