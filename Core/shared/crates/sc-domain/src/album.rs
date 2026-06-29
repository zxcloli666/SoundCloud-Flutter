use serde::{Deserialize, Serialize};

use crate::track::Track;

/// Артист альбома с ролью (primary/featured/producer).
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct AlbumArtist {
    pub id: String,
    pub name: String,
    pub role: Option<String>,
    pub avatar_url: Option<String>,
}

/// Альбом в каталоге/поиске (`/discover/albums`, `/search/db/albums`).
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct AlbumCard {
    pub id: String,
    pub title: String,
    pub release_year: Option<i32>,
    pub release_month: Option<u32>,
    pub cover_url: Option<String>,
    pub confidence: f32,
    pub track_count: u32,
    pub total_duration_ms: Option<u64>,
    pub popularity: f32,
    pub star: bool,
    pub primary_artist: AlbumArtist,
}

/// Краткая ссылка на альбом из списка артиста (`/artists/{id}/albums`).
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct AlbumRef {
    pub id: String,
    pub title: String,
    pub release_year: Option<i32>,
    pub role: Option<String>,
}

/// Страница альбома (`/albums/{id}`).
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct AlbumDetail {
    pub id: String,
    pub title: String,
    pub release_year: Option<i32>,
    pub cover_url: Option<String>,
    pub confidence: f32,
    pub primary_artist: AlbumArtist,
    pub artists: Vec<AlbumArtist>,
    pub tracks: Vec<Track>,
}

/// Год + альбомы этого года (`/discover/albums/by-year`).
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct AlbumYearBucket {
    pub year: i32,
    pub items: Vec<AlbumCard>,
}
