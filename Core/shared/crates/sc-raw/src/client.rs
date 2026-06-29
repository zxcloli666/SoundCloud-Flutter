use std::sync::Arc;

use bytes::Bytes;

use sc_domain::{Track, Urn};
use sc_net::{HttpRequest, NetClient};

use crate::Progress;
use crate::client_id::ClientId;
use crate::error::RawError;
use crate::hls;
use crate::types::{
    ApiSearchResponse, ApiTrack, ApiTranscoding, SearchPage, StreamProtocol, StreamSource,
    TranscodingTarget,
};

const SC_API_V2: &str = "https://api-v2.soundcloud.com";

/// Клиент сырого SoundCloud (анонимный apiv2) поверх [`NetClient`]: роутинг,
/// прокси и пробив блокировок работают здесь даром.
pub struct RawClient {
    net: Arc<NetClient>,
    client_id: ClientId,
}

impl RawClient {
    pub fn new(net: Arc<NetClient>) -> Self {
        Self {
            client_id: ClientId::new(net.clone()),
            net,
        }
    }

    /// Резолв трека. `Ok(None)` при 404/410 (удалён/ограничен).
    pub async fn resolve_track(&self, urn: &Urn) -> Result<Option<Track>, RawError> {
        let resp = self.fetch_track(urn).await?;
        match resp.status {
            404 | 410 => Ok(None),
            status if !(200..300).contains(&status) => {
                Err(RawError::SoundCloud(format!("resolve {status}")))
            }
            _ => Ok(Some(resp.json::<ApiTrack>()?.into_domain())),
        }
    }

    pub async fn search_tracks(
        &self,
        query: &str,
        limit: u32,
        offset: u32,
    ) -> Result<SearchPage<Track>, RawError> {
        let client_id = self.client_id.get().await?;
        let query = urlencoding::encode(query);
        let url =
            format!("{SC_API_V2}/search/tracks?q={query}&client_id={client_id}&limit={limit}&offset={offset}");
        let resp = self.net.request(HttpRequest::get(url)).await?;
        if !resp.is_success() {
            return Err(RawError::SoundCloud(format!("search {}", resp.status)));
        }
        let parsed = resp.json::<ApiSearchResponse>()?;
        let items = parsed.collection.into_iter().map(ApiTrack::into_domain).collect();
        let next_offset = parsed.next_href.map(|_| offset + limit);
        Ok(SearchPage { items, next_offset })
    }

    /// Выбрать лучший источник и развернуть transcoding в реальный URL потока.
    pub async fn resolve_stream(&self, urn: &Urn) -> Result<StreamSource, RawError> {
        let client_id = self.client_id.get().await?;
        let resp = self.fetch_track(urn).await?;
        if !resp.is_success() {
            return Err(RawError::SoundCloud(format!("resolve {}", resp.status)));
        }
        let track = resp.json::<ApiTrack>()?;
        let authorization = track.track_authorization;
        let media = track
            .media
            .ok_or_else(|| RawError::Stream("no media".into()))?;

        // Перебираем кандидатов (progressive→hls, по приоритету пресета), пока
        // один не развернётся в рабочий URL — у части треков лучший 404-ит.
        let candidates = playable_sorted(media.transcodings);
        if candidates.is_empty() {
            return Err(RawError::Stream("no playable transcoding".into()));
        }
        let mut last_error = None;
        for transcoding in candidates {
            let Some(preset) = transcoding.preset_kind() else {
                continue;
            };
            let target_url =
                build_transcoding_target(&transcoding.url, &client_id, authorization.as_deref());
            let target = match self.net.request(HttpRequest::get(target_url)).await {
                Ok(target) if target.is_success() => target,
                Ok(target) => {
                    last_error = Some(RawError::Stream(format!("transcoding {}", target.status)));
                    continue;
                }
                Err(error) => {
                    last_error = Some(error.into());
                    continue;
                }
            };
            let Ok(resolved) = target.json::<TranscodingTarget>() else {
                continue;
            };
            return Ok(StreamSource {
                url: resolved.url,
                protocol: transcoding.protocol(),
                preset,
                track_authorization: authorization,
            });
        }
        Err(last_error.unwrap_or_else(|| RawError::Stream("no resolvable transcoding".into())))
    }

    /// Скачать поток целиком (выбор протокола по источнику). Результат — сырые
    /// байты (возможно не-AAC): дальше их забирает `sc-cache` и приводит к m4a.
    /// [`progress`] (опц.) получает долю готовности 0..1 по мере скачки.
    pub async fn fetch_stream(
        &self,
        source: &StreamSource,
        progress: Option<Progress<'_>>,
    ) -> Result<Bytes, RawError> {
        match source.protocol {
            StreamProtocol::Progressive => {
                hls::download_progressive(&self.net, &source.url, progress).await
            }
            StreamProtocol::Hls => hls::download_hls_full(&self.net, &source.url, progress).await,
        }
    }

    async fn fetch_track(&self, urn: &Urn) -> Result<sc_net::HttpResponse, RawError> {
        let client_id = self.client_id.get().await?;
        let url = format!("{SC_API_V2}/tracks/{}?client_id={}", urn.bare(), client_id);
        Ok(self.net.request(HttpRequest::get(url)).await?)
    }
}

/// Пригодные транскодинги в порядке предпочтения (progressive→hls, затем по
/// приоритету пресета).
fn playable_sorted(transcodings: Vec<ApiTranscoding>) -> Vec<ApiTranscoding> {
    let mut candidates: Vec<ApiTranscoding> = transcodings
        .into_iter()
        .filter(ApiTranscoding::is_playable)
        .collect();
    candidates.sort_by_key(ApiTranscoding::sort_key);
    candidates
}

fn build_transcoding_target(url: &str, client_id: &str, authorization: Option<&str>) -> String {
    let separator = if url.contains('?') { '&' } else { '?' };
    let mut target = format!("{url}{separator}client_id={client_id}");
    if let Some(authorization) = authorization {
        target.push_str("&track_authorization=");
        target.push_str(authorization);
    }
    target
}

#[cfg(test)]
mod tests {
    use super::*;
    use sc_net::{NetClient, NetConfig};

    /// Живой anon-путь end-to-end: client_id → resolve_stream → fetch_stream.
    /// Сеть/реальный SoundCloud — поэтому `#[ignore]` (гонять явно):
    /// `cargo test -p sc-raw -- --ignored --nocapture`.
    #[tokio::test]
    #[ignore = "network: hits real SoundCloud anon api-v2"]
    async fn anon_resolves_and_fetches_public_track() {
        let net = NetClient::new(NetConfig::direct())
            .await
            .expect("net client");
        let raw = RawClient::new(std::sync::Arc::new(net));
        // Публичный трек (RAMIREZ — SARCOPHAGUS II), есть progressive+hls транскодинги.
        let urn = Urn::new("soundcloud:tracks:2047869544");

        let source = raw.resolve_stream(&urn).await.expect("resolve_stream");
        eprintln!("source: protocol={:?} preset={:?}", source.protocol, source.preset);

        let bytes = raw.fetch_stream(&source, None).await.expect("fetch_stream");
        eprintln!("fetched {} bytes", bytes.len());
        assert!(bytes.len() > 50_000, "stream too small: {} bytes", bytes.len());
    }
}
