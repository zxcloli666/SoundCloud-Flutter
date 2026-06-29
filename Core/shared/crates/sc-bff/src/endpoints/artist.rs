use sc_domain::{AlbumRef, ArtistDetail, ArtistStar, ListPage, Track};

use crate::client::{BffClient, offset_to_page};
use crate::dto::album::AlbumRefDto;
use crate::dto::artist::ArtistDetailDto;
use crate::dto::envelope::ListEnvelope;
use crate::dto::star::ArtistStarDto;
use crate::dto::track::TrackDto;
use crate::error::BffError;

impl BffClient {
    pub async fn artist_detail(&self, id: &str) -> Result<ArtistDetail, BffError> {
        let path = format!("/artists/{id}");
        let dto: ArtistDetailDto = self.get_json(&path).await?;
        Ok(dto.into_domain())
    }

    /// Треки артиста. `role`: `"primary"` — свои, `"featured"` — участия
    /// («появляется в», вкладка appears). Бэкенд постранично через `page`.
    pub async fn artist_tracks(
        &self,
        id: &str,
        role: &str,
        limit: u32,
        offset: u32,
    ) -> Result<ListPage<Track>, BffError> {
        let path = format!(
            "/artists/{id}/tracks?role={role}&limit={limit}&page={}",
            offset_to_page(offset, limit)
        );
        let env: ListEnvelope<TrackDto> = self.get_json(&path).await?;
        Ok(env.into_page(TrackDto::into_domain))
    }

    /// Список альбомов артиста (`/artists/{id}/albums`) — бэкенд отдаёт всё
    /// разом, без пагинации, поэтому limit/offset тут не нужны.
    pub async fn artist_albums(&self, id: &str) -> Result<Vec<AlbumRef>, BffError> {
        let path = format!("/artists/{id}/albums");
        let dtos: Vec<AlbumRefDto> = self.get_json(&path).await?;
        Ok(dtos.into_iter().map(AlbumRefDto::into_domain).collect())
    }

    /// Кавера на оригиналы этого артиста (`/artists/{id}/covers`). Бэкенд
    /// постранично через `page` — конвертируем `offset` в страницу.
    pub async fn artist_covers(
        &self,
        id: &str,
        limit: u32,
        offset: u32,
    ) -> Result<ListPage<Track>, BffError> {
        let page = offset_to_page(offset, limit);
        let path = format!("/artists/{id}/covers?limit={limit}&page={page}");
        let env: ListEnvelope<TrackDto> = self.get_json(&path).await?;
        Ok(env.into_page(TrackDto::into_domain))
    }

    /// Звёздный/премиум-флаг артиста + аура (`/artists/{id}/star`).
    pub async fn artist_star(&self, id: &str) -> Result<ArtistStar, BffError> {
        let path = format!("/artists/{id}/star");
        let dto: ArtistStarDto = self.get_json(&path).await?;
        Ok(dto.into_domain())
    }
}
