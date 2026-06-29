use serde::{Deserialize, Serialize};

use crate::ids::Urn;

/// Полный SC-профиль пользователя (результат /search/db/users).
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct User {
    pub id: Urn,
    pub username: String,
    pub permalink: Option<String>,
    pub permalink_url: Option<String>,
    pub avatar_url: Option<String>,
    pub full_name: Option<String>,
    pub city: Option<String>,
    pub country_code: Option<String>,
    pub description: Option<String>,
    pub verified: bool,
    pub followers_count: Option<u64>,
    pub followings_count: Option<u64>,
    pub track_count: Option<u64>,
    pub playlist_count: Option<u64>,
    pub public_favorites_count: Option<i64>,
    pub plan: Option<String>,
    pub created_at: Option<String>,
}

/// Облегчённая ссылка на SC-пользователя (загрузчик трека/владелец плейлиста).
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct UserRef {
    pub id: Urn,
    pub username: String,
    pub permalink: Option<String>,
    pub permalink_url: Option<String>,
    pub avatar_url: Option<String>,
    pub verified: bool,
}

/// Профиль текущего пользователя (`/me`) + флаг премиума (`/me/subscription`).
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Me {
    pub id: Urn,
    pub username: String,
    pub permalink: Option<String>,
    pub permalink_url: Option<String>,
    pub avatar_url: Option<String>,
    pub plan: Option<String>,
    pub premium: bool,
    pub followers_count: Option<u64>,
    pub followings_count: Option<u64>,
    pub public_favorites_count: Option<u64>,
    pub private_playlists_count: Option<u64>,
    pub playlist_count: Option<u64>,
}
