//! QR-перенос сессии (`/auth/link/*`). Один девайс создаёт линк и показывает QR
//! payload `scd://link?token=…&mode=…`, второй сканирует и клеймит.

use serde::Serialize;

use sc_domain::{LinkClaim, LinkCreate, LinkStatus};

use crate::client::{enc, BffClient};
use crate::dto::auth::{LinkClaimDto, LinkCreateDto, LinkStatusDto};
use crate::error::BffError;

#[derive(Serialize)]
struct CreateBody<'a> {
    mode: &'a str,
}

#[derive(Serialize)]
struct ClaimBody<'a> {
    #[serde(rename = "claimToken")]
    claim_token: &'a str,
}

impl BffClient {
    /// Создать линк (`mode` = "pull"|"push"). Возвращает токены + готовый
    /// `scd://link`-payload для QR.
    pub async fn link_create(&self, mode: &str) -> Result<LinkCreate, BffError> {
        let dto: LinkCreateDto = self.post_json("/auth/link/create", &CreateBody { mode }).await?;
        Ok(dto.into_domain(mode))
    }

    /// Поллинг статуса линка по `linkRequestId`.
    pub async fn link_status(&self, link_request_id: &str) -> Result<LinkStatus, BffError> {
        let path = format!("/auth/link/status?id={}", enc(link_request_id));
        let dto: LinkStatusDto = self.get_json(&path).await?;
        Ok(dto.into_domain())
    }

    /// Клейм отсканированного payload. Принимает либо полный `scd://link?...`,
    /// либо голый claimToken — вытаскиваем токен и постим бэкенду.
    pub async fn link_claim(&self, payload: &str) -> Result<LinkClaim, BffError> {
        let claim_token = extract_claim_token(payload);
        let dto: LinkClaimDto = self
            .post_json("/auth/link/claim", &ClaimBody { claim_token })
            .await?;
        Ok(dto.into_domain())
    }
}

/// `scd://link?token=<t>&mode=<m>` → `<t>`. Не URL → весь вход как токен.
fn extract_claim_token(payload: &str) -> &str {
    let Some(query) = payload.split_once('?').map(|(_, q)| q) else {
        return payload;
    };
    query
        .split('&')
        .filter_map(|pair| pair.split_once('='))
        .find(|(k, _)| *k == "token")
        .map(|(_, v)| v)
        .unwrap_or(payload)
}

#[cfg(test)]
mod tests {
    use super::extract_claim_token;

    #[test]
    fn extracts_token_from_payload() {
        assert_eq!(extract_claim_token("scd://link?token=abc123&mode=pull"), "abc123");
        assert_eq!(extract_claim_token("scd://link?mode=push&token=xyz"), "xyz");
        assert_eq!(extract_claim_token("rawtoken"), "rawtoken");
    }
}
