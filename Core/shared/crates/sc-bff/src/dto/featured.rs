use serde::Deserialize;

use sc_domain::user::UserRef;
use sc_domain::{Featured, FeaturedPick, PlaylistSummary, Urn};

use crate::dto::track::TrackDto;

/// `/featured`: тип пика + сырой объект (полный SC трек/плейлист).
#[derive(Deserialize)]
pub(crate) struct FeaturedDto {
    #[serde(default, rename = "type")]
    pub kind: Option<String>,
    pub data: serde_json::Value,
}

impl FeaturedDto {
    pub(crate) fn into_domain(self) -> Featured {
        let kind = self.kind.unwrap_or_default();
        let pick = match kind.as_str() {
            "track" => serde_json::from_value::<TrackDto>(self.data)
                .map(|t| FeaturedPick::Track(Box::new(t.into_domain())))
                .unwrap_or(FeaturedPick::Unknown),
            "playlist" | "album" => serde_json::from_value::<FeaturedPlaylistDto>(self.data)
                .map(|p| FeaturedPick::Playlist(Box::new(p.into_domain())))
                .unwrap_or(FeaturedPick::Unknown),
            _ => FeaturedPick::Unknown,
        };
        Featured { kind, pick }
    }
}

/// Сырой SC-плейлист из `/featured` (отличается от BFF-сводки: `is_album`,
/// `favoritings_count`).
#[derive(Deserialize)]
struct FeaturedPlaylistDto {
    #[serde(deserialize_with = "crate::dto::flex::de_i64")]
    id: i64,
    #[serde(default)]
    urn: Option<String>,
    #[serde(default)]
    title: Option<String>,
    #[serde(default)]
    artwork_url: Option<String>,
    #[serde(default)]
    is_album: bool,
    #[serde(default)]
    track_count: u32,
    #[serde(default)]
    duration: Option<u64>,
    #[serde(default)]
    likes_count: Option<u64>,
    #[serde(default)]
    reposts_count: Option<u64>,
    #[serde(default)]
    permalink_url: Option<String>,
    #[serde(default)]
    created_at: Option<String>,
    #[serde(default)]
    last_modified: Option<String>,
    #[serde(default)]
    description: Option<String>,
    #[serde(default)]
    set_type: Option<String>,
    #[serde(default)]
    user: Option<FeaturedUserDto>,
}

#[derive(Deserialize)]
struct FeaturedUserDto {
    #[serde(deserialize_with = "crate::dto::flex::de_i64")]
    id: i64,
    #[serde(default)]
    urn: Option<String>,
    #[serde(default)]
    username: Option<String>,
    #[serde(default)]
    permalink: Option<String>,
    #[serde(default)]
    permalink_url: Option<String>,
    #[serde(default)]
    avatar_url: Option<String>,
    #[serde(default)]
    verified: bool,
}

impl FeaturedPlaylistDto {
    fn into_domain(self) -> PlaylistSummary {
        PlaylistSummary {
            id: Urn::new(self.urn.unwrap_or_else(|| format!("soundcloud:playlists:{}", self.id))),
            title: self.title.unwrap_or_default(),
            artwork_url: self.artwork_url,
            is_album: self.is_album,
            track_count: self.track_count,
            duration_ms: self.duration,
            likes_count: self.likes_count,
            reposts_count: self.reposts_count,
            permalink_url: self.permalink_url,
            created_at: self.created_at,
            release_year: None,
            owner: self.user.map(FeaturedUserDto::into_ref),
            user_favorite: None,
            description: self.description,
            last_modified: self.last_modified,
            kind: self
                .set_type
                .map(|t| t.to_ascii_lowercase())
                .or_else(|| self.is_album.then(|| "album".to_owned())),
        }
    }
}

impl FeaturedUserDto {
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
