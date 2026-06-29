use std::time::Duration;

use bytes::Bytes;
use futures::stream::{self, BoxStream};
use serde::de::DeserializeOwned;

use crate::error::NetError;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Method {
    Get,
    Head,
    Post,
    Put,
    Delete,
}

/// Запрос без привязки к способу доставки — его исполняет любой [`Transport`].
#[derive(Clone, Debug)]
pub struct HttpRequest {
    pub method: Method,
    pub url: String,
    pub headers: Vec<(String, String)>,
    pub body: Option<Bytes>,
    pub timeout: Option<Duration>,
}

impl HttpRequest {
    fn new(method: Method, url: impl Into<String>) -> Self {
        Self {
            method,
            url: url.into(),
            headers: Vec::new(),
            body: None,
            timeout: None,
        }
    }

    pub fn get(url: impl Into<String>) -> Self {
        Self::new(Method::Get, url)
    }

    pub fn head(url: impl Into<String>) -> Self {
        Self::new(Method::Head, url)
    }

    pub fn post(url: impl Into<String>, body: impl Into<Bytes>) -> Self {
        let mut req = Self::new(Method::Post, url);
        req.body = Some(body.into());
        req
    }

    pub fn put(url: impl Into<String>, body: impl Into<Bytes>) -> Self {
        let mut req = Self::new(Method::Put, url);
        req.body = Some(body.into());
        req
    }

    pub fn delete(url: impl Into<String>) -> Self {
        Self::new(Method::Delete, url)
    }

    pub fn header(mut self, key: impl Into<String>, value: impl Into<String>) -> Self {
        self.headers.push((key.into(), value.into()));
        self
    }

    pub fn with_timeout(mut self, timeout: Duration) -> Self {
        self.timeout = Some(timeout);
        self
    }

    /// Хост из URL — по нему роутер выбирает маршрут.
    pub fn host(&self) -> Option<String> {
        url::Url::parse(&self.url)
            .ok()
            .and_then(|u| u.host_str().map(str::to_owned))
    }
}

#[derive(Clone, Debug)]
pub struct HttpResponse {
    pub status: u16,
    pub headers: Vec<(String, String)>,
    pub body: Bytes,
}

/// Ответ, тело которого течёт чанками (для скачки больших файлов с прогрессом).
/// Заголовки уже прочитаны — отсюда известна длина; байты потребитель тянет сам
/// и считает прочитанное. Получается через [`crate::stream::StreamClient::download`].
pub struct NetStream {
    pub content_length: Option<u64>,
    pub body: BoxStream<'static, Result<Bytes, NetError>>,
}

impl NetStream {
    /// Завернуть уже целиком прочитанное тело в одночанковый поток — деградация
    /// для транспортов без настоящего стрима (прогресс прыгнет 0→100 одним шагом).
    pub fn whole(body: Bytes) -> Self {
        Self {
            content_length: Some(body.len() as u64),
            body: Box::pin(stream::once(async move { Ok(body) })),
        }
    }
}

impl HttpResponse {
    pub fn is_success(&self) -> bool {
        (200..300).contains(&self.status)
    }

    pub fn is_redirect(&self) -> bool {
        (300..400).contains(&self.status)
    }

    pub fn json<T: DeserializeOwned>(&self) -> Result<T, NetError> {
        serde_json::from_slice(&self.body).map_err(|e| NetError::Decode(e.to_string()))
    }
}
