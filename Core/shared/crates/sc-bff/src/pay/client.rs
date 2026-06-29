use std::sync::Arc;

use serde::Serialize;
use serde::de::DeserializeOwned;

use sc_net::{HttpRequest, HttpResponse, NetClient, SessionSource};

use crate::error::BffError;

pub(crate) const PAY_BASE: &str = "https://pay.scdinternal.site";

/// Клиент платёжного сервиса (`pay.scdinternal.site`) поверх [`NetClient`].
/// `UserCtx` на бэке резолвит `x-session-id` — навешиваем его **здесь** (sc-net
/// токенов не знает).
pub struct PayClient {
    net: Arc<NetClient>,
    session: Arc<dyn SessionSource>,
}

impl PayClient {
    pub fn new(net: Arc<NetClient>, session: Arc<dyn SessionSource>) -> Self {
        Self { net, session }
    }

    /// Навесить токен API на запрос (если сессия активна).
    fn authed(&self, req: HttpRequest) -> HttpRequest {
        match self.session.session_id() {
            Some(token) => req.header("x-session-id", token),
            None => req,
        }
    }

    pub(crate) async fn get_json<T: DeserializeOwned>(&self, path: &str) -> Result<T, BffError> {
        let resp = self.get(path).await?;
        Self::decode(path, &resp)
    }

    /// GET, который при 404/410 даёт `Ok(None)`.
    pub(crate) async fn get_optional<T: DeserializeOwned>(
        &self,
        path: &str,
    ) -> Result<Option<T>, BffError> {
        let resp = self.get(path).await?;
        match resp.status {
            404 | 410 => Ok(None),
            _ => Self::decode(path, &resp).map(Some),
        }
    }

    pub(crate) async fn post_json<B: Serialize, T: DeserializeOwned>(
        &self,
        path: &str,
        body: &B,
    ) -> Result<T, BffError> {
        let url = format!("{PAY_BASE}{path}");
        let payload = serde_json::to_vec(body).map_err(|e| BffError::Decode(e.to_string()))?;
        let req = self.authed(
            HttpRequest::post(url, payload).header("content-type", "application/json"),
        );
        let resp = self.net.request(req).await?;
        Self::decode(path, &resp)
    }

    /// POST, результат которого не нужен — важен лишь успех (2xx).
    pub(crate) async fn post_ok<B: Serialize>(&self, path: &str, body: &B) -> Result<(), BffError> {
        let url = format!("{PAY_BASE}{path}");
        let payload = serde_json::to_vec(body).map_err(|e| BffError::Decode(e.to_string()))?;
        let req = self.authed(
            HttpRequest::post(url, payload).header("content-type", "application/json"),
        );
        let resp = self.net.request(req).await?;
        if resp.is_success() {
            Ok(())
        } else {
            Err(BffError::Status {
                status: resp.status,
                path: path.to_owned(),
            })
        }
    }

    async fn get(&self, path: &str) -> Result<HttpResponse, BffError> {
        let url = format!("{PAY_BASE}{path}");
        Ok(self.net.request(self.authed(HttpRequest::get(url))).await?)
    }

    fn decode<T: DeserializeOwned>(path: &str, resp: &HttpResponse) -> Result<T, BffError> {
        if !resp.is_success() {
            return Err(BffError::Status {
                status: resp.status,
                path: path.to_owned(),
            });
        }
        serde_json::from_slice(&resp.body).map_err(|e| BffError::Decode(e.to_string()))
    }
}
