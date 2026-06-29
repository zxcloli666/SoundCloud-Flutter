use serde::{Deserialize, Serialize};

/// Звёздный/премиум-флаг артиста (`/artists/{id}/star`) + аура источника.
#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct ArtistStar {
    pub premium: bool,
    pub aura_id: Option<String>,
    pub custom_hex: Option<String>,
    pub source_sc_user_id: Option<String>,
}

/// Аура пользователя (`/users/{urn}/aura`, `PUT /me/aura`).
#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct Aura {
    pub aura_id: Option<String>,
    pub custom_hex: Option<String>,
}

/// Веб-профиль/соцссылка SC-пользователя (`/users/{urn}/web-profiles`).
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct WebProfile {
    pub network: Option<String>,
    pub title: Option<String>,
    pub url: String,
    pub username: Option<String>,
}
