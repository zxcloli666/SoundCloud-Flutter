use serde::Deserialize;

use sc_domain::{DiscoverSummary, SpotlightItem, Tag};

use crate::dto::album::AlbumCardDto;
use crate::dto::artist::ArtistCardDto;

/// Элемент «В центре внимания»: `{kind, artist|album}`. untagged — различаем по
/// наличию поля `artist`/`album` (поле `kind` игнорируем).
#[derive(Deserialize)]
#[serde(untagged)]
pub(crate) enum SpotlightItemDto {
    Artist { artist: ArtistCardDto },
    Album { album: AlbumCardDto },
}

#[derive(Deserialize)]
pub(crate) struct SpotlightResponseDto {
    #[serde(default)]
    pub items: Vec<SpotlightItemDto>,
}

impl SpotlightItemDto {
    pub(crate) fn into_domain(self) -> SpotlightItem {
        match self {
            SpotlightItemDto::Artist { artist } => {
                SpotlightItem::Artist(artist.into_domain())
            }
            SpotlightItemDto::Album { album } => {
                SpotlightItem::Album(album.into_domain())
            }
        }
    }
}

#[derive(Deserialize)]
pub(crate) struct DiscoverSummaryDto {
    #[serde(default)]
    pub artists_count: u64,
    #[serde(default)]
    pub albums_count: u64,
    #[serde(default)]
    pub fresh_count: u64,
    #[serde(default)]
    pub fresh_window_days: u32,
}

impl DiscoverSummaryDto {
    pub(crate) fn into_domain(self) -> DiscoverSummary {
        DiscoverSummary {
            artists_count: self.artists_count,
            albums_count: self.albums_count,
            fresh_count: self.fresh_count,
            fresh_window_days: self.fresh_window_days,
        }
    }
}

#[derive(Deserialize)]
pub(crate) struct TagDto {
    pub id: String,
    #[serde(default)]
    pub label: Option<String>,
    #[serde(default)]
    pub count: u64,
}

impl TagDto {
    pub(crate) fn into_domain(self) -> Tag {
        Tag {
            label: self.label.unwrap_or_else(|| self.id.clone()),
            id: self.id,
            count: self.count,
        }
    }
}
