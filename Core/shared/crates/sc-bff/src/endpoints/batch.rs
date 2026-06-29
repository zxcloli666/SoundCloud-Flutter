use std::sync::Arc;

use tokio::sync::Semaphore;

use sc_domain::{Track, Urn};

use crate::client::BffClient;
use crate::error::BffError;

/// Сколько resolve'ов держим в полёте одновременно — гасит N round-trip'ов
/// home/artist/wave/similar, не заваливая бэкенд.
const RESOLVE_CONCURRENCY: usize = 8;

impl BffClient {
    /// Батч-резолв треков по URN. Сохраняет порядок входа; 404/410 (None)
    /// выкидываются. Веер ограничен семафором.
    pub async fn resolve_tracks(&self, urns: &[String]) -> Result<Vec<Track>, BffError> {
        let limiter = Arc::new(Semaphore::new(RESOLVE_CONCURRENCY));
        let futures = urns.iter().map(|raw| {
            let limiter = limiter.clone();
            let urn = Urn::new(raw.clone());
            async move {
                // permit жив до конца запроса (RAII drop вернёт слот).
                let _permit = limiter.acquire().await;
                self.resolve_track(&urn).await
            }
        });
        let results = futures::future::join_all(futures).await;

        let mut tracks = Vec::with_capacity(results.len());
        for result in results {
            if let Some(track) = result? {
                tracks.push(track);
            }
        }
        Ok(tracks)
    }
}
