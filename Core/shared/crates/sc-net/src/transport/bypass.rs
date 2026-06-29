use std::sync::Arc;

use async_trait::async_trait;
use sc_net_bypass::Desync;

use super::{Transport, TransportKind, send_with};
use crate::error::NetError;
use crate::request::{HttpRequest, HttpResponse};

/// Пробив DPI: поднимает локальный десинхронизатор ([`sc_net_bypass`]) и гонит
/// трафик через него. Применяется как фоллбэк, когда прямой путь режут.
pub struct BypassTransport {
    desync: Arc<Desync>,
    client: reqwest::Client,
}

impl BypassTransport {
    pub async fn spawn(enabled: bool) -> Result<Self, NetError> {
        let desync = Desync::spawn(enabled)
            .await
            .map_err(|e| NetError::Io(e.to_string()))?;
        let proxy = reqwest::Proxy::all(desync.proxy_url())?;
        let client = reqwest::Client::builder().proxy(proxy).build()?;
        Ok(Self {
            desync: Arc::new(desync),
            client,
        })
    }

    pub fn desync(&self) -> &Desync {
        &self.desync
    }

    /// Подобрать рабочую стратегию, дёргая `probe_url`.
    pub async fn auto_tune(&self, probe_url: &str) {
        self.desync.probe(probe_url).await;
    }
}

#[async_trait]
impl Transport for BypassTransport {
    async fn execute(&self, req: &HttpRequest) -> Result<HttpResponse, NetError> {
        send_with(&self.client, req).await
    }

    fn kind(&self) -> TransportKind {
        TransportKind::Bypass
    }
}
