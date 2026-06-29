use sc_domain::AlbumDetail;

use crate::client::BffClient;
use crate::dto::album::AlbumDetailDto;
use crate::error::BffError;

impl BffClient {
    pub async fn album_detail(&self, id: &str) -> Result<AlbumDetail, BffError> {
        let path = format!("/albums/{id}");
        let dto: AlbumDetailDto = self.get_json(&path).await?;
        Ok(dto.into_domain())
    }
}
