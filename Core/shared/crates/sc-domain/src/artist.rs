use serde::{Deserialize, Serialize};

use crate::track::Track;

/// Артист в каталоге/поиске (`/discover/artists`, `/search/db/artists`).
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ArtistCard {
    pub id: String,
    pub name: String,
    pub country: Option<String>,
    pub avatar_url: Option<String>,
    pub confidence: f32,
    pub star: bool,
    pub track_count_primary: u32,
    pub track_count_featured: u32,
    pub album_count: u32,
    pub monthly_listeners: u64,
    pub trending: f32,
    pub popularity: f32,
    pub tags: Vec<String>,
    pub aura_id: Option<String>,
    pub custom_hex: Option<String>,
}

/// Соцссылка артиста.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Social {
    pub kind: String,
    pub url: String,
    pub source: Option<String>,
    pub verified: bool,
}

/// Привязанный SC-аккаунт артиста.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ScAccount {
    pub sc_user_id: String,
    pub role: Option<String>,
    pub source: Option<String>,
    pub verified: bool,
}

/// Связанный артист (вес из ко-лайк сетки).
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct RelatedArtist {
    pub id: String,
    pub name: String,
    pub country: Option<String>,
    pub avatar_url: Option<String>,
    pub weight: f32,
}

/// Страница артиста (`/artists/{id}`).
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ArtistDetail {
    pub id: String,
    pub name: String,
    pub country: Option<String>,
    pub bio: Option<String>,
    pub avatar_url: Option<String>,
    pub confidence: f32,
    pub track_count: u32,
    pub track_count_primary: u32,
    pub track_count_featured: u32,
    pub album_count: u32,
    pub socials: Vec<Social>,
    pub sc_accounts: Vec<ScAccount>,
    pub related_artists: Vec<RelatedArtist>,
    pub popular_tracks: Vec<Track>,
}
