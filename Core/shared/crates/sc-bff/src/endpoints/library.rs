use sc_domain::{ListPage, Me, PlaylistSummary, Track, User};

use crate::client::{BffClient, offset_to_page};
use crate::dto::envelope::ListEnvelope;
use crate::dto::playlist::PlaylistSummaryDto;
use crate::dto::track::TrackDto;
use crate::dto::user::{MeDto, SubscriptionDto, UserProfileDto};
use crate::error::BffError;

impl BffClient {
    pub async fn me(&self) -> Result<Me, BffError> {
        let dto: MeDto = self.get_json("/me").await?;
        let premium = self.me_subscription().await.unwrap_or(false);
        Ok(dto.into_domain(premium))
    }

    pub async fn me_subscription(&self) -> Result<bool, BffError> {
        let dto: SubscriptionDto = self.get_json("/me/subscription").await?;
        Ok(dto.premium)
    }

    pub async fn me_likes_tracks(
        &self,
        limit: u32,
        offset: u32,
    ) -> Result<ListPage<Track>, BffError> {
        let path =
            format!("/me/likes/tracks?limit={limit}&page={}", offset_to_page(offset, limit));
        let env: ListEnvelope<TrackDto> = self.get_json(&path).await?;
        Ok(env.into_page(TrackDto::into_domain))
    }

    pub async fn me_likes_playlists(
        &self,
        limit: u32,
        offset: u32,
    ) -> Result<ListPage<PlaylistSummary>, BffError> {
        let path =
            format!("/me/likes/playlists?limit={limit}&page={}", offset_to_page(offset, limit));
        let env: ListEnvelope<PlaylistSummaryDto> = self.get_json(&path).await?;
        Ok(env.into_page(PlaylistSummaryDto::into_domain))
    }

    pub async fn me_playlists(
        &self,
        limit: u32,
        offset: u32,
    ) -> Result<ListPage<PlaylistSummary>, BffError> {
        let path = format!("/me/playlists?limit={limit}&page={}", offset_to_page(offset, limit));
        let env: ListEnvelope<PlaylistSummaryDto> = self.get_json(&path).await?;
        Ok(env.into_page(PlaylistSummaryDto::into_domain))
    }

    /// Артисты, на которых подписан текущий пользователь (`/me/followings`).
    /// Бэкенд постранично через `page` — конвертируем offset.
    pub async fn me_followings(
        &self,
        limit: u32,
        offset: u32,
    ) -> Result<ListPage<User>, BffError> {
        let page = offset_to_page(offset, limit);
        let path = format!("/me/followings?limit={limit}&page={page}");
        let env: ListEnvelope<UserProfileDto> = self.get_json(&path).await?;
        Ok(env.into_page(UserProfileDto::into_domain))
    }

    /// Свежие треки от подписок (`/me/followings/tracks`) — Library Fresh Drops.
    pub async fn me_followings_tracks(
        &self,
        limit: u32,
        offset: u32,
    ) -> Result<ListPage<Track>, BffError> {
        let page = offset_to_page(offset, limit);
        let path = format!("/me/followings/tracks?limit={limit}&page={page}");
        let env: ListEnvelope<TrackDto> = self.get_json(&path).await?;
        Ok(env.into_page(TrackDto::into_domain))
    }
}
