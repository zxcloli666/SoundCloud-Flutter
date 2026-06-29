use async_trait::async_trait;

use super::{Transport, TransportKind, send_with};
use crate::error::NetError;
use crate::request::{HttpRequest, HttpResponse};

/// Через произвольный прокси: `http://`, `https://`, `socks5://`, `socks5h://`.
/// Сюда же — «только через VPN»: VPN поднимается как socks/http-эндпоинт.
pub struct ProxyTransport {
    client: reqwest::Client,
}

impl ProxyTransport {
    pub fn new(proxy_url: &str) -> Result<Self, NetError> {
        let proxy = reqwest::Proxy::all(proxy_url)?;
        Ok(Self {
            client: reqwest::Client::builder().proxy(proxy).build()?,
        })
    }
}

#[async_trait]
impl Transport for ProxyTransport {
    async fn execute(&self, req: &HttpRequest) -> Result<HttpResponse, NetError> {
        send_with(&self.client, req).await
    }

    fn kind(&self) -> TransportKind {
        TransportKind::Proxy
    }
}
