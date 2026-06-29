use sc_domain::{Comment, ListPage, Track, TrackStreams, Urn, User};

use crate::client::{BffClient, offset_to_page};
use crate::dto::comment::{CommentDto, CommentInput, PostCommentBody};
use crate::dto::envelope::ListEnvelope;
use crate::dto::misc::TrackStreamsDto;
use crate::dto::star::WaveformDto;
use crate::dto::track::TrackDto;
use crate::dto::user::UserProfileDto;
use crate::error::BffError;

impl BffClient {
    /// Резолв трека. `Ok(None)` при 404/410.
    pub async fn resolve_track(&self, urn: &Urn) -> Result<Option<Track>, BffError> {
        let path = format!("/tracks/{}", urn);
        let dto: Option<TrackDto> = self.get_optional(&path).await?;
        Ok(dto.map(TrackDto::into_domain))
    }

    pub async fn track_related(&self, urn: &Urn, limit: u32) -> Result<ListPage<Track>, BffError> {
        let path = format!("/tracks/{urn}/related?limit={limit}");
        let env: ListEnvelope<TrackDto> = self.get_json(&path).await?;
        Ok(env.into_page(TrackDto::into_domain))
    }

    pub async fn track_streams(&self, urn: &Urn) -> Result<TrackStreams, BffError> {
        let path = format!("/tracks/{urn}/streams");
        let dto: TrackStreamsDto = self.get_json(&path).await?;
        Ok(dto.into_domain())
    }

    /// Кто лайкнул трек (`/tracks/{urn}/favoriters`). Бэкенд через `page`.
    pub async fn track_favoriters(&self, urn: &Urn, limit: u32) -> Result<ListPage<User>, BffError> {
        let path = format!("/tracks/{urn}/favoriters?limit={limit}");
        let env: ListEnvelope<UserProfileDto> = self.get_json(&path).await?;
        Ok(env.into_page(UserProfileDto::into_domain))
    }

    /// Комментарии трека (`GET /tracks/{urn}/comments`, постранично через `page`).
    pub async fn track_comments(
        &self,
        urn: &Urn,
        limit: u32,
        offset: u32,
    ) -> Result<ListPage<Comment>, BffError> {
        let path = format!(
            "/tracks/{urn}/comments?limit={limit}&page={}",
            offset_to_page(offset, limit)
        );
        let env: ListEnvelope<CommentDto> = self.get_json(&path).await?;
        Ok(env.into_page(CommentDto::into_domain))
    }

    /// Оставить комментарий (`POST /tracks/{urn}/comments`). `timestamp_ms` —
    /// привязка к моменту трека (`None` → 0, без таймкода).
    pub async fn post_comment(
        &self,
        urn: &Urn,
        body: &str,
        timestamp_ms: Option<i64>,
    ) -> Result<Comment, BffError> {
        let path = format!("/tracks/{urn}/comments");
        let payload = PostCommentBody {
            comment: CommentInput {
                body,
                timestamp: timestamp_ms.unwrap_or(0),
            },
        };
        let dto: CommentDto = self.post_json(&path, &payload).await?;
        Ok(dto.into_domain())
    }

    /// Кто репостнул трек (`/tracks/{urn}/reposters`).
    pub async fn track_reposters(&self, urn: &Urn, limit: u32) -> Result<ListPage<User>, BffError> {
        let path = format!("/tracks/{urn}/reposters?limit={limit}");
        let env: ListEnvelope<UserProfileDto> = self.get_json(&path).await?;
        Ok(env.into_page(UserProfileDto::into_domain))
    }

    /// Внешний waveform-JSON (`wave.sndcdn.com/*.json`) → нормированные 0..1.
    pub async fn track_waveform(&self, waveform_url: &str) -> Result<Vec<f32>, BffError> {
        let bytes = self.get_external_bytes(waveform_url).await?;
        let dto: WaveformDto =
            serde_json::from_slice(&bytes).map_err(|e| BffError::Decode(e.to_string()))?;
        Ok(dto.into_normalized())
    }
}
