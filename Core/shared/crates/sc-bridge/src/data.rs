//! FRB-функции слоя данных: чтение бэкенда через [`sc_core::ScRuntime`].
//! Каждая зовёт `bridge.rt.block_on(...)` и маппит домен в плоский DTO
//! ([`crate::map`]). Зеркалит существующий [`crate::api::search`].

use sc_domain::Urn;

use crate::api::{BridgeError, bridge, track_to_dto};
use crate::dto::{
    AlbumCardPageDto, AlbumDetailDto, AlbumRefDto, ArtistCardPageDto, ArtistDetailDto, AuthStatusDto,
    ClusterDto, DiscoverSummaryDto, FeaturedDto, HistoryPageDto, LinkClaimDto, LinkCreateDto,
    LinkStatusDto, LoginStartDto, LoginStatusDto, LyricsDto, MeDto, PlaylistDetailDto,
    PlaylistSummaryPageDto, TagDto, TrackPageDto, TrackStreamsDto, UserPageDto, WaveDto,
};
use crate::dto_social::{
    AlbumYearBucketDto, DiscoverAlbumsPageDto, DiscoverArtistsPageDto, SpotlightFeedDto,
};
use crate::{map, map_misc};

// --- поиск ---

pub fn search_artists(
    query: String,
    limit: u32,
    offset: u32,
) -> Result<ArtistCardPageDto, BridgeError> {
    let b = bridge()?;
    let page = b.rt.block_on(b.core.search_artists(&query, limit, offset))?;
    Ok(map::artist_card_page(page))
}

pub fn search_albums(
    query: String,
    limit: u32,
    offset: u32,
) -> Result<AlbumCardPageDto, BridgeError> {
    let b = bridge()?;
    let page = b.rt.block_on(b.core.search_albums(&query, limit, offset))?;
    Ok(map::album_card_page(page))
}

pub fn search_playlists(
    query: String,
    limit: u32,
    offset: u32,
) -> Result<PlaylistSummaryPageDto, BridgeError> {
    let b = bridge()?;
    let page = b.rt.block_on(b.core.search_playlists(&query, limit, offset))?;
    Ok(map::playlist_summary_page(page))
}

pub fn search_users(query: String, limit: u32, offset: u32) -> Result<UserPageDto, BridgeError> {
    let b = bridge()?;
    let page = b.rt.block_on(b.core.search_users(&query, limit, offset))?;
    Ok(map_misc::user_page(page))
}

// --- треки ---

pub fn track_related(urn: String, limit: u32) -> Result<TrackPageDto, BridgeError> {
    let b = bridge()?;
    let page = b.rt.block_on(b.core.track_related(&Urn::new(urn), limit))?;
    Ok(map::track_page(page))
}

pub fn track_streams(urn: String) -> Result<TrackStreamsDto, BridgeError> {
    let b = bridge()?;
    let streams = b.rt.block_on(b.core.track_streams(&Urn::new(urn)))?;
    Ok(map_misc::track_streams(streams))
}

// --- дом / волна ---

pub fn home_river(
    limit: u32,
    languages: Vec<String>,
    hide_listened: bool,
) -> Result<Vec<ClusterDto>, BridgeError> {
    let b = bridge()?;
    let clusters = b
        .rt
        .block_on(b.core.home_clusters(limit, &languages, hide_listened))?;
    Ok(clusters.into_iter().map(map_misc::cluster).collect())
}

pub fn wave(
    limit: u32,
    cursor: Option<String>,
    languages: Vec<String>,
    hide_listened: bool,
) -> Result<WaveDto, BridgeError> {
    let b = bridge()?;
    let wave =
        b.rt.block_on(b.core.wave(limit, cursor.as_deref(), &languages, hide_listened))?;
    Ok(map_misc::wave(wave))
}

pub fn recommendations_feedback(cluster_id: String, kind: String) -> Result<(), BridgeError> {
    let b = bridge()?;
    b.rt.block_on(b.core.recommendations_feedback(&cluster_id, &kind))?;
    Ok(())
}

pub fn wave_feedback(
    cursor: String,
    negatives: u32,
    positives: u32,
) -> Result<Option<String>, BridgeError> {
    let b = bridge()?;
    Ok(b.rt.block_on(b.core.wave_feedback(&cursor, negatives, positives))?)
}

// --- каталог ---

pub fn discover_summary() -> Result<DiscoverSummaryDto, BridgeError> {
    let b = bridge()?;
    Ok(map_misc::discover_summary(b.rt.block_on(b.core.discover_summary())?))
}

pub fn discover_artists(
    limit: u32,
    cursor: Option<String>,
    sort: Option<String>,
    tag: Option<String>,
    q: Option<String>,
) -> Result<DiscoverArtistsPageDto, BridgeError> {
    let b = bridge()?;
    let page = b.rt.block_on(b.core.discover_artists(
        limit,
        cursor.as_deref(),
        sort.as_deref(),
        tag.as_deref(),
        q.as_deref(),
    ))?;
    Ok(map::discover_artists_page(page))
}

pub fn discover_albums(
    limit: u32,
    cursor: Option<String>,
    sort: Option<String>,
    kind: Option<String>,
    q: Option<String>,
) -> Result<DiscoverAlbumsPageDto, BridgeError> {
    let b = bridge()?;
    let page = b.rt.block_on(b.core.discover_albums(
        limit,
        cursor.as_deref(),
        sort.as_deref(),
        kind.as_deref(),
        q.as_deref(),
    ))?;
    Ok(map::discover_albums_page(page))
}

pub fn discover_albums_by_year(
    years: u32,
    per_year: u32,
    kind: Option<String>,
) -> Result<Vec<AlbumYearBucketDto>, BridgeError> {
    let b = bridge()?;
    let buckets = b.rt.block_on(b.core.discover_albums_by_year(years, per_year, kind.as_deref()))?;
    Ok(buckets.into_iter().map(map::album_year_bucket).collect())
}

pub fn discover_random(kind: Option<String>) -> Result<Option<String>, BridgeError> {
    let b = bridge()?;
    Ok(b.rt.block_on(b.core.discover_random(kind.as_deref()))?)
}

pub fn discover_tags() -> Result<Vec<TagDto>, BridgeError> {
    let b = bridge()?;
    let items = b.rt.block_on(b.core.discover_tags())?;
    Ok(items.into_iter().map(map_misc::tag).collect())
}

pub fn discover_spotlight(limit: Option<u32>) -> Result<SpotlightFeedDto, BridgeError> {
    let b = bridge()?;
    let items = b.rt.block_on(b.core.discover_spotlight(limit))?;
    Ok(map::spotlight_feed(items))
}

// --- артист ---

pub fn artist_detail(id: String) -> Result<ArtistDetailDto, BridgeError> {
    let b = bridge()?;
    Ok(map::artist_detail(b.rt.block_on(b.core.artist_detail(&id))?))
}

pub fn artist_tracks(
    id: String,
    role: String,
    limit: u32,
    offset: u32,
) -> Result<TrackPageDto, BridgeError> {
    let b = bridge()?;
    let page = b.rt.block_on(b.core.artist_tracks(&id, &role, limit, offset))?;
    Ok(map::track_page(page))
}

pub fn artist_albums(id: String) -> Result<Vec<AlbumRefDto>, BridgeError> {
    let b = bridge()?;
    let items = b.rt.block_on(b.core.artist_albums(&id))?;
    Ok(items.into_iter().map(map::album_ref).collect())
}

// --- альбом / плейлист ---

pub fn album_detail(id: String) -> Result<AlbumDetailDto, BridgeError> {
    let b = bridge()?;
    Ok(map::album_detail(b.rt.block_on(b.core.album_detail(&id))?))
}

pub fn playlist_detail(
    urn: String,
    limit: u32,
    offset: u32,
) -> Result<PlaylistDetailDto, BridgeError> {
    let b = bridge()?;
    let d = b.rt.block_on(b.core.playlist_detail(&Urn::new(urn), limit, offset))?;
    Ok(PlaylistDetailDto {
        summary: map::playlist_summary(d.summary),
        tracks: d.tracks.iter().map(track_to_dto).collect(),
    })
}

/// Реальные треки плейлиста (summary часто отдаёт `tracks:null`).
pub fn playlist_tracks(urn: String, limit: u32, offset: u32) -> Result<TrackPageDto, BridgeError> {
    let b = bridge()?;
    let page = b.rt.block_on(b.core.playlist_tracks(&Urn::new(urn), limit, offset))?;
    Ok(map::track_page(page))
}

// --- библиотека / профиль ---

pub fn me() -> Result<MeDto, BridgeError> {
    let b = bridge()?;
    Ok(map_misc::me(b.rt.block_on(b.core.me())?))
}

pub fn me_subscription() -> Result<bool, BridgeError> {
    let b = bridge()?;
    Ok(b.rt.block_on(b.core.me_subscription())?)
}

pub fn library_likes_tracks(limit: u32, offset: u32) -> Result<TrackPageDto, BridgeError> {
    let b = bridge()?;
    let page = b.rt.block_on(b.core.library_likes_tracks(limit, offset))?;
    Ok(map::track_page(page))
}

pub fn library_likes_playlists(
    limit: u32,
    offset: u32,
) -> Result<PlaylistSummaryPageDto, BridgeError> {
    let b = bridge()?;
    let page = b.rt.block_on(b.core.library_likes_playlists(limit, offset))?;
    Ok(map::playlist_summary_page(page))
}

pub fn library_playlists(limit: u32, offset: u32) -> Result<PlaylistSummaryPageDto, BridgeError> {
    let b = bridge()?;
    let page = b.rt.block_on(b.core.library_playlists(limit, offset))?;
    Ok(map::playlist_summary_page(page))
}

pub fn history(limit: u32, offset: u32) -> Result<HistoryPageDto, BridgeError> {
    let b = bridge()?;
    Ok(map_misc::history_page(b.rt.block_on(b.core.history(limit, offset))?))
}

// --- редакторское / лирика ---

pub fn featured() -> Result<FeaturedDto, BridgeError> {
    let b = bridge()?;
    Ok(map_misc::featured(b.rt.block_on(b.core.featured())?))
}

pub fn lyrics(sc_track_id: String) -> Result<Option<LyricsDto>, BridgeError> {
    let b = bridge()?;
    let lyrics = b.rt.block_on(b.core.lyrics(&sc_track_id))?;
    Ok(lyrics.map(map_misc::lyrics))
}

// --- авторизация ---

pub fn auth_status() -> Result<AuthStatusDto, BridgeError> {
    let b = bridge()?;
    Ok(map_misc::auth_status(b.rt.block_on(b.core.auth_status())))
}

pub fn auth_start_login() -> Result<LoginStartDto, BridgeError> {
    let b = bridge()?;
    Ok(map_misc::login_start(b.rt.block_on(b.core.start_login())?))
}

pub fn auth_poll_login(login_request_id: String) -> Result<LoginStatusDto, BridgeError> {
    let b = bridge()?;
    let status = b.rt.block_on(b.core.poll_login(&login_request_id))?;
    Ok(map_misc::login_status(status))
}

pub fn auth_logout() -> Result<(), BridgeError> {
    let b = bridge()?;
    b.rt.block_on(b.core.logout())?;
    Ok(())
}

// --- QR-перенос сессии ---

pub fn auth_link_create(mode: String) -> Result<LinkCreateDto, BridgeError> {
    let b = bridge()?;
    Ok(map_misc::link_create(b.rt.block_on(b.core.auth_link_create(&mode))?))
}

pub fn auth_link_status(link_request_id: String) -> Result<LinkStatusDto, BridgeError> {
    let b = bridge()?;
    Ok(map_misc::link_status(b.rt.block_on(b.core.auth_link_status(&link_request_id))?))
}

pub fn auth_link_claim(payload: String) -> Result<LinkClaimDto, BridgeError> {
    let b = bridge()?;
    Ok(map_misc::link_claim(b.rt.block_on(b.core.auth_link_claim(&payload))?))
}
