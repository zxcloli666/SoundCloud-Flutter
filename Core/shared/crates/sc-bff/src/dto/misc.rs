use serde::Deserialize;

use sc_domain::{HistoryEntry, HistoryPage, LyricLine, Lyrics, TrackStreams};

#[derive(Deserialize)]
pub(crate) struct TrackStreamsDto {
    #[serde(default)]
    pub hls_aac_160_url: Option<String>,
    #[serde(default)]
    pub hls_mp3_128_url: Option<String>,
    #[serde(default)]
    pub http_mp3_128_url: Option<String>,
    #[serde(default)]
    pub preview_mp3_128_url: Option<String>,
}

impl TrackStreamsDto {
    pub(crate) fn into_domain(self) -> TrackStreams {
        TrackStreams {
            hls_aac_160_url: self.hls_aac_160_url,
            hls_mp3_128_url: self.hls_mp3_128_url,
            http_mp3_128_url: self.http_mp3_128_url,
            preview_mp3_128_url: self.preview_mp3_128_url,
        }
    }
}

// История: бэкенд отдаёт camelCase.
#[derive(Deserialize)]
pub(crate) struct HistoryPageDto {
    #[serde(default)]
    pub collection: Vec<HistoryEntryDto>,
    #[serde(default)]
    pub total: u32,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct HistoryEntryDto {
    pub id: String,
    pub sc_track_id: String,
    #[serde(default)]
    pub title: Option<String>,
    #[serde(default)]
    pub artist_name: Option<String>,
    #[serde(default)]
    pub artist_urn: Option<String>,
    #[serde(default)]
    pub artwork_url: Option<String>,
    #[serde(default)]
    pub duration: u64,
    #[serde(default)]
    pub played_at: Option<String>,
}

impl HistoryPageDto {
    pub(crate) fn into_domain(self) -> HistoryPage {
        HistoryPage {
            items: self.collection.into_iter().map(HistoryEntryDto::into_domain).collect(),
            total: self.total,
        }
    }
}

impl HistoryEntryDto {
    fn into_domain(self) -> HistoryEntry {
        HistoryEntry {
            id: self.id,
            sc_track_id: self.sc_track_id,
            title: self.title.unwrap_or_default(),
            artist_name: self.artist_name.unwrap_or_default(),
            artist_urn: self.artist_urn,
            artwork_url: self.artwork_url,
            duration_ms: self.duration,
            played_at: self.played_at.unwrap_or_default(),
        }
    }
}

// Лирика. Бэкенд может отдавать синхро-строки (`{time, line}`) или plain-текст —
// разбираем обе формы best-effort.
#[derive(Deserialize)]
pub(crate) struct LyricsDto {
    #[serde(default)]
    pub synced: Option<bool>,
    #[serde(default)]
    pub source: Option<String>,
    #[serde(default)]
    pub lines: Vec<LyricLineDto>,
    #[serde(default)]
    pub plain: Option<String>,
}

#[derive(Deserialize)]
pub(crate) struct LyricLineDto {
    #[serde(default, alias = "time", alias = "at", alias = "ts")]
    pub at_ms: Option<u64>,
    #[serde(default, alias = "line", alias = "words")]
    pub text: Option<String>,
}

impl LyricsDto {
    pub(crate) fn into_domain(self) -> Lyrics {
        let mut lines: Vec<LyricLine> = self
            .lines
            .into_iter()
            .map(|l| LyricLine {
                at_ms: l.at_ms,
                text: l.text.unwrap_or_default(),
            })
            .collect();
        if lines.is_empty()
            && let Some(plain) = self.plain
        {
            lines = plain
                .lines()
                .map(|t| LyricLine {
                    at_ms: None,
                    text: t.to_owned(),
                })
                .collect();
        }
        let synced = self.synced.unwrap_or_else(|| lines.iter().any(|l| l.at_ms.is_some()));
        Lyrics {
            synced,
            source: self.source,
            lines,
        }
    }
}
