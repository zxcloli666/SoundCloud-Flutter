//! Транспорт — способ доставки запроса. Реализации взаимозаменяемы, роутер
//! комбинирует их в цепочки.

mod bypass;
mod direct;
mod proxy;
mod relay;

pub use bypass::BypassTransport;
pub use direct::DirectTransport;
pub use proxy::ProxyTransport;
pub use relay::RelayTransport;

use async_trait::async_trait;
use futures::{StreamExt, TryStreamExt};

use crate::error::NetError;
use crate::request::{HttpRequest, HttpResponse, Method, NetStream};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum TransportKind {
    Direct,
    Proxy,
    Bypass,
    Relay,
}

#[async_trait]
pub trait Transport: Send + Sync {
    async fn execute(&self, req: &HttpRequest) -> Result<HttpResponse, NetError>;
    fn kind(&self) -> TransportKind;

    /// Скачать тело потоком (для прогресса). По умолчанию — буферизуем целиком и
    /// отдаём одним чанком; настоящий стрим даёт только [`DirectTransport`], а
    /// стриминговые хосты закреплены на Direct (см. `sc-core::pin_streaming_direct`).
    async fn execute_stream(&self, req: &HttpRequest) -> Result<NetStream, NetError> {
        Ok(NetStream::whole(self.execute(req).await?.body))
    }
}

/// Собрать reqwest-запрос из транспортно-независимого [`HttpRequest`]. Общий код
/// всех транспортов — разница между ними только в конфигурации клиента.
pub(crate) fn build_request(
    client: &reqwest::Client,
    req: &HttpRequest,
) -> reqwest::RequestBuilder {
    let method = match req.method {
        Method::Get => reqwest::Method::GET,
        Method::Head => reqwest::Method::HEAD,
        Method::Post => reqwest::Method::POST,
        Method::Put => reqwest::Method::PUT,
        Method::Delete => reqwest::Method::DELETE,
    };

    let mut builder = client.request(method, &req.url);
    for (key, value) in &req.headers {
        builder = builder.header(key, value);
    }
    if let Some(body) = &req.body {
        builder = builder.body(body.clone());
    }
    if let Some(timeout) = req.timeout {
        builder = builder.timeout(timeout);
    }
    builder
}

/// Исполнить запрос готовым reqwest-клиентом, прочитав тело целиком.
pub(crate) async fn send_with(
    client: &reqwest::Client,
    req: &HttpRequest,
) -> Result<HttpResponse, NetError> {
    let resp = build_request(client, req).send().await?;
    let status = resp.status().as_u16();
    let headers = resp
        .headers()
        .iter()
        .map(|(k, v)| (k.as_str().to_owned(), v.to_str().unwrap_or_default().to_owned()))
        .collect();
    let body = resp.bytes().await?;

    Ok(HttpResponse {
        status,
        headers,
        body,
    })
}

/// Открыть запрос готовым клиентом и отдать тело чанками. Заголовки читаем сразу
/// (нужна длина для прогресса), статус ≥400 — ошибка (чтобы роутер пробовал
/// следующий транспорт, как в небуферизованном пути).
pub(crate) async fn stream_with(
    client: &reqwest::Client,
    req: &HttpRequest,
) -> Result<NetStream, NetError> {
    let resp = build_request(client, req).send().await?;
    let status = resp.status().as_u16();
    if status >= 400 {
        return Err(NetError::Status(status));
    }
    let content_length = resp.content_length();
    let body = resp.bytes_stream().map_err(NetError::from).boxed();
    Ok(NetStream {
        content_length,
        body,
    })
}
