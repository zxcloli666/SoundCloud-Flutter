use sc_domain::{
    AlbumCard, ArtistCard, ListPage, LyricHit, PlaylistSummary, Track, User, VibeResult,
};

use crate::client::{BffClient, enc, offset_to_page};
use crate::dto::album::AlbumCardDto;
use crate::dto::artist::ArtistCardDto;
use crate::dto::envelope::ListEnvelope;
use crate::dto::playlist::PlaylistSummaryDto;
use crate::dto::search::{LyricsSearchDto, VibeDto};
use crate::dto::track::TrackDto;
use crate::dto::user::UserProfileDto;
use crate::error::BffError;

impl BffClient {
    pub async fn search_tracks(
        &self,
        query: &str,
        limit: u32,
        offset: u32,
    ) -> Result<ListPage<Track>, BffError> {
        let path = format!(
            "/search/db/tracks?q={}&limit={limit}&page={}",
            enc(query),
            offset_to_page(offset, limit)
        );
        let env: ListEnvelope<TrackDto> = self.get_json(&path).await?;
        Ok(env.into_page(TrackDto::into_domain))
    }

    /// AI vibe-поиск (`/search/vibe`) — семантика по MuLan-вектору. Несёт флаг
    /// `preparing` (вектор кодируется).
    pub async fn search_vibe(&self, query: &str, limit: u32) -> Result<VibeResult, BffError> {
        let path = format!("/search/vibe?q={}&limit={limit}", enc(query));
        let dto: VibeDto = self.get_json(&path).await?;
        Ok(dto.into_result())
    }

    /// Полнотекстовый поиск по лирике (`/search/lyrics`). Хит = трек + совпавшая
    /// строка (`matchedLine`) для карточки-цитаты.
    pub async fn search_lyrics(
        &self,
        query: &str,
        limit: u32,
    ) -> Result<ListPage<LyricHit>, BffError> {
        let path = format!("/search/lyrics?q={}&limit={limit}", enc(query));
        let dto: LyricsSearchDto = self.get_json(&path).await?;
        Ok(dto.into_page())
    }

    pub async fn search_artists(
        &self,
        query: &str,
        limit: u32,
        offset: u32,
    ) -> Result<ListPage<ArtistCard>, BffError> {
        let path = format!(
            "/search/db/artists?q={}&limit={limit}&page={}",
            enc(query),
            offset_to_page(offset, limit)
        );
        let env: ListEnvelope<ArtistCardDto> = self.get_json(&path).await?;
        Ok(env.into_page(ArtistCardDto::into_domain))
    }

    pub async fn search_albums(
        &self,
        query: &str,
        limit: u32,
        offset: u32,
    ) -> Result<ListPage<AlbumCard>, BffError> {
        let path = format!(
            "/search/db/albums?q={}&limit={limit}&page={}",
            enc(query),
            offset_to_page(offset, limit)
        );
        let env: ListEnvelope<AlbumCardDto> = self.get_json(&path).await?;
        Ok(env.into_page(AlbumCardDto::into_domain))
    }

    pub async fn search_playlists(
        &self,
        query: &str,
        limit: u32,
        offset: u32,
    ) -> Result<ListPage<PlaylistSummary>, BffError> {
        let path = format!(
            "/search/db/playlists?q={}&limit={limit}&page={}",
            enc(query),
            offset_to_page(offset, limit)
        );
        let env: ListEnvelope<PlaylistSummaryDto> = self.get_json(&path).await?;
        Ok(env.into_page(PlaylistSummaryDto::into_domain))
    }

    pub async fn search_users(
        &self,
        query: &str,
        limit: u32,
        offset: u32,
    ) -> Result<ListPage<User>, BffError> {
        let path = format!(
            "/search/db/users?q={}&limit={limit}&page={}",
            enc(query),
            offset_to_page(offset, limit)
        );
        let env: ListEnvelope<UserProfileDto> = self.get_json(&path).await?;
        Ok(env.into_page(UserProfileDto::into_domain))
    }
}
