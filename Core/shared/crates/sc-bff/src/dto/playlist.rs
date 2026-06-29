use serde::Deserialize;

use sc_domain::user::UserRef;
use sc_domain::{PlaylistDetail, PlaylistSummary, Urn};

use crate::dto::track::TrackDto;

/// Сводка плейлиста: списки библиотеки/поиска/лайков, а также шапка детали.
#[derive(Deserialize)]
pub(crate) struct PlaylistSummaryDto {
    #[serde(deserialize_with = "crate::dto::flex::de_i64")]
    pub id: i64,
    #[serde(default)]
    pub urn: Option<String>,
    #[serde(default)]
    pub title: Option<String>,
    #[serde(default)]
    pub artwork_url: Option<String>,
    #[serde(default)]
    pub playlist_type: Option<String>,
    #[serde(default)]
    pub track_count: u32,
    #[serde(default)]
    pub duration: Option<u64>,
    #[serde(default)]
    pub likes_count: Option<u64>,
    #[serde(default)]
    pub reposts_count: Option<u64>,
    #[serde(default)]
    pub permalink_url: Option<String>,
    #[serde(default)]
    pub created_at: Option<String>,
    #[serde(default)]
    pub last_modified: Option<String>,
    #[serde(default)]
    pub release_year: Option<i32>,
    #[serde(default)]
    pub description: Option<String>,
    /// Сырой SC-плейлист несёт `set_type` ("album"/"ep"/...) вместо `playlist_type`.
    #[serde(default)]
    pub set_type: Option<String>,
    #[serde(default)]
    pub user: Option<PlaylistUserDto>,
    #[serde(default)]
    pub user_favorite: Option<bool>,
}

#[derive(Deserialize)]
pub(crate) struct PlaylistUserDto {
    #[serde(deserialize_with = "crate::dto::flex::de_i64")]
    pub id: i64,
    #[serde(default)]
    pub urn: Option<String>,
    #[serde(default)]
    pub username: Option<String>,
    #[serde(default)]
    pub permalink: Option<String>,
    #[serde(default)]
    pub permalink_url: Option<String>,
    #[serde(default)]
    pub avatar_url: Option<String>,
    #[serde(default)]
    pub verified: bool,
}

impl PlaylistUserDto {
    fn into_ref(self) -> UserRef {
        UserRef {
            id: Urn::new(self.urn.unwrap_or_else(|| format!("soundcloud:users:{}", self.id))),
            username: self.username.unwrap_or_default(),
            permalink: self.permalink,
            permalink_url: self.permalink_url,
            avatar_url: self.avatar_url,
            verified: self.verified,
        }
    }
}

impl PlaylistSummaryDto {
    pub(crate) fn into_domain(self) -> PlaylistSummary {
        // kind: playlist_type ("PLAYLIST"/"ALBUM") нормализуем в lower; для
        // сырого SC-плейлиста берём set_type ("album"/"ep"/"single").
        let kind = self
            .playlist_type
            .as_deref()
            .or(self.set_type.as_deref())
            .map(|t| t.to_ascii_lowercase());
        let is_album = kind.as_deref() == Some("album");
        PlaylistSummary {
            id: Urn::new(self.urn.unwrap_or_else(|| format!("soundcloud:playlists:{}", self.id))),
            title: self.title.unwrap_or_default(),
            artwork_url: self.artwork_url,
            is_album,
            track_count: self.track_count,
            duration_ms: self.duration,
            likes_count: self.likes_count,
            reposts_count: self.reposts_count,
            permalink_url: self.permalink_url,
            created_at: self.created_at,
            release_year: self.release_year,
            owner: self.user.map(PlaylistUserDto::into_ref),
            user_favorite: self.user_favorite,
            description: self.description,
            last_modified: self.last_modified,
            kind,
        }
    }
}

/// Деталь плейлиста: поля сводки на верхнем уровне + опциональные `tracks`.
#[derive(Deserialize)]
pub(crate) struct PlaylistDetailDto {
    #[serde(flatten)]
    pub summary: PlaylistSummaryDto,
    #[serde(default)]
    pub tracks: Vec<TrackDto>,
}

impl PlaylistDetailDto {
    pub(crate) fn into_domain(self) -> PlaylistDetail {
        PlaylistDetail {
            summary: self.summary.into_domain(),
            tracks: self.tracks.into_iter().map(TrackDto::into_domain).collect(),
        }
    }
}
