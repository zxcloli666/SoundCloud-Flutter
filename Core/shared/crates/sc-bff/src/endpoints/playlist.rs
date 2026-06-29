use sc_domain::{ListPage, PlaylistDetail, Track, Urn};

use crate::client::{BffClient, offset_to_page};
use crate::dto::envelope::ListEnvelope;
use crate::dto::playlist::PlaylistDetailDto;
use crate::dto::track::TrackDto;
use crate::error::BffError;

impl BffClient {
    /// Сводка плейлиста (`/playlists/{urn}`). `tracks` тут часто `null` — реальные
    /// треки тянет [`Self::playlist_tracks`].
    pub async fn playlist_detail(
        &self,
        urn: &Urn,
        limit: u32,
        offset: u32,
    ) -> Result<PlaylistDetail, BffError> {
        let path = format!("/playlists/{urn}?limit={limit}&page={}", offset_to_page(offset, limit));
        let dto: PlaylistDetailDto = self.get_json(&path).await?;
        Ok(dto.into_domain())
    }

    /// Реальные треки плейлиста (`GET /playlists/{urn}/tracks` →
    /// `ListPageResult<Track>`, постранично через `page`).
    pub async fn playlist_tracks(
        &self,
        urn: &Urn,
        limit: u32,
        offset: u32,
    ) -> Result<ListPage<Track>, BffError> {
        let path =
            format!("/playlists/{urn}/tracks?limit={limit}&page={}", offset_to_page(offset, limit));
        let env: ListEnvelope<TrackDto> = self.get_json(&path).await?;
        Ok(env.into_page(TrackDto::into_domain))
    }
}
