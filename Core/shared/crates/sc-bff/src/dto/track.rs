use serde::Deserialize;

use sc_domain::track::{TrackAlbum, TrackBadge, TrackParticipant};
use sc_domain::user::UserRef;
use sc_domain::{ArtistRef, Track, Urn};

use crate::dto::tag_list::parse_tag_list;

/// SC-трек в BFF-форме. Поля, которых может не быть, — `Option`/`#[serde(default)]`.
#[derive(Deserialize)]
pub(crate) struct TrackDto {
    #[serde(deserialize_with = "crate::dto::flex::de_i64")]
    pub id: i64,
    #[serde(default)]
    pub urn: Option<String>,
    #[serde(default)]
    pub title: Option<String>,
    #[serde(default)]
    pub duration: Option<u64>,
    #[serde(default)]
    pub artwork_url: Option<String>,
    #[serde(default)]
    pub waveform_url: Option<String>,
    #[serde(default)]
    pub genre: Option<String>,
    #[serde(default)]
    pub permalink_url: Option<String>,
    #[serde(default)]
    pub likes_count: Option<u64>,
    #[serde(default)]
    pub playback_count: Option<u64>,
    #[serde(default)]
    pub reposts_count: Option<u64>,
    #[serde(default)]
    pub created_at: Option<String>,
    #[serde(default)]
    pub release_year: Option<i32>,
    #[serde(default)]
    pub user_favorite: Option<bool>,
    #[serde(default)]
    pub description: Option<String>,
    #[serde(default)]
    pub tag_list: Option<String>,
    #[serde(default)]
    pub language: Option<String>,
    #[serde(default)]
    pub publisher_metadata: Option<PublisherMetadataDto>,
    #[serde(default)]
    pub user: Option<UserDto>,
    #[serde(default)]
    pub enrichment: Option<EnrichmentDto>,
    #[serde(default, rename = "_scd_meta")]
    pub scd_meta: Option<ScdMetaDto>,
}

#[derive(Deserialize)]
pub(crate) struct PublisherMetadataDto {
    #[serde(default)]
    pub isrc: Option<String>,
}

#[derive(Deserialize)]
pub(crate) struct UserDto {
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

#[derive(Deserialize)]
pub(crate) struct EnrichmentDto {
    #[serde(default)]
    pub primary_artist: Option<EnrichArtistDto>,
    #[serde(default)]
    pub album: Option<EnrichAlbumDto>,
    #[serde(default)]
    pub participants: Vec<EnrichParticipantDto>,
}

#[derive(Deserialize)]
pub(crate) struct EnrichArtistDto {
    pub id: String,
    #[serde(default)]
    pub name: Option<String>,
    #[serde(default)]
    pub avatar_url: Option<String>,
}

#[derive(Deserialize)]
pub(crate) struct EnrichAlbumDto {
    pub id: String,
    #[serde(default)]
    pub title: Option<String>,
    #[serde(default)]
    pub cover_url: Option<String>,
    #[serde(default)]
    pub year: Option<i32>,
}

#[derive(Deserialize)]
pub(crate) struct EnrichParticipantDto {
    pub artist: EnrichArtistDto,
    #[serde(default)]
    pub role: Option<String>,
}

#[derive(Deserialize)]
pub(crate) struct ScdMetaDto {
    #[serde(default)]
    pub storage_state: Option<String>,
    #[serde(default)]
    pub storage_quality: Option<String>,
    #[serde(default)]
    pub index_state: Option<String>,
    #[serde(default)]
    pub enrich_state: Option<String>,
}

impl UserDto {
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

impl TrackDto {
    pub(crate) fn into_domain(self) -> Track {
        let urn = self
            .urn
            .clone()
            .unwrap_or_else(|| format!("soundcloud:tracks:{}", self.id));

        // Display-артист: enrichment.primary_artist, иначе загрузчик.
        let enrich_artist = self.enrichment.as_ref().and_then(|e| e.primary_artist.as_ref());
        let artist = match enrich_artist {
            Some(a) => ArtistRef {
                id: Urn::new(a.id.clone()),
                name: a.name.clone().unwrap_or_default(),
                avatar_url: a.avatar_url.clone(),
            },
            None => match self.user.as_ref() {
                Some(u) => ArtistRef {
                    id: Urn::new(
                        u.urn.clone().unwrap_or_else(|| format!("soundcloud:users:{}", u.id)),
                    ),
                    name: u.username.clone().unwrap_or_default(),
                    avatar_url: u.avatar_url.clone(),
                },
                None => ArtistRef {
                    id: Urn::new(String::new()),
                    name: String::new(),
                    avatar_url: None,
                },
            },
        };

        let badge = self.scd_meta.map_or_else(TrackBadge::default, |m| TrackBadge {
            storage_state: m.storage_state,
            storage_quality: m.storage_quality,
            index_state: m.index_state,
            enrich_state: m.enrich_state,
        });

        let isrc = self.publisher_metadata.and_then(|p| p.isrc);
        let tags = self.tag_list.as_deref().map(parse_tag_list).unwrap_or_default();
        let album = self.enrichment.as_ref().and_then(|e| e.album.as_ref()).map(|a| TrackAlbum {
            id: a.id.clone(),
            title: a.title.clone().unwrap_or_default(),
            cover_url: a.cover_url.clone(),
            year: a.year,
        });
        let participants = self
            .enrichment
            .as_ref()
            .map(|e| {
                e.participants
                    .iter()
                    .map(|p| TrackParticipant {
                        id: Some(p.artist.id.clone()),
                        name: p.artist.name.clone().unwrap_or_default(),
                        role: p.role.clone(),
                    })
                    .collect()
            })
            .unwrap_or_default();

        Track {
            id: Urn::new(urn),
            title: self.title.unwrap_or_default(),
            artist,
            duration_ms: self.duration.unwrap_or(0),
            artwork_url: self.artwork_url,
            waveform_url: self.waveform_url,
            genre: self.genre,
            play_count: self.playback_count,
            likes_count: self.likes_count,
            reposts_count: self.reposts_count,
            permalink_url: self.permalink_url,
            created_at: self.created_at,
            release_year: self.release_year,
            uploader: self.user.map(UserDto::into_ref),
            badge,
            user_favorite: self.user_favorite,
            is_cover: false,
            description: self.description,
            tags,
            isrc,
            language: self.language,
            album,
            participants,
        }
    }
}
