//! Добыча и кэш анонимного `client_id`. Минимальный интервал обновления +
//! circuit breaker (как в легаси): не долбим SoundCloud при череде ошибок.

use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use sc_net::{HttpRequest, NetClient};

use crate::error::RawError;

const SC_HOME: &str = "https://soundcloud.com";
const MIN_REFRESH: Duration = Duration::from_secs(30);
const COOLDOWN: Duration = Duration::from_secs(300);
const MAX_FAILURES: u32 = 3;

#[derive(Default)]
struct Cache {
    value: Option<String>,
    fetched_at: Option<Instant>,
    failures: u32,
    cooldown_until: Option<Instant>,
}

pub(crate) struct ClientId {
    net: Arc<NetClient>,
    cache: Mutex<Cache>,
}

impl ClientId {
    pub(crate) fn new(net: Arc<NetClient>) -> Self {
        Self {
            net,
            cache: Mutex::new(Cache::default()),
        }
    }

    pub(crate) async fn get(&self) -> Result<String, RawError> {
        if let Some(fresh) = self.cached_fresh() {
            return Ok(fresh);
        }
        match self.fetch().await {
            Ok(id) => {
                let mut cache = self.lock();
                cache.value = Some(id.clone());
                cache.fetched_at = Some(Instant::now());
                cache.failures = 0;
                cache.cooldown_until = None;
                Ok(id)
            }
            Err(error) => {
                let mut cache = self.lock();
                cache.failures += 1;
                if cache.failures >= MAX_FAILURES {
                    cache.cooldown_until = Some(Instant::now() + COOLDOWN);
                    cache.failures = 0;
                }
                // Деградация: лучше отдать устаревший id, чем упасть.
                cache.value.clone().ok_or(error)
            }
        }
    }

    /// Свежий кэш (моложе MIN_REFRESH) либо id под открытым circuit breaker'ом.
    fn cached_fresh(&self) -> Option<String> {
        let cache = self.lock();
        if let Some(value) = &cache.value {
            let fresh = cache.fetched_at.is_some_and(|t| t.elapsed() < MIN_REFRESH);
            let cooling = cache.cooldown_until.is_some_and(|t| t > Instant::now());
            if fresh || cooling {
                return Some(value.clone());
            }
        }
        None
    }

    async fn fetch(&self) -> Result<String, RawError> {
        let resp = self.net.request(HttpRequest::get(SC_HOME)).await?;
        if !resp.is_success() {
            return Err(RawError::ClientId(format!("homepage status {}", resp.status)));
        }
        let html = String::from_utf8_lossy(&resp.body).into_owned();
        if let Some(id) = extract_client_id(&html) {
            return Ok(id);
        }
        // client_id лежит не в HTML, а в JS-бандле (a-v2.sndcdn.com/assets).
        // Обычно в одном из последних — пробуем с конца.
        let mut scripts = script_srcs(&html);
        scripts.reverse();
        for src in scripts {
            let resp = self.net.request(HttpRequest::get(&src)).await?;
            if !resp.is_success() {
                continue;
            }
            let js = String::from_utf8_lossy(&resp.body);
            if let Some(id) = extract_client_id(&js) {
                return Ok(id);
            }
        }
        Err(RawError::ClientId("not found in homepage or bundles".into()))
    }

    fn lock(&self) -> std::sync::MutexGuard<'_, Cache> {
        // Poison не паникуем — восстанавливаем (см. правило no-unwrap в проде).
        self.cache.lock().unwrap_or_else(|poison| poison.into_inner())
    }
}

/// Вытащить первый правдоподобный client_id из текста (HTML или JS-бандла).
fn extract_client_id(text: &str) -> Option<String> {
    for marker in ["client_id:\"", "\"client_id\":\"", "client_id="] {
        let mut rest = text;
        while let Some(pos) = rest.find(marker) {
            let tail = &rest[pos + marker.len()..];
            let id: String = tail
                .chars()
                .take_while(|c| c.is_ascii_alphanumeric())
                .collect();
            if id.len() >= 16 {
                return Some(id);
            }
            rest = tail;
        }
    }
    None
}

/// URL-ы JS-бандлов SoundCloud (`a-v2.sndcdn.com/assets/*.js`) из разметки.
fn script_srcs(html: &str) -> Vec<String> {
    const NEEDLE: &str = "https://a-v2.sndcdn.com/assets/";
    let mut urls = Vec::new();
    let mut rest = html;
    while let Some(pos) = rest.find(NEEDLE) {
        let tail = &rest[pos..];
        let Some(end) = tail.find('"') else { break };
        let url = &tail[..end];
        if url.ends_with(".js") {
            urls.push(url.to_owned());
        }
        rest = &tail[end..];
    }
    urls
}
