//! Публичные типы потока + изолированные сырые apiv2-DTO (чужой нестабильный
//! контракт живёт только здесь и не протекает выше).

use serde::Deserialize;

use sc_domain::track::TrackBadge;
use sc_domain::{ArtistRef, Track, Urn};

/// Страница результатов поиска.
#[derive(Clone, Debug)]
pub struct SearchPage<T> {
    pub items: Vec<T>,
    pub next_offset: Option<u32>,
}

/// Источник для скачивания. `preset` может быть не-AAC — поэтому источник идёт
/// ТОЛЬКО в `sc-cache` (транскод в m4a), а не в плеер напрямую.
#[derive(Clone, Debug)]
pub struct StreamSource {
    pub url: String,
    pub protocol: StreamProtocol,
    pub preset: AudioPreset,
    pub track_authorization: Option<String>,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum StreamProtocol {
    Progressive,
    Hls,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum AudioPreset {
    Mp3,
    Aac,
    Opus,
    AbrSq,
}

impl AudioPreset {
    /// Уже AAC — транскод в m4a не нужен (stream-copy).
    pub fn is_aac(self) -> bool {
        matches!(self, AudioPreset::Aac)
    }

    fn from_preset_str(value: &str) -> Option<Self> {
        match value {
            "mp3_1_0" => Some(Self::Mp3),
            "aac_160k" => Some(Self::Aac),
            "opus_0_0" => Some(Self::Opus),
            "abr_sq" => Some(Self::AbrSq),
            _ => None,
        }
    }

    /// Приоритет пресета (меньше — лучше). Порядок из легаси PRESET_ORDER.
    fn rank(self) -> usize {
        match self {
            Self::Mp3 => 0,
            Self::Aac => 1,
            Self::Opus => 2,
            Self::AbrSq => 3,
        }
    }
}

// --- сырые apiv2 DTO ---

#[derive(Deserialize)]
pub(crate) struct ApiTrack {
    pub id: u64,
    pub title: Option<String>,
    pub duration: Option<u64>,
    pub genre: Option<String>,
    pub artwork_url: Option<String>,
    pub waveform_url: Option<String>,
    pub playback_count: Option<u64>,
    pub user: Option<ApiUser>,
    pub media: Option<ApiMedia>,
    pub track_authorization: Option<String>,
}

#[derive(Deserialize)]
pub(crate) struct ApiUser {
    pub id: u64,
    pub username: Option<String>,
    pub avatar_url: Option<String>,
}

#[derive(Deserialize)]
pub(crate) struct ApiMedia {
    pub transcodings: Vec<ApiTranscoding>,
}

#[derive(Deserialize)]
pub(crate) struct ApiTranscoding {
    pub url: String,
    pub preset: Option<String>,
    pub snipped: Option<bool>,
    pub format: Option<ApiFormat>,
}

#[derive(Deserialize)]
pub(crate) struct ApiFormat {
    pub protocol: Option<String>,
}

#[derive(Deserialize)]
pub(crate) struct ApiSearchResponse {
    pub collection: Vec<ApiTrack>,
    pub next_href: Option<String>,
}

#[derive(Deserialize)]
pub(crate) struct TranscodingTarget {
    pub url: String,
}

impl ApiTrack {
    pub(crate) fn into_domain(self) -> Track {
        let artist = match self.user {
            Some(user) => ArtistRef {
                id: Urn::new(user.id.to_string()),
                name: user.username.unwrap_or_default(),
                avatar_url: user.avatar_url,
            },
            None => ArtistRef {
                id: Urn::new(String::new()),
                name: String::new(),
                avatar_url: None,
            },
        };
        Track {
            id: Urn::new(format!("soundcloud:tracks:{}", self.id)),
            title: self.title.unwrap_or_default(),
            artist,
            duration_ms: self.duration.unwrap_or(0),
            artwork_url: self.artwork_url,
            waveform_url: self.waveform_url,
            genre: self.genre,
            play_count: self.playback_count,
            likes_count: None,
            reposts_count: None,
            permalink_url: None,
            created_at: None,
            release_year: None,
            uploader: None,
            badge: TrackBadge::default(),
            user_favorite: None,
            is_cover: false,
            description: None,
            tags: Vec::new(),
            isrc: None,
            language: None,
            album: None,
            participants: Vec::new(),
        }
    }
}

impl ApiTranscoding {
    pub(crate) fn protocol(&self) -> StreamProtocol {
        match self.format.as_ref().and_then(|f| f.protocol.as_deref()) {
            Some("hls") => StreamProtocol::Hls,
            _ => StreamProtocol::Progressive,
        }
    }

    pub(crate) fn preset_kind(&self) -> Option<AudioPreset> {
        self.preset.as_deref().and_then(AudioPreset::from_preset_str)
    }

    /// Отсеять зашифрованные/обрезанные/preview-транскодинги.
    pub(crate) fn is_playable(&self) -> bool {
        let snipped = self.snipped.unwrap_or(false);
        let preview = self.url.contains("/preview");
        let encrypted = self.preset.as_deref().is_some_and(|p| p.contains("encrypted"))
            || self
                .format
                .as_ref()
                .and_then(|f| f.protocol.as_deref())
                .is_some_and(|p| p.contains("encrypted"));
        !snipped && !preview && !encrypted && self.preset_kind().is_some()
    }

    /// Ключ сортировки: сперва progressive, затем по приоритету пресета.
    pub(crate) fn sort_key(&self) -> (usize, usize) {
        let protocol_rank = match self.protocol() {
            StreamProtocol::Progressive => 0,
            StreamProtocol::Hls => 1,
        };
        let preset_rank = self.preset_kind().map_or(usize::MAX, AudioPreset::rank);
        (protocol_rank, preset_rank)
    }
}
