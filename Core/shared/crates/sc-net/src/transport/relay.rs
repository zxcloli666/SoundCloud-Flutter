use async_trait::async_trait;
use base64::Engine;

use super::{Transport, TransportKind, send_with};
use crate::error::NetError;
use crate::request::{HttpRequest, HttpResponse};

/// Доставка через наш edge/relay: исходный URL уезжает в заголовок `X-Target`
/// (base64), запрос идёт на фиксированный relay-эндпоинт. Совместимо с нашей
/// bypass-проксёй (она ждёт `X-Target: base64(url)`).
pub struct RelayTransport {
    client: reqwest::Client,
    relay_base: String,
    auth: Option<(String, String)>,
}

impl RelayTransport {
    pub fn new(relay_base: impl Into<String>) -> Result<Self, NetError> {
        Ok(Self {
            client: reqwest::Client::builder().build()?,
            relay_base: relay_base.into(),
            auth: None,
        })
    }

    pub fn with_client(relay_base: impl Into<String>, client: reqwest::Client) -> Self {
        Self {
            client,
            relay_base: relay_base.into(),
            auth: None,
        }
    }

    pub fn with_auth(mut self, header: impl Into<String>, value: impl Into<String>) -> Self {
        self.auth = Some((header.into(), value.into()));
        self
    }

    fn rewrap(&self, req: &HttpRequest) -> HttpRequest {
        let target = base64::engine::general_purpose::STANDARD.encode(req.url.as_bytes());
        let mut headers = req.headers.clone();
        headers.push(("X-Target".to_owned(), target));
        if let Some((header, value)) = &self.auth {
            headers.push((header.clone(), value.clone()));
        }
        HttpRequest {
            method: req.method,
            url: self.relay_base.clone(),
            headers,
            body: req.body.clone(),
            timeout: req.timeout,
        }
    }
}

#[async_trait]
impl Transport for RelayTransport {
    async fn execute(&self, req: &HttpRequest) -> Result<HttpResponse, NetError> {
        send_with(&self.client, &self.rewrap(req)).await
    }

    fn kind(&self) -> TransportKind {
        TransportKind::Relay
    }
}
