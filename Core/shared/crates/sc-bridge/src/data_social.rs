//! FRB-функции третьей волны: vibe/lyrics-поиск, кавера/звезда артиста, реко-
//! кластеры, профили пользователей, подписки/лайки/дизлайки, аура, waveform,
//! resolve, очистка истории. Зеркалит стиль [`crate::data`].

use sc_domain::Urn;

use crate::api::{BridgeError, TrackDto, bridge, track_to_dto};
use crate::dto::{
    ClusterDto, CommentDto, CommentPageDto, PlaylistSummaryDto, PlaylistSummaryPageDto,
    TrackPageDto, UserDto, UserPageDto,
};
use crate::dto_social::{
    ArtistStarDto, AuraDto, CacheEntryDto, LyricHitPageDto, VibePageDto, WallpaperPageDto,
    WallpaperQueryDto, WebProfileDto,
};
use crate::{map, map_misc};

// --- vibe / lyrics ---

pub fn search_vibe(query: String, limit: u32) -> Result<VibePageDto, BridgeError> {
    let b = bridge()?;
    let result = b.rt.block_on(b.core.search_vibe(&query, limit))?;
    Ok(VibePageDto {
        items: result.tracks.iter().map(track_to_dto).collect(),
        preparing: result.preparing,
    })
}

/// Живой поиск треков прямо в SoundCloud (источник «SC»).
pub fn search_sc_tracks(query: String, limit: u32) -> Result<Vec<TrackDto>, BridgeError> {
    let b = bridge()?;
    let tracks = b.rt.block_on(b.core.search_sc_tracks(&query, limit))?;
    Ok(tracks.iter().map(track_to_dto).collect())
}

pub fn search_lyrics(query: String, limit: u32) -> Result<LyricHitPageDto, BridgeError> {
    let b = bridge()?;
    let page = b.rt.block_on(b.core.search_lyrics(&query, limit))?;
    Ok(map_misc::lyric_hit_page(page))
}

// --- артист: кавера / звезда / реко ---

pub fn artist_covers(id: String, limit: u32, offset: u32) -> Result<TrackPageDto, BridgeError> {
    let b = bridge()?;
    let page = b.rt.block_on(b.core.artist_covers(&id, limit, offset))?;
    Ok(map::track_page(page))
}

pub fn artist_star(id: String) -> Result<ArtistStarDto, BridgeError> {
    let b = bridge()?;
    Ok(map_misc::artist_star(b.rt.block_on(b.core.artist_star(&id))?))
}

pub fn recommendations_similar(track_id: String, limit: u32) -> Result<Vec<ClusterDto>, BridgeError> {
    let b = bridge()?;
    let clusters = b.rt.block_on(b.core.recommendations_similar(&track_id, limit))?;
    Ok(clusters.into_iter().map(map_misc::cluster).collect())
}

pub fn recommendations_artist(artist_id: String, limit: u32) -> Result<Vec<ClusterDto>, BridgeError> {
    let b = bridge()?;
    let clusters = b.rt.block_on(b.core.recommendations_artist(&artist_id, limit))?;
    Ok(clusters.into_iter().map(map_misc::cluster).collect())
}

// --- пользователь по URN ---

pub fn user(urn: String) -> Result<Option<UserDto>, BridgeError> {
    let b = bridge()?;
    let user = b.rt.block_on(b.core.user(&Urn::new(urn)))?;
    Ok(user.map(map_misc::user))
}

pub fn user_tracks(urn: String, limit: u32, offset: u32) -> Result<TrackPageDto, BridgeError> {
    let b = bridge()?;
    let page = b.rt.block_on(b.core.user_tracks(&Urn::new(urn), limit, offset))?;
    Ok(map::track_page(page))
}

pub fn user_playlists(
    urn: String,
    limit: u32,
    offset: u32,
) -> Result<PlaylistSummaryPageDto, BridgeError> {
    let b = bridge()?;
    let page = b.rt.block_on(b.core.user_playlists(&Urn::new(urn), limit, offset))?;
    Ok(map::playlist_summary_page(page))
}

pub fn user_liked_tracks(urn: String, limit: u32, offset: u32) -> Result<TrackPageDto, BridgeError> {
    let b = bridge()?;
    let page = b.rt.block_on(b.core.user_liked_tracks(&Urn::new(urn), limit, offset))?;
    Ok(map::track_page(page))
}

pub fn user_followers(urn: String, limit: u32, offset: u32) -> Result<UserPageDto, BridgeError> {
    let b = bridge()?;
    let page = b.rt.block_on(b.core.user_followers(&Urn::new(urn), limit, offset))?;
    Ok(map_misc::user_page(page))
}

pub fn user_followings(urn: String, limit: u32, offset: u32) -> Result<UserPageDto, BridgeError> {
    let b = bridge()?;
    let page = b.rt.block_on(b.core.user_followings(&Urn::new(urn), limit, offset))?;
    Ok(map_misc::user_page(page))
}

pub fn user_web_profiles(urn: String) -> Result<Vec<WebProfileDto>, BridgeError> {
    let b = bridge()?;
    let items = b.rt.block_on(b.core.user_web_profiles(&Urn::new(urn)))?;
    Ok(items.into_iter().map(map_misc::web_profile).collect())
}

pub fn user_subscription(urn: String) -> Result<bool, BridgeError> {
    let b = bridge()?;
    Ok(b.rt.block_on(b.core.user_subscription(&Urn::new(urn)))?)
}

// --- мои подписки ---

pub fn me_followings(limit: u32, offset: u32) -> Result<UserPageDto, BridgeError> {
    let b = bridge()?;
    Ok(map_misc::user_page(b.rt.block_on(b.core.me_followings(limit, offset))?))
}

pub fn me_followings_tracks(limit: u32, offset: u32) -> Result<TrackPageDto, BridgeError> {
    let b = bridge()?;
    Ok(map::track_page(b.rt.block_on(b.core.me_followings_tracks(limit, offset))?))
}

// --- аура ---

pub fn user_aura(urn: String) -> Result<AuraDto, BridgeError> {
    let b = bridge()?;
    Ok(map_misc::aura(b.rt.block_on(b.core.user_aura(&Urn::new(urn)))?))
}

pub fn put_aura(aura_id: String, custom_hex: Option<String>) -> Result<AuraDto, BridgeError> {
    let b = bridge()?;
    let aura = b.rt.block_on(b.core.put_aura(&aura_id, custom_hex.as_deref()))?;
    Ok(map_misc::aura(aura))
}

// --- кто-вайбит / резолв / waveform ---

pub fn track_favoriters(urn: String, limit: u32) -> Result<UserPageDto, BridgeError> {
    let b = bridge()?;
    Ok(map_misc::user_page(b.rt.block_on(b.core.track_favoriters(&Urn::new(urn), limit))?))
}

/// Комментарии трека (постранично).
pub fn track_comments(urn: String, limit: u32, offset: u32) -> Result<CommentPageDto, BridgeError> {
    let b = bridge()?;
    Ok(map_misc::comment_page(
        b.rt.block_on(b.core.track_comments(&Urn::new(urn), limit, offset))?,
    ))
}

/// Оставить комментарий (`timestampMs` — таймкод в треке, `null` — без привязки).
pub fn post_comment(
    urn: String,
    body: String,
    timestamp_ms: Option<i64>,
) -> Result<CommentDto, BridgeError> {
    let b = bridge()?;
    Ok(map_misc::comment(
        b.rt.block_on(b.core.post_comment(&Urn::new(urn), &body, timestamp_ms))?,
    ))
}

pub fn track_reposters(urn: String, limit: u32) -> Result<UserPageDto, BridgeError> {
    let b = bridge()?;
    Ok(map_misc::user_page(b.rt.block_on(b.core.track_reposters(&Urn::new(urn), limit))?))
}

pub fn resolve_url(url: String) -> Result<Option<crate::api::TrackDto>, BridgeError> {
    let b = bridge()?;
    let track = b.rt.block_on(b.core.resolve_url(&url))?;
    Ok(track.as_ref().map(crate::api::track_to_dto))
}

pub fn track_waveform(waveform_url: String) -> Result<Vec<f32>, BridgeError> {
    let b = bridge()?;
    Ok(b.rt.block_on(b.core.track_waveform(&waveform_url))?)
}

// --- мьютации ---

pub fn like_track(track_urn: String) -> Result<(), BridgeError> {
    let b = bridge()?;
    b.rt.block_on(b.core.like_track(&Urn::new(track_urn)))?;
    Ok(())
}

pub fn unlike_track(track_urn: String) -> Result<(), BridgeError> {
    let b = bridge()?;
    b.rt.block_on(b.core.unlike_track(&Urn::new(track_urn)))?;
    Ok(())
}

pub fn like_playlist(playlist_urn: String) -> Result<(), BridgeError> {
    let b = bridge()?;
    b.rt.block_on(b.core.like_playlist(&Urn::new(playlist_urn)))?;
    Ok(())
}

pub fn unlike_playlist(playlist_urn: String) -> Result<(), BridgeError> {
    let b = bridge()?;
    b.rt.block_on(b.core.unlike_playlist(&Urn::new(playlist_urn)))?;
    Ok(())
}

pub fn follow_user(user_urn: String) -> Result<(), BridgeError> {
    let b = bridge()?;
    b.rt.block_on(b.core.follow_user(&Urn::new(user_urn)))?;
    Ok(())
}

pub fn unfollow_user(user_urn: String) -> Result<(), BridgeError> {
    let b = bridge()?;
    b.rt.block_on(b.core.unfollow_user(&Urn::new(user_urn)))?;
    Ok(())
}

pub fn dislike_track(sc_track_id: String) -> Result<(), BridgeError> {
    let b = bridge()?;
    b.rt.block_on(b.core.dislike_track(&sc_track_id))?;
    Ok(())
}

pub fn undislike_track(sc_track_id: String) -> Result<(), BridgeError> {
    let b = bridge()?;
    b.rt.block_on(b.core.undislike_track(&sc_track_id))?;
    Ok(())
}

pub fn dislike_status(sc_track_id: String) -> Result<bool, BridgeError> {
    let b = bridge()?;
    Ok(b.rt.block_on(b.core.dislike_status(&sc_track_id))?)
}

pub fn dislike_ids() -> Result<Vec<String>, BridgeError> {
    let b = bridge()?;
    Ok(b.rt.block_on(b.core.dislike_ids())?)
}

pub fn clear_history() -> Result<(), BridgeError> {
    let b = bridge()?;
    b.rt.block_on(b.core.clear_history())?;
    Ok(())
}

// --- обои (анонимно, через наш транспорт) ---

pub fn wallpaper_search(query: WallpaperQueryDto) -> Result<WallpaperPageDto, BridgeError> {
    let b = bridge()?;
    let q = sc_core::WallpaperQuery {
        source: query.source,
        query: query.query,
        category: query.category,
        color: query.color,
        cursor: query.cursor,
        adult: query.adult,
        api_key: query.api_key,
    };
    Ok(map_misc::wallpaper_page(b.rt.block_on(b.core.wallpaper_search(q))?))
}

/// Скачать обоину по URL в локальное хранилище — абсолютный путь файла.
pub fn wallpaper_download(url: String) -> Result<String, BridgeError> {
    let b = bridge()?;
    Ok(b.rt.block_on(b.core.wallpaper_download(&url))?)
}

/// Импортировать локальный файл (file-picker) в хранилище обоев.
pub fn wallpaper_import(src_path: String) -> Result<String, BridgeError> {
    let b = bridge()?;
    Ok(b.rt.block_on(b.core.wallpaper_import(&src_path))?)
}

/// Абсолютные пути всех сохранённых обоев.
pub fn wallpaper_list() -> Result<Vec<String>, BridgeError> {
    let b = bridge()?;
    Ok(b.rt.block_on(b.core.wallpaper_list()))
}

/// Удалить обоину по абсолютному пути.
pub fn wallpaper_remove(path: String) -> Result<(), BridgeError> {
    let b = bridge()?;
    b.rt.block_on(b.core.wallpaper_remove(&path))?;
    Ok(())
}

// --- батч-резолв ---

pub fn resolve_tracks(urns: Vec<String>) -> Result<Vec<TrackDto>, BridgeError> {
    let b = bridge()?;
    let tracks = b.rt.block_on(b.core.resolve_tracks(&urns))?;
    Ok(tracks.iter().map(track_to_dto).collect())
}

// --- мьютации плейлистов ---

pub fn playlist_add_track(
    playlist_urn: String,
    track_urn: String,
) -> Result<TrackPageDto, BridgeError> {
    let b = bridge()?;
    let page =
        b.rt.block_on(b.core.playlist_add_track(&Urn::new(playlist_urn), &Urn::new(track_urn)))?;
    Ok(map::track_page(page))
}

pub fn playlist_remove_track(
    playlist_urn: String,
    track_urn: String,
) -> Result<TrackPageDto, BridgeError> {
    let b = bridge()?;
    let page = b
        .rt
        .block_on(b.core.playlist_remove_track(&Urn::new(playlist_urn), &Urn::new(track_urn)))?;
    Ok(map::track_page(page))
}

pub fn playlist_reorder(
    playlist_urn: String,
    track_urns: Vec<String>,
) -> Result<TrackPageDto, BridgeError> {
    let b = bridge()?;
    let page = b.rt.block_on(b.core.playlist_reorder(&Urn::new(playlist_urn), &track_urns))?;
    Ok(map::track_page(page))
}

pub fn create_playlist(
    title: String,
    track_urns: Vec<String>,
) -> Result<PlaylistSummaryDto, BridgeError> {
    let b = bridge()?;
    let summary = b.rt.block_on(b.core.create_playlist(&title, &track_urns))?;
    Ok(map::playlist_summary(summary))
}

pub fn delete_playlist(playlist_urn: String) -> Result<(), BridgeError> {
    let b = bridge()?;
    b.rt.block_on(b.core.delete_playlist(&Urn::new(playlist_urn)))?;
    Ok(())
}

// --- оффлайн-кэш ---

pub fn cache_inventory() -> Result<Vec<CacheEntryDto>, BridgeError> {
    let b = bridge()?;
    let entries = b.core.cache_inventory()?;
    Ok(entries.into_iter().map(map_misc::cache_entry).collect())
}

pub fn cache_total_bytes() -> Result<i64, BridgeError> {
    Ok(bridge()?.core.cache_total_bytes()?)
}

pub fn cache_is_cached(urn: String) -> Result<bool, BridgeError> {
    Ok(bridge()?.core.cache_is_cached(&Urn::new(urn)))
}

pub fn cache_remove(urn: String) -> Result<(), BridgeError> {
    let b = bridge()?;
    b.rt.block_on(b.core.cache_remove(&Urn::new(urn)))?;
    Ok(())
}

pub fn cache_ensure(urn: String) -> Result<(), BridgeError> {
    let b = bridge()?;
    b.rt.block_on(b.core.cache_ensure(&Urn::new(urn)))?;
    Ok(())
}

/// Экспорт трека в файл (легаси `save_track_to_path`): путь даёт платформа.
pub fn track_export(urn: String, dest_path: String) -> Result<(), BridgeError> {
    let b = bridge()?;
    b.rt
        .block_on(b.core.export_track(&Urn::new(urn), &dest_path))?;
    Ok(())
}

/// Опережающий прогрев трека в фоне (легаси `track_preload`) — кэш без игры.
/// `preload_track` делает `tokio::spawn`, поэтому входим в контекст рантайма
/// (FRB зовёт нас вне него) — иначе паника «no reactor running».
pub fn track_preload(urn: String) -> Result<(), BridgeError> {
    let b = bridge()?;
    let _guard = b.rt.enter();
    b.core.preload_track(Urn::new(urn));
    Ok(())
}

pub fn cache_liked_bytes() -> Result<i64, BridgeError> {
    Ok(bridge()?.core.cache_liked_bytes()?)
}

pub fn cache_clear() -> Result<(), BridgeError> {
    bridge()?.core.cache_clear()?;
    Ok(())
}

pub fn cache_clear_liked() -> Result<(), BridgeError> {
    bridge()?.core.cache_clear_liked()?;
    Ok(())
}

/// Применить лимит обычного аудиокэша (LRU-вытеснение). Зовётся после скачки.
pub fn cache_enforce_limit(limit_mb: u64) -> Result<(), BridgeError> {
    bridge()?.core.cache_enforce_limit(limit_mb);
    Ok(())
}

pub fn cache_likes_running() -> Result<bool, BridgeError> {
    Ok(bridge()?.core.cache_likes_running())
}

pub fn cancel_cache_likes() -> Result<(), BridgeError> {
    bridge()?.core.cancel_cache_likes();
    Ok(())
}

/// Запустить bulk-кэш лайков в защищённый кэш. Возвращается сразу — прогресс
/// идёт потоком [`crate::api::likes_progress`], завершение — событием `finished`.
pub fn cache_likes(urns: Vec<String>) -> Result<(), BridgeError> {
    let b = bridge()?;
    let core = b.core.clone();
    let urns: Vec<Urn> = urns.into_iter().map(Urn::new).collect();
    b.rt.spawn(async move {
        let _ = core.cache_likes(urns).await;
    });
    Ok(())
}
