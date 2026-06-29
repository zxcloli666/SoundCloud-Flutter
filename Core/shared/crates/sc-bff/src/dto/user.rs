use serde::Deserialize;

use sc_domain::{Me, Urn, User};

/// Полный SC-профиль (`/search/db/users`, `/users/{urn}`).
#[derive(Deserialize)]
pub(crate) struct UserProfileDto {
    #[serde(deserialize_with = "crate::dto::flex::de_i64")]
    pub id: i64,
    #[serde(default)]
    pub urn: Option<String>,
    #[serde(default)]
    pub username: Option<String>,
    #[serde(default)]
    pub permalink: Option<String>,
    #[serde(default)]
    pub permalink_url: Option<String>,
    #[serde(default)]
    pub avatar_url: Option<String>,
    #[serde(default)]
    pub full_name: Option<String>,
    #[serde(default)]
    pub city: Option<String>,
    #[serde(default)]
    pub country_code: Option<String>,
    #[serde(default)]
    pub description: Option<String>,
    #[serde(default)]
    pub verified: bool,
    #[serde(default)]
    pub followers_count: Option<u64>,
    #[serde(default)]
    pub followings_count: Option<u64>,
    #[serde(default)]
    pub track_count: Option<u64>,
    #[serde(default)]
    pub playlist_count: Option<u64>,
    #[serde(default)]
    pub public_favorites_count: Option<i64>,
    #[serde(default)]
    pub plan: Option<String>,
    #[serde(default)]
    pub created_at: Option<String>,
}

impl UserProfileDto {
    pub(crate) fn into_domain(self) -> User {
        User {
            id: Urn::new(self.urn.unwrap_or_else(|| format!("soundcloud:users:{}", self.id))),
            username: self.username.unwrap_or_default(),
            permalink: self.permalink,
            permalink_url: self.permalink_url,
            avatar_url: self.avatar_url,
            full_name: self.full_name,
            city: self.city,
            country_code: self.country_code,
            description: self.description,
            verified: self.verified,
            followers_count: self.followers_count,
            followings_count: self.followings_count,
            track_count: self.track_count,
            playlist_count: self.playlist_count,
            public_favorites_count: self.public_favorites_count,
            plan: self.plan,
            created_at: self.created_at,
        }
    }
}

/// `/me`. Премиум приходит отдельным вызовом (`/me/subscription`).
#[derive(Deserialize)]
pub(crate) struct MeDto {
    #[serde(deserialize_with = "crate::dto::flex::de_i64")]
    pub id: i64,
    #[serde(default)]
    pub urn: Option<String>,
    #[serde(default)]
    pub username: Option<String>,
    #[serde(default)]
    pub permalink: Option<String>,
    #[serde(default)]
    pub permalink_url: Option<String>,
    #[serde(default)]
    pub avatar_url: Option<String>,
    #[serde(default)]
    pub plan: Option<String>,
    #[serde(default)]
    pub followers_count: Option<u64>,
    #[serde(default)]
    pub followings_count: Option<u64>,
    #[serde(default)]
    pub public_favorites_count: Option<u64>,
    #[serde(default)]
    pub private_playlists_count: Option<u64>,
    #[serde(default)]
    pub playlist_count: Option<u64>,
}

impl MeDto {
    pub(crate) fn into_domain(self, premium: bool) -> Me {
        Me {
            id: Urn::new(self.urn.unwrap_or_else(|| format!("soundcloud:users:{}", self.id))),
            username: self.username.unwrap_or_default(),
            permalink: self.permalink,
            permalink_url: self.permalink_url,
            avatar_url: self.avatar_url,
            plan: self.plan,
            premium,
            followers_count: self.followers_count,
            followings_count: self.followings_count,
            public_favorites_count: self.public_favorites_count,
            private_playlists_count: self.private_playlists_count,
            playlist_count: self.playlist_count,
        }
    }
}

#[derive(Deserialize)]
pub(crate) struct SubscriptionDto {
    #[serde(default)]
    pub premium: bool,
}
