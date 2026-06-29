use std::sync::Arc;

use serde::de::DeserializeOwned;

use sc_net::{
    FailKind, HostId, HostPool, HttpRequest, HttpResponse, Method, NetClient, NetError, Plane,
    SessionSource,
};

use crate::error::BffError;

/// Клиент API-бэка поверх [`NetClient`] с failover main⇄star ([`HostPool`]):
/// роутинг/прокси/пробив берём из `sc-net`, а **токен `x-session-id` навешиваем
/// здесь** (sc-net токенов не знает — он тупой транспорт). Базу хоста выбирает
/// пул по классу запроса; провалы/успехи копятся в вердикты (UI читает их).
pub struct BffClient {
    pub(crate) net: Arc<NetClient>,
    pub(crate) pool: Arc<HostPool>,
    session: Arc<dyn SessionSource>,
}

impl BffClient {
    pub fn new(net: Arc<NetClient>, pool: Arc<HostPool>, session: Arc<dyn SessionSource>) -> Self {
        Self { net, pool, session }
    }

    /// GET + декод тела в `T`. Не-2xx → `BffError::Status`.
    pub(crate) async fn get_json<T: DeserializeOwned>(&self, path: &str) -> Result<T, BffError> {
        let resp = self.get(path).await?;
        Self::decode(path, &resp)
    }

    /// GET, который при 404/410 даёт `Ok(None)` (удалён/ограничен), иначе `T`.
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

    pub(crate) async fn get(&self, path: &str) -> Result<HttpResponse, BffError> {
        self.execute(Method::Get, path, None, false).await
    }

    /// POST с пустым телом. Транспортная ошибка пробрасывается; статус ответа
    /// решает вызывающий (logout игнорирует не-2xx — это revoke).
    pub(crate) async fn post_empty(&self, path: &str) -> Result<HttpResponse, BffError> {
        self.execute(Method::Post, path, Some(Vec::new()), false).await
    }

    pub(crate) async fn put_empty(&self, path: &str) -> Result<HttpResponse, BffError> {
        self.execute(Method::Put, path, Some(Vec::new()), false).await
    }

    pub(crate) async fn delete(&self, path: &str) -> Result<HttpResponse, BffError> {
        self.execute(Method::Delete, path, None, false).await
    }

    /// PUT с JSON-телом + декод ответа в `T`. Не-2xx → `BffError::Status`.
    pub(crate) async fn put_json<B: serde::Serialize, T: DeserializeOwned>(
        &self,
        path: &str,
        body: &B,
    ) -> Result<T, BffError> {
        let payload = serde_json::to_vec(body).map_err(|e| BffError::Decode(e.to_string()))?;
        let resp = self.execute(Method::Put, path, Some(payload), true).await?;
        Self::decode(path, &resp)
    }

    /// POST с JSON-телом + декод ответа в `T`. Не-2xx → `BffError::Status`.
    pub(crate) async fn post_json<B: serde::Serialize, T: DeserializeOwned>(
        &self,
        path: &str,
        body: &B,
    ) -> Result<T, BffError> {
        let payload = serde_json::to_vec(body).map_err(|e| BffError::Decode(e.to_string()))?;
        let resp = self.execute(Method::Post, path, Some(payload), true).await?;
        Self::decode(path, &resp)
    }

    /// POST с JSON-телом, результат не нужен — важен лишь успех (2xx).
    pub(crate) async fn post_ok<B: serde::Serialize>(
        &self,
        path: &str,
        body: &B,
    ) -> Result<(), BffError> {
        let payload = serde_json::to_vec(body).map_err(|e| BffError::Decode(e.to_string()))?;
        let resp = self.execute(Method::Post, path, Some(payload), true).await?;
        if resp.is_success() {
            Ok(())
        } else {
            Err(BffError::Status {
                status: resp.status,
                path: path.to_owned(),
            })
        }
    }

    /// Сырое GET-тело произвольного внешнего URL (через тот же транспорт): нужно
    /// для waveform-JSON с `wave.sndcdn.com` — не наш BFF, без failover.
    pub(crate) async fn get_external_bytes(&self, url: &str) -> Result<Vec<u8>, BffError> {
        let resp = self.net.request(HttpRequest::get(url.to_owned())).await?;
        if !resp.is_success() {
            return Err(BffError::Status {
                status: resp.status,
                path: url.to_owned(),
            });
        }
        Ok(resp.body.to_vec())
    }

    /// Исполнить запрос с failover: пул отдаёт хосты по классу [`Plane`], перебор
    /// до первого ответа. На 5xx/транспортной ошибке хост помечается провалившимся
    /// и (для не-мутаций) пробуем следующий. **Мутации** уходят на резерв ТОЛЬКО
    /// при транспортной ошибке вида `Connect` (соединения не было) — получили
    /// любой ответ (даже 5xx) или таймаут → НЕ ретраим, иначе двойное применение.
    async fn execute(
        &self,
        method: Method,
        path: &str,
        body: Option<Vec<u8>>,
        json: bool,
    ) -> Result<HttpResponse, BffError> {
        let plane = plane_for(method, path);
        let hosts = self.pool.order(plane);
        let last_idx = hosts.len().saturating_sub(1);
        let mut last_err: Option<BffError> = None;

        for (i, (host, base)) in hosts.into_iter().enumerate() {
            let is_last = i == last_idx;
            let mut req = build_request(method, format!("{base}{path}"), body.clone(), json);
            // Токен API навешиваем здесь (наш бэк), не в sc-net.
            if let Some(token) = self.session.session_id() {
                req = req.header("x-session-id", token);
            }
            match self.net.request(req).await {
                Ok(resp) if resp.status < 500 => {
                    self.pool.record_success(host);
                    // STAR отказал премиум-claim (403) — подписка могла истечь:
                    // просим внеочередную перепроверку (рефрешер в sc-core).
                    if host == HostId::Star && resp.status == 403 {
                        self.pool.request_recheck();
                    }
                    return Ok(resp);
                }
                Ok(resp) => {
                    // 5xx: хост ответил, но сломан. Мутацию не переигрываем (мог
                    // применить); не-мутацию пробуем на резерве.
                    self.pool.record_failure(host, FailKind::ServerError);
                    if plane == Plane::Mutation || is_last {
                        return Ok(resp);
                    }
                    last_err = Some(BffError::Status {
                        status: resp.status,
                        path: path.to_owned(),
                    });
                }
                Err(e) => {
                    let kind = fail_kind(&e);
                    self.pool.record_failure(host, kind);
                    // Мутацию на резерв — только если соединения точно не было.
                    if is_last || (plane == Plane::Mutation && !kind.mutation_retryable()) {
                        return Err(BffError::Net(e));
                    }
                    last_err = Some(BffError::Net(e));
                }
            }
        }
        Err(last_err.unwrap_or_else(|| BffError::Net(NetError::Exhausted(path.to_owned()))))
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

/// Класс запроса для пула: auth — control-plane; подписка — оба хоста; идемпотентные
/// чтения — data; запись — mutation (особый failover).
fn plane_for(method: Method, path: &str) -> Plane {
    if path.starts_with("/auth/") {
        return Plane::Control;
    }
    if path == "/me/subscription" {
        return Plane::Subscription;
    }
    match method {
        Method::Get | Method::Head => Plane::Data,
        Method::Post | Method::Put | Method::Delete => Plane::Mutation,
    }
}

fn build_request(method: Method, url: String, body: Option<Vec<u8>>, json: bool) -> HttpRequest {
    let mut req = match method {
        Method::Get | Method::Head => HttpRequest::get(url),
        Method::Post => HttpRequest::post(url, body.unwrap_or_default()),
        Method::Put => HttpRequest::put(url, body.unwrap_or_default()),
        Method::Delete => HttpRequest::delete(url),
    };
    if json {
        req = req.header("content-type", "application/json");
    }
    req
}

/// Классификация транспортной ошибки. Для мутаций безопасен только `Connect`
/// (соединение не состоялось → запрос точно не применился). Неоднозначные
/// (таймаут/обрыв в полёте) — `Timeout`: мутацию не переигрываем.
fn fail_kind(e: &NetError) -> FailKind {
    match e {
        NetError::Exhausted(_) => FailKind::Connect,
        NetError::Reqwest(re) if re.is_connect() => FailKind::Connect,
        NetError::Reqwest(re) if re.is_timeout() => FailKind::Timeout,
        NetError::RetriesExhausted(_, inner) => fail_kind(inner),
        _ => FailKind::Timeout,
    }
}

/// URL-энкод значения запроса (`q`).
pub(crate) fn enc(value: &str) -> String {
    urlencoding::encode(value).into_owned()
}

/// `offset` → номер страницы для бэкендов с page-пагинацией (единый (limit,
/// offset) контракт BFF, бэкенд ждёт `page`).
pub(crate) fn offset_to_page(offset: u32, limit: u32) -> u32 {
    offset.checked_div(limit).unwrap_or(0)
}
