//! Плоские FRB-DTO третьей волны (социал/каталог/аура). Мапперы — в
//! [`crate::map`]. Списки переиспользуют TrackPageDto/UserPageDto/
//! PlaylistSummaryPageDto, карточки — ArtistCardDto/AlbumCardDto.

use crate::dto::{AlbumCardDto, ArtistCardDto};

#[derive(Clone, Debug)]
pub struct ArtistStarDto {
    pub premium: bool,
    pub aura_id: Option<String>,
    pub custom_hex: Option<String>,
    pub source_sc_user_id: Option<String>,
}

#[derive(Clone, Debug)]
pub struct AuraDto {
    pub aura_id: Option<String>,
    pub custom_hex: Option<String>,
}

#[derive(Clone, Debug)]
pub struct WebProfileDto {
    pub network: Option<String>,
    pub title: Option<String>,
    pub url: String,
    pub username: Option<String>,
}

#[derive(Clone, Debug)]
pub struct AlbumYearBucketDto {
    pub year: i32,
    pub items: Vec<AlbumCardDto>,
}

/// Курсорная страница каталога артистов (`/discover/artists`).
#[derive(Clone, Debug)]
pub struct DiscoverArtistsPageDto {
    pub items: Vec<ArtistCardDto>,
    pub next_cursor: Option<String>,
}

/// Курсорная страница каталога альбомов (`/discover/albums`).
#[derive(Clone, Debug)]
pub struct DiscoverAlbumsPageDto {
    pub items: Vec<AlbumCardDto>,
    pub next_cursor: Option<String>,
}

/// Элемент «В центре внимания» (`/discover/spotlight`): артист или альбом.
#[derive(Clone, Debug)]
pub enum SpotlightItemDto {
    Artist(ArtistCardDto),
    Album(AlbumCardDto),
}

/// Лента «В центре внимания» — курируемые карточки без пагинации.
#[derive(Clone, Debug)]
pub struct SpotlightFeedDto {
    pub items: Vec<SpotlightItemDto>,
}

/// Результат vibe-поиска: треки + флаг «вектор кодируется» (плашка «Ловим вайб»).
#[derive(Clone, Debug)]
pub struct VibePageDto {
    pub items: Vec<crate::api::TrackDto>,
    pub preparing: bool,
}

/// Хит поиска по лирике: трек + совпавшая строка текста (для карточки-цитаты).
#[derive(Clone, Debug)]
pub struct LyricHitDto {
    pub track: crate::api::TrackDto,
    pub matched_line: Option<String>,
}

/// Страница хитов поиска по лирике.
#[derive(Clone, Debug)]
pub struct LyricHitPageDto {
    pub items: Vec<LyricHitDto>,
    pub page: u32,
    pub page_size: u32,
    pub has_more: bool,
}

/// Запись оффлайн-кэша (один m4a на диске).
#[derive(Clone, Debug)]
pub struct CacheEntryDto {
    pub urn: String,
    pub sc_id: i64,
    pub bytes: i64,
}

/// Параметры поиска обоев (вход FRB). `source`: wallhaven|pinterest|konachan|
/// safebooru. `cursor` — непрозрачный токен следующей страницы из [`WallpaperPageDto`].
#[derive(Clone, Debug)]
pub struct WallpaperQueryDto {
    pub source: String,
    pub query: String,
    pub category: Option<String>,
    pub color: Option<String>,
    pub cursor: Option<String>,
    pub adult: bool,
    pub api_key: Option<String>,
}

/// Один результат поиска обоев.
#[derive(Clone, Debug)]
pub struct WallpaperHitDto {
    pub id: String,
    pub thumb: String,
    pub full: String,
    pub resolution: String,
}

/// Страница обоев + курсор следующей (null — конец).
#[derive(Clone, Debug)]
pub struct WallpaperPageDto {
    pub items: Vec<WallpaperHitDto>,
    pub cursor: Option<String>,
}
