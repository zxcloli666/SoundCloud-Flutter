use serde::{Deserialize, Serialize};

use crate::ids::Urn;

/// Запись оффлайн-кэша: один материализованный m4a на диске.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct CacheEntry {
    pub urn: Urn,
    /// Голый SC-id трека.
    pub sc_id: i64,
    pub path: String,
    pub bytes: i64,
}
