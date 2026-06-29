use serde::Deserialize;

use sc_domain::{AlbumArtist, AlbumCard, AlbumDetail, AlbumRef};

use crate::dto::track::TrackDto;

#[derive(Deserialize)]
pub(crate) struct AlbumArtistDto {
    pub id: String,
    #[serde(default)]
    pub name: Option<String>,
    #[serde(default)]
    pub role: Option<String>,
    #[serde(default)]
    pub avatar_url: Option<String>,
}

impl AlbumArtistDto {
    fn into_domain(self) -> AlbumArtist {
        AlbumArtist {
            id: self.id,
            name: self.name.unwrap_or_default(),
            role: self.role,
            avatar_url: self.avatar_url,
        }
    }
}

/// Карточка альбома: `/discover/albums`, `/search/db/albums`.
#[derive(Deserialize)]
pub(crate) struct AlbumCardDto {
    pub id: String,
    #[serde(default)]
    pub title: Option<String>,
    #[serde(default)]
    pub release_year: Option<i32>,
    #[serde(default)]
    pub release_month: Option<u32>,
    #[serde(default)]
    pub cover_url: Option<String>,
    #[serde(default)]
    pub confidence: f32,
    #[serde(default)]
    pub track_count: u32,
    #[serde(default)]
    pub total_duration_ms: Option<u64>,
    #[serde(default)]
    pub popularity: f32,
    #[serde(default)]
    pub star: bool,
    pub primary_artist: AlbumArtistDto,
}

impl AlbumCardDto {
    pub(crate) fn into_domain(self) -> AlbumCard {
        AlbumCard {
            id: self.id,
            title: self.title.unwrap_or_default(),
            release_year: self.release_year,
            release_month: self.release_month,
            cover_url: self.cover_url,
            confidence: self.confidence,
            track_count: self.track_count,
            total_duration_ms: self.total_duration_ms,
            popularity: self.popularity,
            star: self.star,
            primary_artist: self.primary_artist.into_domain(),
        }
    }
}

/// Ссылка на альбом из списка артиста: `/artists/{id}/albums`.
#[derive(Deserialize)]
pub(crate) struct AlbumRefDto {
    pub id: String,
    #[serde(default)]
    pub title: Option<String>,
    #[serde(default)]
    pub release_year: Option<i32>,
    #[serde(default)]
    pub role: Option<String>,
}

impl AlbumRefDto {
    pub(crate) fn into_domain(self) -> AlbumRef {
        AlbumRef {
            id: self.id,
            title: self.title.unwrap_or_default(),
            release_year: self.release_year,
            role: self.role,
        }
    }
}

#[derive(Deserialize)]
pub(crate) struct AlbumDetailDto {
    pub id: String,
    #[serde(default)]
    pub title: Option<String>,
    #[serde(default)]
    pub release_year: Option<i32>,
    #[serde(default)]
    pub cover_url: Option<String>,
    #[serde(default)]
    pub confidence: f32,
    pub primary_artist: AlbumArtistDto,
    #[serde(default)]
    pub artists: Vec<AlbumArtistDto>,
    #[serde(default)]
    pub tracks: Vec<TrackDto>,
}

impl AlbumDetailDto {
    pub(crate) fn into_domain(self) -> AlbumDetail {
        AlbumDetail {
            id: self.id,
            title: self.title.unwrap_or_default(),
            release_year: self.release_year,
            cover_url: self.cover_url,
            confidence: self.confidence,
            primary_artist: self.primary_artist.into_domain(),
            artists: self.artists.into_iter().map(AlbumArtistDto::into_domain).collect(),
            tracks: self.tracks.into_iter().map(TrackDto::into_domain).collect(),
        }
    }
}
