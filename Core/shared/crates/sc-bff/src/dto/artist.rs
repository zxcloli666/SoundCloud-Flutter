use serde::Deserialize;

use sc_domain::{ArtistCard, ArtistDetail, RelatedArtist, ScAccount, Social};

use crate::dto::track::TrackDto;

/// Карточка артиста: общая для `/discover/artists` и `/search/db/artists`
/// (поиск добавляет aura_id/custom_hex).
#[derive(Deserialize)]
pub(crate) struct ArtistCardDto {
    pub id: String,
    #[serde(default)]
    pub name: Option<String>,
    #[serde(default)]
    pub country: Option<String>,
    #[serde(default)]
    pub avatar_url: Option<String>,
    #[serde(default)]
    pub confidence: f32,
    #[serde(default)]
    pub star: bool,
    #[serde(default)]
    pub track_count_primary: u32,
    #[serde(default)]
    pub track_count_featured: u32,
    #[serde(default)]
    pub album_count: u32,
    #[serde(default)]
    pub monthly_listeners: u64,
    #[serde(default)]
    pub trending: f32,
    #[serde(default)]
    pub popularity: f32,
    #[serde(default)]
    pub tags: Vec<String>,
    #[serde(default)]
    pub aura_id: Option<String>,
    #[serde(default)]
    pub custom_hex: Option<String>,
}

impl ArtistCardDto {
    pub(crate) fn into_domain(self) -> ArtistCard {
        ArtistCard {
            id: self.id,
            name: self.name.unwrap_or_default(),
            country: self.country,
            avatar_url: self.avatar_url,
            confidence: self.confidence,
            star: self.star,
            track_count_primary: self.track_count_primary,
            track_count_featured: self.track_count_featured,
            album_count: self.album_count,
            monthly_listeners: self.monthly_listeners,
            trending: self.trending,
            popularity: self.popularity,
            tags: self.tags,
            aura_id: self.aura_id,
            custom_hex: self.custom_hex,
        }
    }
}

#[derive(Deserialize)]
pub(crate) struct ArtistDetailDto {
    pub id: String,
    #[serde(default)]
    pub name: Option<String>,
    #[serde(default)]
    pub country: Option<String>,
    #[serde(default)]
    pub bio: Option<String>,
    #[serde(default)]
    pub avatar_url: Option<String>,
    #[serde(default)]
    pub confidence: f32,
    #[serde(default)]
    pub track_count: u32,
    #[serde(default)]
    pub track_count_primary: u32,
    #[serde(default)]
    pub track_count_featured: u32,
    #[serde(default)]
    pub album_count: u32,
    #[serde(default)]
    pub socials: Vec<SocialDto>,
    #[serde(default)]
    pub sc_accounts: Vec<ScAccountDto>,
    #[serde(default)]
    pub related_artists: Vec<RelatedArtistDto>,
    #[serde(default)]
    pub popular_tracks: Vec<TrackDto>,
}

#[derive(Deserialize)]
pub(crate) struct SocialDto {
    pub kind: String,
    pub url: String,
    #[serde(default)]
    pub source: Option<String>,
    #[serde(default)]
    pub verified: bool,
}

#[derive(Deserialize)]
pub(crate) struct ScAccountDto {
    pub sc_user_id: String,
    #[serde(default)]
    pub role: Option<String>,
    #[serde(default)]
    pub source: Option<String>,
    #[serde(default)]
    pub verified: bool,
}

#[derive(Deserialize)]
pub(crate) struct RelatedArtistDto {
    pub id: String,
    #[serde(default)]
    pub name: Option<String>,
    #[serde(default)]
    pub country: Option<String>,
    #[serde(default)]
    pub avatar_url: Option<String>,
    #[serde(default)]
    pub weight: f32,
}

impl ArtistDetailDto {
    pub(crate) fn into_domain(self) -> ArtistDetail {
        ArtistDetail {
            id: self.id,
            name: self.name.unwrap_or_default(),
            country: self.country,
            bio: self.bio,
            avatar_url: self.avatar_url,
            confidence: self.confidence,
            track_count: self.track_count,
            track_count_primary: self.track_count_primary,
            track_count_featured: self.track_count_featured,
            album_count: self.album_count,
            socials: self.socials.into_iter().map(SocialDto::into_domain).collect(),
            sc_accounts: self.sc_accounts.into_iter().map(ScAccountDto::into_domain).collect(),
            related_artists: self
                .related_artists
                .into_iter()
                .map(RelatedArtistDto::into_domain)
                .collect(),
            popular_tracks: self.popular_tracks.into_iter().map(TrackDto::into_domain).collect(),
        }
    }
}

impl SocialDto {
    fn into_domain(self) -> Social {
        Social {
            kind: self.kind,
            url: self.url,
            source: self.source,
            verified: self.verified,
        }
    }
}

impl ScAccountDto {
    fn into_domain(self) -> ScAccount {
        ScAccount {
            sc_user_id: self.sc_user_id,
            role: self.role,
            source: self.source,
            verified: self.verified,
        }
    }
}

impl RelatedArtistDto {
    fn into_domain(self) -> RelatedArtist {
        RelatedArtist {
            id: self.id,
            name: self.name.unwrap_or_default(),
            country: self.country,
            avatar_url: self.avatar_url,
            weight: self.weight,
        }
    }
}
