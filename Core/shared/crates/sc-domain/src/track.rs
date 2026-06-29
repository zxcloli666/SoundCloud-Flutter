use serde::{Deserialize, Serialize};

use crate::ids::Urn;
use crate::user::UserRef;

/// Результат vibe-поиска: треки + флаг «вектор ещё кодируется на воркере»
/// (`/search/vibe` status). `preparing` → стена не пуста «по результату», а ждёт
/// энкодинг — рисуем плашку «Ловим вайб», а не «ничего не найдено».
#[derive(Clone, Debug, Default)]
pub struct VibeResult {
    pub tracks: Vec<Track>,
    pub preparing: bool,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Track {
    pub id: Urn,
    pub title: String,
    /// Отображаемый артист: enrichment.primary_artist, иначе загрузчик.
    pub artist: ArtistRef,
    pub duration_ms: u64,
    pub artwork_url: Option<String>,
    pub waveform_url: Option<String>,
    pub genre: Option<String>,
    pub play_count: Option<u64>,
    pub likes_count: Option<u64>,
    pub reposts_count: Option<u64>,
    pub permalink_url: Option<String>,
    pub created_at: Option<String>,
    pub release_year: Option<i32>,
    /// SC-загрузчик трека (отличается от display-артиста при enrichment).
    pub uploader: Option<UserRef>,
    pub badge: TrackBadge,
    /// Лайкнут текущим пользователем (на likeable-списках).
    pub user_favorite: Option<bool>,
    /// Денормализованный признак кавера — каталог фильтрует на read-path.
    pub is_cover: bool,
    // --- liner notes (credits/теги/альбом) ---
    pub description: Option<String>,
    pub tags: Vec<String>,
    pub isrc: Option<String>,
    pub language: Option<String>,
    pub album: Option<TrackAlbum>,
    /// Кредиты (продюсеры/фичеринг) из enrichment.participants.
    pub participants: Vec<TrackParticipant>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ArtistRef {
    pub id: Urn,
    pub name: String,
    pub avatar_url: Option<String>,
}

/// Альбом трека (из enrichment.album).
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct TrackAlbum {
    pub id: String,
    pub title: String,
    pub cover_url: Option<String>,
    pub year: Option<i32>,
}

/// Участник трека (продюсер/фичеринг) из enrichment.participants.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct TrackParticipant {
    pub id: Option<String>,
    pub name: String,
    pub role: Option<String>,
}

/// Бейдж-метаданные из `_scd_meta`: качество хранения и стадии конвейера.
#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct TrackBadge {
    pub storage_state: Option<String>,
    pub storage_quality: Option<String>,
    pub index_state: Option<String>,
    pub enrich_state: Option<String>,
}
