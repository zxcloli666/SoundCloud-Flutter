use serde::{Deserialize, Serialize};

use crate::ids::Urn;
use crate::track::{ArtistRef, Track};
use crate::user::UserRef;

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Playlist {
    pub id: Urn,
    pub title: String,
    pub owner: ArtistRef,
    pub artwork_url: Option<String>,
    /// Альбом — частный случай плейлиста.
    pub is_album: bool,
    pub track_count: u32,
    pub tracks: Vec<Track>,
}

/// Сводка плейлиста для списков (библиотека/поиск/лайки) — без треков.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct PlaylistSummary {
    pub id: Urn,
    pub title: String,
    pub artwork_url: Option<String>,
    pub is_album: bool,
    pub track_count: u32,
    pub duration_ms: Option<u64>,
    pub likes_count: Option<u64>,
    pub reposts_count: Option<u64>,
    pub permalink_url: Option<String>,
    pub created_at: Option<String>,
    pub release_year: Option<i32>,
    pub owner: Option<UserRef>,
    pub user_favorite: Option<bool>,
    pub description: Option<String>,
    pub last_modified: Option<String>,
    /// "album"|"playlist"|"ep"|"single" из playlist_type/set_type.
    pub kind: Option<String>,
}

/// Детальный плейлист (`/playlists/{urn}`): сводка + страница треков.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct PlaylistDetail {
    pub summary: PlaylistSummary,
    pub tracks: Vec<Track>,
}
