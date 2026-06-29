//! DRM-слой: расшифровка защищённого контента (Widevine-подобный поток).
//!
//! Перенос `decrypt` + `decrypt-client`. Высокий уровень ([`Engine`]) собирает
//! ключ по манифесту и расшифровывает сегменты; низкий ([`segment`]) — разбор
//! MP4-боксов и сам AES. Сейчас публичный билд — заглушка (`Error::Disabled`),
//! реальная реализация подключается отдельно. Сеть инъектируется через
//! [`Fetcher`], так что крейт не знает, как именно ходят запросы.

pub mod segment;

use std::path::Path;
use std::sync::Arc;

use bytes::Bytes;
use futures::future::BoxFuture;
use futures::stream::BoxStream;

#[derive(Debug, thiserror::Error)]
pub enum Error {
    #[error("disabled")]
    Disabled,
    #[error("fetch: {0}")]
    Fetch(String),
}

impl Error {
    pub fn is_disabled(&self) -> bool {
        matches!(self, Error::Disabled)
    }
}

/// Абстракция сети для DRM — реализуется поверх [`sc-net`](../sc_net).
pub trait Fetcher: Send + Sync {
    fn get(
        &self,
        url: String,
        headers: Vec<(String, String)>,
    ) -> BoxFuture<'static, Result<Bytes, Error>>;

    fn post(
        &self,
        url: String,
        headers: Vec<(String, String)>,
        body: Vec<u8>,
    ) -> BoxFuture<'static, Result<Bytes, Error>>;
}

/// Подготовленный для клиента поток: init-сегмент, список сегментов и ключ.
pub struct ClientPrep {
    pub content_type: String,
    pub init: Bytes,
    pub segment_urls: Vec<String>,
    pub key: [u8; 16],
}

pub struct Engine {}

impl Engine {
    pub fn load(_path: &Path) -> Result<Self, Error> {
        Err(Error::Disabled)
    }

    pub fn from_wvd_bytes(_wvd: &[u8]) -> Result<Self, Error> {
        Err(Error::Disabled)
    }

    pub fn devices(&self) -> usize {
        0
    }

    pub async fn process(
        &self,
        _manifest: &str,
        _token: &str,
        _fetcher: &dyn Fetcher,
    ) -> Result<Bytes, Error> {
        Err(Error::Disabled)
    }

    pub async fn process_stream(
        &self,
        _manifest: &str,
        _token: &str,
        _fetcher: Arc<dyn Fetcher>,
    ) -> Result<BoxStream<'static, Result<Bytes, Error>>, Error> {
        Err(Error::Disabled)
    }

    pub async fn prepare_for_client(
        &self,
        _manifest: &str,
        _token: &str,
        _fetcher: Arc<dyn Fetcher>,
    ) -> Result<ClientPrep, Error> {
        Err(Error::Disabled)
    }
}
