use serde::{Deserialize, Serialize};

use crate::Track;

/// Совпадение полнотекстового поиска по лирике (`/search/lyrics`): трек + строка
/// текста, по которой нашлось (для карточки-цитаты). `matched_line` может быть пуст.
#[derive(Clone, Debug)]
pub struct LyricHit {
    pub track: Track,
    pub matched_line: Option<String>,
}

/// Строка лирики. `at_ms` задан для синхронизированной (LRC), иначе plain.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct LyricLine {
    pub at_ms: Option<u64>,
    pub text: String,
}

/// Лирика трека (`/lyrics/{sc_track_id}`).
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Lyrics {
    pub synced: bool,
    pub source: Option<String>,
    pub lines: Vec<LyricLine>,
}
