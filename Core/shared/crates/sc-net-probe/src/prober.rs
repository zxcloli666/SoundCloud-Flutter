use std::collections::HashMap;
use std::sync::Arc;
use std::time::Duration;

use serde::Deserialize;
use serde_json::Value;

use sc_net::{HttpRequest, NetClient, RetryPolicy};

use crate::Reachability;

const PROBE_TIMEOUT: Duration = Duration::from_secs(5);
/// Дёшево и надёжно: 204-эндпоинт «есть ли вообще интернет».
const CONNECTIVITY_URL: &str = "https://www.google.com/generate_204";
const CHECK_HOST_CREATE: &str = "https://check-host.net/check-http";
const CHECK_HOST_RESULT: &str = "https://check-host.net/check-result";
const RESULT_POLLS: u32 = 5;
const RESULT_POLL_DELAY: Duration = Duration::from_millis(1200);

pub struct Prober {
    net: Arc<NetClient>,
}

impl Prober {
    pub fn new(net: Arc<NetClient>) -> Self {
        Self { net }
    }

    /// Вердикт по цели: прямая доступность → нет сети → внешний консенсус.
    pub async fn diagnose(&self, target_url: &str) -> Reachability {
        if self.reachable(target_url).await {
            return Reachability::Online;
        }
        if !self.reachable(CONNECTIVITY_URL).await {
            return Reachability::Offline;
        }
        match self.external_reaches(target_url).await {
            Some(true) => Reachability::BlockedLocally,
            Some(false) => Reachability::Down,
            None => Reachability::Degraded,
        }
    }

    async fn reachable(&self, url: &str) -> bool {
        let request = HttpRequest::head(url).with_timeout(PROBE_TIMEOUT);
        match self.net.request_with(request, &RetryPolicy::none()).await {
            Ok(resp) => resp.is_success() || resp.is_redirect(),
            Err(_) => false,
        }
    }

    /// Спросить check-host.net, достучались ли внешние узлы. `None` — спросить
    /// не удалось/неясно; `Some(true)` — кто-то снаружи дотянулся (значит режут
    /// нас); `Some(false)` — никто, сервис лежит у всех.
    async fn external_reaches(&self, target_url: &str) -> Option<bool> {
        let host = urlencoding::encode(target_url);
        let create = HttpRequest::get(format!("{CHECK_HOST_CREATE}?host={host}&max_nodes=3"))
            .header("Accept", "application/json")
            .with_timeout(PROBE_TIMEOUT);
        let created: CheckHostCreate = self
            .net
            .request_with(create, &RetryPolicy::none())
            .await
            .ok()?
            .json()
            .ok()?;
        if created.ok != 1 {
            return None;
        }
        let request_id = created.request_id?;

        for _ in 0..RESULT_POLLS {
            tokio::time::sleep(RESULT_POLL_DELAY).await;
            let request = HttpRequest::get(format!("{CHECK_HOST_RESULT}/{request_id}"))
                .header("Accept", "application/json")
                .with_timeout(PROBE_TIMEOUT);
            let Ok(resp) = self.net.request_with(request, &RetryPolicy::none()).await else {
                continue;
            };
            let Ok(result) = resp.json::<CheckHostResult>() else {
                continue;
            };

            let mut all_responded = true;
            for node in result.0.values() {
                match node {
                    None => all_responded = false,
                    Some(checks) if checks.iter().any(|check| is_success(check)) => {
                        return Some(true);
                    }
                    Some(_) => {}
                }
            }
            if all_responded {
                return Some(false);
            }
        }
        None
    }
}

/// Узел отвечает массивом `[success, time, "200", ...]`; первый элемент == 1 —
/// успех.
fn is_success(check: &[Value]) -> bool {
    match check.first() {
        Some(flag) => flag.as_i64() == Some(1) || flag.as_f64() == Some(1.0),
        None => false,
    }
}

#[derive(Deserialize)]
struct CheckHostCreate {
    #[serde(default)]
    ok: i32,
    #[serde(default)]
    request_id: Option<String>,
}

#[derive(Deserialize)]
#[serde(transparent)]
struct CheckHostResult(HashMap<String, Option<Vec<Vec<Value>>>>);
