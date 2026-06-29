use serde::Deserialize;

use sc_domain::{ListPage, LyricHit, VibeResult};

use crate::dto::track::TrackDto;

/// `/search/vibe` → `{items:[Track], atmosphere, status}`. `status=="preparing"` —
/// вектор ещё кодируется (не «ничего не нашлось»).
#[derive(Deserialize)]
pub(crate) struct VibeDto {
    #[serde(default)]
    pub items: Vec<TrackDto>,
    #[serde(default)]
    pub status: Option<String>,
}

impl VibeDto {
    pub(crate) fn into_result(self) -> VibeResult {
        let preparing = self
            .status
            .as_deref()
            .is_some_and(|s| s.eq_ignore_ascii_case("preparing") || s.eq_ignore_ascii_case("encoding"));
        VibeResult {
            tracks: self.items.into_iter().map(TrackDto::into_domain).collect(),
            preparing,
        }
    }
}

/// `/search/lyrics` → `{collection:[{track, matchedLine?, score}], page,
/// page_size, has_more, mode}`. Разворачиваем `.track` в трек.
#[derive(Deserialize)]
pub(crate) struct LyricsSearchDto {
    #[serde(default)]
    pub collection: Vec<LyricsHitDto>,
    #[serde(default)]
    pub page: u32,
    #[serde(default)]
    pub page_size: u32,
    #[serde(default)]
    pub has_more: bool,
}

#[derive(Deserialize)]
pub(crate) struct LyricsHitDto {
    pub track: TrackDto,
    /// Совпавшая строка текста — для карточки-цитаты (бэк: `matchedLine`).
    #[serde(rename = "matchedLine", default)]
    pub matched_line: Option<String>,
}

impl LyricsSearchDto {
    pub(crate) fn into_page(self) -> ListPage<LyricHit> {
        let items: Vec<LyricHit> = self
            .collection
            .into_iter()
            .map(|h| LyricHit {
                track: h.track.into_domain(),
                matched_line: h.matched_line.filter(|s| !s.trim().is_empty()),
            })
            .collect();
        let size = if self.page_size == 0 { items.len() as u32 } else { self.page_size };
        ListPage::new(items, self.page, size, self.has_more)
    }
}
