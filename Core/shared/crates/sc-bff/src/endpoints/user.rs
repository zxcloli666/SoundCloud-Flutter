use sc_domain::{ListPage, PlaylistSummary, Track, Urn, User, WebProfile};

use crate::client::{BffClient, offset_to_page};
use crate::dto::envelope::ListEnvelope;
use crate::dto::playlist::PlaylistSummaryDto;
use crate::dto::star::WebProfileDto;
use crate::dto::track::TrackDto;
use crate::dto::user::UserProfileDto;
use crate::error::BffError;

impl BffClient {
    /// Профиль пользователя по URN (`/users/{urn}`). `Ok(None)` при 404/410.
    pub async fn user(&self, urn: &Urn) -> Result<Option<User>, BffError> {
        let path = format!("/users/{urn}");
        let dto: Option<UserProfileDto> = self.get_optional(&path).await?;
        Ok(dto.map(UserProfileDto::into_domain))
    }

    pub async fn user_tracks(
        &self,
        urn: &Urn,
        limit: u32,
        offset: u32,
    ) -> Result<ListPage<Track>, BffError> {
        let path = format!("/users/{urn}/tracks?limit={limit}&page={}", offset_to_page(offset, limit));
        let env: ListEnvelope<TrackDto> = self.get_json(&path).await?;
        Ok(env.into_page(TrackDto::into_domain))
    }

    pub async fn user_playlists(
        &self,
        urn: &Urn,
        limit: u32,
        offset: u32,
    ) -> Result<ListPage<PlaylistSummary>, BffError> {
        let path = format!("/users/{urn}/playlists?limit={limit}&page={}", offset_to_page(offset, limit));
        let env: ListEnvelope<PlaylistSummaryDto> = self.get_json(&path).await?;
        Ok(env.into_page(PlaylistSummaryDto::into_domain))
    }

    pub async fn user_liked_tracks(
        &self,
        urn: &Urn,
        limit: u32,
        offset: u32,
    ) -> Result<ListPage<Track>, BffError> {
        let path =
            format!("/users/{urn}/likes/tracks?limit={limit}&page={}", offset_to_page(offset, limit));
        let env: ListEnvelope<TrackDto> = self.get_json(&path).await?;
        Ok(env.into_page(TrackDto::into_domain))
    }

    pub async fn user_followers(
        &self,
        urn: &Urn,
        limit: u32,
        offset: u32,
    ) -> Result<ListPage<User>, BffError> {
        let path = format!("/users/{urn}/followers?limit={limit}&page={}", offset_to_page(offset, limit));
        let env: ListEnvelope<UserProfileDto> = self.get_json(&path).await?;
        Ok(env.into_page(UserProfileDto::into_domain))
    }

    pub async fn user_followings(
        &self,
        urn: &Urn,
        limit: u32,
        offset: u32,
    ) -> Result<ListPage<User>, BffError> {
        let path = format!("/users/{urn}/followings?limit={limit}&page={}", offset_to_page(offset, limit));
        let env: ListEnvelope<UserProfileDto> = self.get_json(&path).await?;
        Ok(env.into_page(UserProfileDto::into_domain))
    }

    /// Веб-профили (`/users/{urn}/web-profiles`) — сырой SC-массив соцссылок.
    pub async fn user_web_profiles(&self, urn: &Urn) -> Result<Vec<WebProfile>, BffError> {
        let path = format!("/users/{urn}/web-profiles");
        let dtos: Vec<WebProfileDto> = self.get_json(&path).await?;
        Ok(dtos.into_iter().map(WebProfileDto::into_domain).collect())
    }

    /// Премиум-флаг пользователя (`/users/{urn}/subscription` → `{premium}`).
    pub async fn user_subscription(&self, urn: &Urn) -> Result<bool, BffError> {
        let path = format!("/users/{urn}/subscription");
        let dto: PremiumDto = self.get_json(&path).await?;
        Ok(dto.premium)
    }
}

#[derive(serde::Deserialize)]
struct PremiumDto {
    #[serde(default)]
    premium: bool,
}
