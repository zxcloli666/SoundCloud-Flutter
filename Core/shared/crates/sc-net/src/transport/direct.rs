use async_trait::async_trait;

use super::{Transport, TransportKind, send_with, stream_with};
use crate::error::NetError;
use crate::request::{HttpRequest, HttpResponse, NetStream};

/// Прямое соединение без обёрток.
pub struct DirectTransport {
    client: reqwest::Client,
}

impl DirectTransport {
    pub fn new() -> Result<Self, NetError> {
        Ok(Self {
            client: reqwest::Client::builder().build()?,
        })
    }

    pub fn with_client(client: reqwest::Client) -> Self {
        Self { client }
    }
}

#[async_trait]
impl Transport for DirectTransport {
    async fn execute(&self, req: &HttpRequest) -> Result<HttpResponse, NetError> {
        send_with(&self.client, req).await
    }

    async fn execute_stream(&self, req: &HttpRequest) -> Result<NetStream, NetError> {
        stream_with(&self.client, req).await
    }

    fn kind(&self) -> TransportKind {
        TransportKind::Direct
    }
}
