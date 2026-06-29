use sc_domain::{Featured, HistoryPage, Lyrics};

use crate::client::BffClient;
use crate::dto::featured::FeaturedDto;
use crate::dto::misc::{HistoryPageDto, LyricsDto};
use crate::error::BffError;

impl BffClient {
    pub async fn history(&self, limit: u32, offset: u32) -> Result<HistoryPage, BffError> {
        let path = format!("/history?limit={limit}&offset={offset}");
        let dto: HistoryPageDto = self.get_json(&path).await?;
        Ok(dto.into_domain())
    }

    pub async fn featured(&self) -> Result<Featured, BffError> {
        let dto: FeaturedDto = self.get_json("/featured").await?;
        Ok(dto.into_domain())
    }

    /// Лирика трека (`/lyrics/{sc_track_id}`). `Ok(None)` если нет (404/410).
    pub async fn lyrics(&self, sc_track_id: &str) -> Result<Option<Lyrics>, BffError> {
        let path = format!("/lyrics/{}", crate::client::enc(sc_track_id));
        let dto: Option<LyricsDto> = self.get_optional(&path).await?;
        Ok(dto.map(LyricsDto::into_domain))
    }
}
