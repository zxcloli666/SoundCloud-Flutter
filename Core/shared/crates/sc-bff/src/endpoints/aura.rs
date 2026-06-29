use sc_domain::{Aura, Urn};

use crate::client::BffClient;
use crate::dto::star::AuraDto;
use crate::error::BffError;

impl BffClient {
    /// Аура пользователя (`/users/{urn}/aura`). Премиум-гейт уже на бэкенде.
    pub async fn user_aura(&self, urn: &Urn) -> Result<Aura, BffError> {
        let path = format!("/users/{urn}/aura");
        let dto: AuraDto = self.get_json(&path).await?;
        Ok(dto.into_domain())
    }

    /// Установить свою ауру (`PUT /me/aura`), вернуть применённую.
    pub async fn put_aura(&self, aura_id: &str, custom_hex: Option<&str>) -> Result<Aura, BffError> {
        let body = PutAuraBody {
            aura_id: aura_id.to_owned(),
            custom_hex: custom_hex.map(str::to_owned),
        };
        let dto: AuraDto = self.put_json("/me/aura", &body).await?;
        Ok(dto.into_domain())
    }
}

#[derive(serde::Serialize)]
struct PutAuraBody {
    aura_id: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    custom_hex: Option<String>,
}
