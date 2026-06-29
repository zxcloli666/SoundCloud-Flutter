use serde::{Deserialize, Serialize};

/// Запись истории прослушивания (`/history`). Денормализована — без resolve.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct HistoryEntry {
    pub id: String,
    pub sc_track_id: String,
    pub title: String,
    pub artist_name: String,
    pub artist_urn: Option<String>,
    pub artwork_url: Option<String>,
    pub duration_ms: u64,
    pub played_at: String,
}

/// Страница истории (`{collection, total}`).
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct HistoryPage {
    pub items: Vec<HistoryEntry>,
    pub total: u32,
}
