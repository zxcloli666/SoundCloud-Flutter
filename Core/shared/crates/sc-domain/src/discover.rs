use serde::{Deserialize, Serialize};

use crate::album::AlbumCard;
use crate::artist::ArtistCard;

/// Элемент «В центре внимания» (`/discover/spotlight`): курируемый артист или
/// альбом (легаси `SpotlightItem`). Карточки — те же, что в каталоге.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub enum SpotlightItem {
    Artist(ArtistCard),
    Album(AlbumCard),
}

/// Сводка каталога (`/discover/summary`) — счётчики для лендинга «Открыть».
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct DiscoverSummary {
    pub artists_count: u64,
    pub albums_count: u64,
    pub fresh_count: u64,
    pub fresh_window_days: u32,
}

/// Тег/жанр каталога (`/discover/tags`).
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Tag {
    pub id: String,
    pub label: String,
    pub count: u64,
}
