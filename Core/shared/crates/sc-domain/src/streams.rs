use serde::{Deserialize, Serialize};

/// Доступные потоки трека (`/tracks/{urn}/streams`).
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct TrackStreams {
    pub hls_aac_160_url: Option<String>,
    pub hls_mp3_128_url: Option<String>,
    pub http_mp3_128_url: Option<String>,
    pub preview_mp3_128_url: Option<String>,
}
