//! Плоские DTO для FRB (только строки/числа/Option/Vec) + страничный конверт.
//! Мапперы из доменных моделей — в [`crate::data`].

use crate::api::TrackDto;

/// Страница списка треков для Dart.
#[derive(Clone, Debug)]
pub struct TrackPageDto {
    pub items: Vec<TrackDto>,
    pub page: u32,
    pub page_size: u32,
    pub has_more: bool,
}

#[derive(Clone, Debug)]
pub struct ArtistCardDto {
    pub id: String,
    pub name: String,
    pub country: Option<String>,
    pub avatar_url: Option<String>,
    pub confidence: f32,
    pub star: bool,
    pub track_count_primary: u32,
    pub track_count_featured: u32,
    pub album_count: u32,
    pub monthly_listeners: u64,
    pub trending: f32,
    pub popularity: f32,
    pub tags: Vec<String>,
    pub aura_id: Option<String>,
    pub custom_hex: Option<String>,
}

#[derive(Clone, Debug)]
pub struct ArtistCardPageDto {
    pub items: Vec<ArtistCardDto>,
    pub page: u32,
    pub page_size: u32,
    pub has_more: bool,
}

#[derive(Clone, Debug)]
pub struct SocialDto {
    pub kind: String,
    pub url: String,
    pub source: Option<String>,
    pub verified: bool,
}

#[derive(Clone, Debug)]
pub struct ScAccountDto {
    pub sc_user_id: String,
    pub role: Option<String>,
    pub source: Option<String>,
    pub verified: bool,
}

#[derive(Clone, Debug)]
pub struct RelatedArtistDto {
    pub id: String,
    pub name: String,
    pub country: Option<String>,
    pub avatar_url: Option<String>,
    pub weight: f32,
}

#[derive(Clone, Debug)]
pub struct ArtistDetailDto {
    pub id: String,
    pub name: String,
    pub country: Option<String>,
    pub bio: Option<String>,
    pub avatar_url: Option<String>,
    pub confidence: f32,
    pub track_count: u32,
    pub track_count_primary: u32,
    pub track_count_featured: u32,
    pub album_count: u32,
    pub socials: Vec<SocialDto>,
    pub sc_accounts: Vec<ScAccountDto>,
    pub related_artists: Vec<RelatedArtistDto>,
    pub popular_tracks: Vec<TrackDto>,
}

#[derive(Clone, Debug)]
pub struct AlbumArtistDto {
    pub id: String,
    pub name: String,
    pub role: Option<String>,
    pub avatar_url: Option<String>,
}

#[derive(Clone, Debug)]
pub struct AlbumCardDto {
    pub id: String,
    pub title: String,
    pub release_year: Option<i32>,
    pub release_month: Option<u32>,
    pub cover_url: Option<String>,
    pub confidence: f32,
    pub track_count: u32,
    pub total_duration_ms: Option<u64>,
    pub popularity: f32,
    pub star: bool,
    pub primary_artist: AlbumArtistDto,
}

#[derive(Clone, Debug)]
pub struct AlbumCardPageDto {
    pub items: Vec<AlbumCardDto>,
    pub page: u32,
    pub page_size: u32,
    pub has_more: bool,
}

#[derive(Clone, Debug)]
pub struct AlbumRefDto {
    pub id: String,
    pub title: String,
    pub release_year: Option<i32>,
    pub role: Option<String>,
}

#[derive(Clone, Debug)]
pub struct AlbumDetailDto {
    pub id: String,
    pub title: String,
    pub release_year: Option<i32>,
    pub cover_url: Option<String>,
    pub confidence: f32,
    pub primary_artist: AlbumArtistDto,
    pub artists: Vec<AlbumArtistDto>,
    pub tracks: Vec<TrackDto>,
}

#[derive(Clone, Debug)]
pub struct PlaylistSummaryDto {
    pub urn: String,
    pub title: String,
    pub artwork_url: Option<String>,
    pub is_album: bool,
    pub track_count: u32,
    pub duration_ms: Option<u64>,
    pub likes_count: Option<u64>,
    pub reposts_count: Option<u64>,
    pub permalink_url: Option<String>,
    pub created_at: Option<String>,
    pub release_year: Option<i32>,
    pub owner_id: Option<String>,
    pub owner_username: Option<String>,
    pub owner_avatar_url: Option<String>,
    pub user_favorite: Option<bool>,
    pub description: Option<String>,
    pub last_modified: Option<String>,
    pub kind: Option<String>,
}

#[derive(Clone, Debug)]
pub struct PlaylistSummaryPageDto {
    pub items: Vec<PlaylistSummaryDto>,
    pub page: u32,
    pub page_size: u32,
    pub has_more: bool,
}

#[derive(Clone, Debug)]
pub struct PlaylistDetailDto {
    pub summary: PlaylistSummaryDto,
    pub tracks: Vec<TrackDto>,
}

#[derive(Clone, Debug)]
pub struct UserDto {
    pub urn: String,
    pub username: String,
    pub permalink: Option<String>,
    pub permalink_url: Option<String>,
    pub avatar_url: Option<String>,
    pub full_name: Option<String>,
    pub city: Option<String>,
    pub country_code: Option<String>,
    pub description: Option<String>,
    pub verified: bool,
    pub followers_count: Option<u64>,
    pub followings_count: Option<u64>,
    pub track_count: Option<u64>,
    pub playlist_count: Option<u64>,
    pub public_favorites_count: Option<i64>,
    pub plan: Option<String>,
    pub created_at: Option<String>,
}

#[derive(Clone, Debug)]
pub struct UserPageDto {
    pub items: Vec<UserDto>,
    pub page: u32,
    pub page_size: u32,
    pub has_more: bool,
}

/// Комментарий трека (автор уплощён внутрь). `timestamp_ms` — таймкод в треке.
#[derive(Clone, Debug)]
pub struct CommentDto {
    pub id: i64,
    pub body: String,
    pub timestamp_ms: Option<i64>,
    pub created_at: Option<String>,
    pub user_urn: String,
    pub username: String,
    pub avatar_url: Option<String>,
    pub permalink_url: Option<String>,
}

#[derive(Clone, Debug)]
pub struct CommentPageDto {
    pub items: Vec<CommentDto>,
    pub page: u32,
    pub page_size: u32,
    pub has_more: bool,
}

#[derive(Clone, Debug)]
pub struct MeDto {
    pub urn: String,
    pub username: String,
    pub permalink: Option<String>,
    pub permalink_url: Option<String>,
    pub avatar_url: Option<String>,
    pub plan: Option<String>,
    pub premium: bool,
    pub followers_count: Option<u64>,
    pub followings_count: Option<u64>,
    pub public_favorites_count: Option<u64>,
    pub private_playlists_count: Option<u64>,
    pub playlist_count: Option<u64>,
}

#[derive(Clone, Debug)]
pub struct ClusterDto {
    pub id: String,
    pub track_ids: Vec<String>,
    pub neighbors: Vec<ClusterNeighborDto>,
}

#[derive(Clone, Debug)]
pub struct ClusterNeighborDto {
    pub artist_id: String,
    pub artist_name: String,
    pub avatar_url: Option<String>,
    pub track_id: String,
}

#[derive(Clone, Debug)]
pub struct WaveItemDto {
    pub id: i64,
    pub score: f32,
}

#[derive(Clone, Debug)]
pub struct WaveDto {
    pub items: Vec<WaveItemDto>,
    pub cursor: Option<String>,
}

#[derive(Clone, Debug)]
pub struct DiscoverSummaryDto {
    pub artists_count: u64,
    pub albums_count: u64,
    pub fresh_count: u64,
    pub fresh_window_days: u32,
}

#[derive(Clone, Debug)]
pub struct TagDto {
    pub id: String,
    pub label: String,
    pub count: u64,
}

#[derive(Clone, Debug)]
pub struct TrackStreamsDto {
    pub hls_aac_160_url: Option<String>,
    pub hls_mp3_128_url: Option<String>,
    pub http_mp3_128_url: Option<String>,
    pub preview_mp3_128_url: Option<String>,
}

#[derive(Clone, Debug)]
pub struct HistoryEntryDto {
    pub id: String,
    pub sc_track_id: String,
    pub title: String,
    pub artist_name: String,
    pub artist_urn: Option<String>,
    pub artwork_url: Option<String>,
    pub duration_ms: u64,
    pub played_at: String,
}

#[derive(Clone, Debug)]
pub struct HistoryPageDto {
    pub items: Vec<HistoryEntryDto>,
    pub total: u32,
}

#[derive(Clone, Debug)]
pub struct LyricLineDto {
    pub at_ms: Option<u64>,
    pub text: String,
}

#[derive(Clone, Debug)]
pub struct LyricsDto {
    pub synced: bool,
    pub source: Option<String>,
    pub lines: Vec<LyricLineDto>,
}

/// Редакционный пик: один из полей задан в зависимости от `kind`.
#[derive(Clone, Debug)]
pub struct FeaturedDto {
    pub kind: String,
    pub track: Option<TrackDto>,
    pub playlist: Option<PlaylistSummaryDto>,
}

/// Состояние авторизации для гейта. `has_session` — локальный токен,
/// `authenticated` — подтверждение бэкендом.
#[derive(Clone, Debug)]
pub struct AuthStatusDto {
    pub has_session: bool,
    pub authenticated: bool,
    pub session_id: Option<String>,
    pub username: Option<String>,
    pub token_state: Option<String>,
}

#[derive(Clone, Debug)]
pub struct LoginStartDto {
    pub url: String,
    pub login_request_id: String,
}

#[derive(Clone, Debug)]
pub struct LoginStatusDto {
    pub status: String,
    pub step: Option<String>,
    pub session_id: Option<String>,
    pub username: Option<String>,
    pub error: Option<String>,
    pub redirect_url: Option<String>,
}

/// QR-перенос сессии: создан линк. `payload` — строка для QR.
#[derive(Clone, Debug)]
pub struct LinkCreateDto {
    pub link_request_id: String,
    pub claim_token: String,
    pub mode: String,
    pub payload: String,
    pub expires_at: Option<String>,
}

#[derive(Clone, Debug)]
pub struct LinkStatusDto {
    pub status: String,
    pub mode: Option<String>,
    pub session_id: Option<String>,
    pub error: Option<String>,
}

#[derive(Clone, Debug)]
pub struct LinkClaimDto {
    pub session_id: Option<String>,
    pub mode: Option<String>,
}
