//! FRB-поверхность: DTO, ошибки, вызовы и потоки поверх [`ScRuntime`].
//!
//! Рантайм владеет собственным tokio-Runtime (не зависим от async-рантайма FRB):
//! FRB зовёт эти функции на worker-пуле, внутри — `block_on`/`spawn` на нашем
//! рантайме. Один экземпляр на процесс (RustLib.init нельзя звать дважды).

use std::sync::OnceLock;

use crate::frb_generated::StreamSink;

use sc_core::{
    CoreEvent, DownloadProgress, HostStatus, LikesProgress, ScConfig, ScRuntime, Verdict,
};
use sc_domain::{Track, Urn};

#[derive(Debug, thiserror::Error)]
pub enum BridgeError {
    #[error("runtime not initialized")]
    NotInitialized,
    #[error("init: {0}")]
    Init(String),
    #[error("{0}")]
    Core(String),
}

impl From<sc_core::CoreError> for BridgeError {
    fn from(error: sc_core::CoreError) -> Self {
        BridgeError::Core(error.to_string())
    }
}

#[derive(Clone, Debug)]
pub struct TrackDto {
    pub urn: String,
    pub title: String,
    pub artist_name: String,
    pub artist_id: String,
    pub artist_avatar_url: Option<String>,
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
    // Загрузчик (отличается от display-артиста при enrichment).
    pub uploader_id: Option<String>,
    pub uploader_username: Option<String>,
    pub uploader_permalink_url: Option<String>,
    pub uploader_avatar_url: Option<String>,
    pub uploader_verified: bool,
    // Бейдж-метаданные `_scd_meta`.
    pub storage_state: Option<String>,
    pub storage_quality: Option<String>,
    pub index_state: Option<String>,
    pub enrich_state: Option<String>,
    pub user_favorite: Option<bool>,
    pub is_cover: bool,
    // Liner notes (credits/теги/альбом).
    pub description: Option<String>,
    pub tags: Vec<String>,
    pub isrc: Option<String>,
    pub language: Option<String>,
    pub album: Option<TrackAlbumDto>,
    pub participants: Vec<TrackParticipantDto>,
}

#[derive(Clone, Debug)]
pub struct TrackAlbumDto {
    pub id: String,
    pub title: String,
    pub cover_url: Option<String>,
    pub year: Option<i32>,
}

#[derive(Clone, Debug)]
pub struct TrackParticipantDto {
    pub id: Option<String>,
    pub name: String,
    pub role: Option<String>,
}

#[derive(Clone, Debug)]
pub enum PlaybackEventDto {
    Ended,
    TrackChanged { urn: String },
}

/// Прогресс скачки трека для индикатора в NowBar: `urn` — какой трек, `fraction`
/// — доля 0..1 (только фаза скачивания; транскод процента не даёт).
#[derive(Clone, Debug)]
pub struct DownloadProgressDto {
    pub urn: String,
    pub fraction: f64,
}

/// Прогресс bulk-кэша лайков для индикатора в настройках.
#[derive(Clone, Debug)]
pub struct LikesProgressDto {
    pub done: u32,
    pub failed: u32,
    pub total: u32,
    pub finished: bool,
}

/// Выходное аудиоустройство для пикера в настройках. `name` — идентификатор для
/// переключения, `description` — человекочитаемое имя в UI.
#[derive(Clone, Debug)]
pub struct AudioDeviceDto {
    pub name: String,
    pub description: String,
    pub is_default: bool,
}

pub(crate) struct Bridge {
    pub(crate) rt: tokio::runtime::Runtime,
    pub(crate) core: ScRuntime,
}

static BRIDGE: OnceLock<Bridge> = OnceLock::new();

pub(crate) fn bridge() -> Result<&'static Bridge, BridgeError> {
    BRIDGE.get().ok_or(BridgeError::NotInitialized)
}

/// Поднять ядро. Идемпотентно. Зовётся один раз после `RustLib.init()`.
/// [`dpi_bypass`] — включить пробив DPI как fallback (TLS-фрагментация).
pub fn init_runtime(
    data_dir: String,
    cache_dir: String,
    dpi_bypass: bool,
) -> Result<(), BridgeError> {
    if BRIDGE.get().is_some() {
        return Ok(());
    }
    let rt = tokio::runtime::Runtime::new().map_err(|e| BridgeError::Init(e.to_string()))?;
    let config = ScConfig::new(data_dir, cache_dir).with_dpi_bypass(dpi_bypass);
    let core = rt.block_on(ScRuntime::new(config))?;
    let _ = BRIDGE.set(Bridge { rt, core });
    Ok(())
}

pub fn search(query: String, limit: u32, offset: u32) -> Result<Vec<TrackDto>, BridgeError> {
    let bridge = bridge()?;
    let tracks = bridge.rt.block_on(bridge.core.search(&query, limit, offset))?;
    Ok(tracks.iter().map(track_to_dto).collect())
}

pub fn resolve_track(urn: String) -> Result<Option<TrackDto>, BridgeError> {
    let bridge = bridge()?;
    let track = bridge.rt.block_on(bridge.core.resolve(&Urn::new(urn)))?;
    Ok(track.as_ref().map(track_to_dto))
}

pub fn play_track(urn: String) -> Result<(), BridgeError> {
    let bridge = bridge()?;
    bridge.rt.block_on(bridge.core.play_track(&Urn::new(urn)))?;
    Ok(())
}

pub fn pause() -> Result<(), BridgeError> {
    bridge()?.core.pause();
    Ok(())
}

pub fn resume() -> Result<(), BridgeError> {
    bridge()?.core.resume();
    Ok(())
}

pub fn stop() -> Result<(), BridgeError> {
    bridge()?.core.stop();
    Ok(())
}

pub fn seek(position_secs: f64) -> Result<(), BridgeError> {
    bridge()?.core.seek(position_secs)?;
    Ok(())
}

pub fn set_volume(volume: f64) -> Result<(), BridgeError> {
    bridge()?.core.set_volume(volume);
    Ok(())
}

pub fn set_speed(speed: f64) -> Result<(), BridgeError> {
    bridge()?.core.set_speed(speed);
    Ok(())
}

pub fn set_eq(enabled: bool, gains: Vec<f64>) -> Result<(), BridgeError> {
    bridge()?.core.set_eq(enabled, &gains);
    Ok(())
}

/// Hover-превью трека: дожать кэш и проиграть сэмпл на отдельном плеере. Окно/
/// гейт/дебаунс — на стороне UI (как легаси `audioPreview`).
pub fn audio_preview_play(urn: String, volume: f64) -> Result<(), BridgeError> {
    let b = bridge()?;
    b.rt.block_on(b.core.preview_play(&Urn::new(urn), volume))?;
    Ok(())
}

/// Снять hover-превью с фейдом (мс). `preview_stop` спавнит фейд-задачу — входим
/// в рантайм (FRB зовёт вне него).
pub fn audio_preview_stop(fade_ms: u64) -> Result<(), BridgeError> {
    let b = bridge()?;
    let _guard = b.rt.enter();
    b.core.preview_stop(fade_ms);
    Ok(())
}

pub fn set_ab_loop(a: Option<f64>, b: Option<f64>) -> Result<(), BridgeError> {
    bridge()?.core.set_ab_loop(a, b);
    Ok(())
}

/// Доступные выходные аудиоустройства (для пикера в настройках).
pub fn audio_output_devices() -> Result<Vec<AudioDeviceDto>, BridgeError> {
    Ok(bridge()?
        .core
        .audio_output_devices()
        .into_iter()
        .map(|d| AudioDeviceDto {
            name: d.name,
            description: d.description,
            is_default: d.is_default,
        })
        .collect())
}

/// Переключить аудиовыход (`None` — системный по умолчанию). Текущий трек
/// переезжает на новое устройство с сохранением позиции.
pub fn set_audio_output(name: Option<String>) -> Result<(), BridgeError> {
    bridge()?.core.set_audio_output(name)?;
    Ok(())
}

pub fn position_secs() -> Result<f64, BridgeError> {
    Ok(bridge()?.core.position_secs())
}

pub fn is_playing() -> Result<bool, BridgeError> {
    Ok(bridge()?.core.is_playing())
}

pub fn set_session(token: Option<String>) -> Result<(), BridgeError> {
    bridge()?.core.set_session(token)?;
    Ok(())
}

/// Позиция воспроизведения (latest-wins).
pub fn position_stream(sink: StreamSink<f64>) -> Result<(), BridgeError> {
    let bridge = bridge()?;
    let mut rx = bridge.core.position_watch();
    bridge.rt.spawn(async move {
        while rx.changed().await.is_ok() {
            let value = *rx.borrow_and_update();
            let _ = sink.add(value);
        }
    });
    Ok(())
}

/// Критические события (Ended/TrackChanged).
pub fn playback_events(sink: StreamSink<PlaybackEventDto>) -> Result<(), BridgeError> {
    let bridge = bridge()?;
    let mut rx = bridge.core.events();
    bridge.rt.spawn(async move {
        loop {
            match rx.recv().await {
                Ok(event) => {
                    let _ = sink.add(event_to_dto(event));
                }
                Err(tokio::sync::broadcast::error::RecvError::Lagged(_)) => continue,
                Err(tokio::sync::broadcast::error::RecvError::Closed) => break,
            }
        }
    });
    Ok(())
}

/// Статус бэкенд-хостов для UI-модалок failover.
#[derive(Clone, Debug)]
pub struct HostStatusDto {
    /// Вердикт основного хоста: `"up"` | `"down"` | `"unknown"`.
    pub main: String,
    /// Вердикт STAR-резерва.
    pub star: String,
    /// Активна ли подписка (открывает STAR).
    pub premium: bool,
}

/// Статус бэкенд-хостов для UI: вердикты main/star ("up"|"down"|"unknown") +
/// premium. Отдаёт текущее значение сразу, далее — при каждом изменении. На этом
/// фронт строит модалки failover (резерв STAR / купи STAR / всё лежит).
pub fn host_status_stream(sink: StreamSink<HostStatusDto>) -> Result<(), BridgeError> {
    let bridge = bridge()?;
    let mut rx = bridge.core.host_status_watch();
    let _ = sink.add(host_status_to_dto(*rx.borrow()));
    bridge.rt.spawn(async move {
        while rx.changed().await.is_ok() {
            let value = *rx.borrow_and_update();
            if sink.add(host_status_to_dto(value)).is_err() {
                break;
            }
        }
    });
    Ok(())
}

/// Внеочередная перепроверка хостов (кнопка «Проверить снова» в модалке failover).
pub fn host_recheck() -> Result<(), BridgeError> {
    bridge()?.core.request_host_recheck();
    Ok(())
}

/// Прогресс скачки текущего трека (доля 0..1) для индикатора в NowBar.
pub fn download_progress(sink: StreamSink<DownloadProgressDto>) -> Result<(), BridgeError> {
    let bridge = bridge()?;
    let mut rx = bridge.core.download_progress();
    bridge.rt.spawn(async move {
        loop {
            match rx.recv().await {
                Ok(progress) => {
                    if sink.add(progress_to_dto(progress)).is_err() {
                        break;
                    }
                }
                Err(tokio::sync::broadcast::error::RecvError::Lagged(_)) => continue,
                Err(tokio::sync::broadcast::error::RecvError::Closed) => break,
            }
        }
    });
    Ok(())
}

/// Прогресс bulk-кэша лайков ({done,failed,total,finished}) для настроек.
pub fn likes_progress(sink: StreamSink<LikesProgressDto>) -> Result<(), BridgeError> {
    let bridge = bridge()?;
    let mut rx = bridge.core.likes_progress();
    bridge.rt.spawn(async move {
        loop {
            match rx.recv().await {
                Ok(progress) => {
                    if sink.add(likes_progress_to_dto(progress)).is_err() {
                        break;
                    }
                }
                Err(tokio::sync::broadcast::error::RecvError::Lagged(_)) => continue,
                Err(tokio::sync::broadcast::error::RecvError::Closed) => break,
            }
        }
    });
    Ok(())
}

/// Поток лог-полос спектра (`Vec<f32>`, 64 полосы, ~30 Гц) для визуализатора.
/// FFT считается в ядре только пока есть подписчик — иначе CPU-idle.
pub fn audio_spectrum(sink: StreamSink<Vec<f32>>) -> Result<(), BridgeError> {
    let bridge = bridge()?;
    let mut rx = bridge.core.spectrum();
    bridge.rt.spawn(async move {
        loop {
            match rx.recv().await {
                Ok(bins) => {
                    if sink.add(bins).is_err() {
                        break;
                    }
                }
                Err(tokio::sync::broadcast::error::RecvError::Lagged(_)) => continue,
                Err(tokio::sync::broadcast::error::RecvError::Closed) => break,
            }
        }
    });
    Ok(())
}

pub(crate) fn track_to_dto(track: &Track) -> TrackDto {
    let uploader = track.uploader.as_ref();
    TrackDto {
        urn: track.id.as_str().to_owned(),
        title: track.title.clone(),
        artist_name: track.artist.name.clone(),
        artist_id: track.artist.id.as_str().to_owned(),
        artist_avatar_url: track.artist.avatar_url.clone(),
        duration_ms: track.duration_ms,
        artwork_url: track.artwork_url.clone(),
        waveform_url: track.waveform_url.clone(),
        genre: track.genre.clone(),
        play_count: track.play_count,
        likes_count: track.likes_count,
        reposts_count: track.reposts_count,
        permalink_url: track.permalink_url.clone(),
        created_at: track.created_at.clone(),
        release_year: track.release_year,
        uploader_id: uploader.map(|u| u.id.as_str().to_owned()),
        uploader_username: uploader.map(|u| u.username.clone()),
        uploader_permalink_url: uploader.and_then(|u| u.permalink_url.clone()),
        uploader_avatar_url: uploader.and_then(|u| u.avatar_url.clone()),
        uploader_verified: uploader.is_some_and(|u| u.verified),
        storage_state: track.badge.storage_state.clone(),
        storage_quality: track.badge.storage_quality.clone(),
        index_state: track.badge.index_state.clone(),
        enrich_state: track.badge.enrich_state.clone(),
        user_favorite: track.user_favorite,
        is_cover: track.is_cover,
        description: track.description.clone(),
        tags: track.tags.clone(),
        isrc: track.isrc.clone(),
        language: track.language.clone(),
        album: track.album.as_ref().map(|a| TrackAlbumDto {
            id: a.id.clone(),
            title: a.title.clone(),
            cover_url: a.cover_url.clone(),
            year: a.year,
        }),
        participants: track
            .participants
            .iter()
            .map(|p| TrackParticipantDto {
                id: p.id.clone(),
                name: p.name.clone(),
                role: p.role.clone(),
            })
            .collect(),
    }
}

fn event_to_dto(event: CoreEvent) -> PlaybackEventDto {
    match event {
        CoreEvent::TrackEnded => PlaybackEventDto::Ended,
        CoreEvent::TrackChanged { urn } => PlaybackEventDto::TrackChanged { urn },
    }
}

fn progress_to_dto(progress: DownloadProgress) -> DownloadProgressDto {
    DownloadProgressDto {
        urn: progress.urn,
        fraction: progress.fraction,
    }
}

fn host_status_to_dto(status: HostStatus) -> HostStatusDto {
    HostStatusDto {
        main: verdict_str(status.main),
        star: verdict_str(status.star),
        premium: status.premium,
    }
}

fn verdict_str(verdict: Verdict) -> String {
    match verdict {
        Verdict::Up => "up",
        Verdict::Down => "down",
        Verdict::Unknown => "unknown",
    }
    .to_owned()
}

fn likes_progress_to_dto(progress: LikesProgress) -> LikesProgressDto {
    LikesProgressDto {
        done: progress.done as u32,
        failed: progress.failed as u32,
        total: progress.total as u32,
        finished: progress.finished,
    }
}
