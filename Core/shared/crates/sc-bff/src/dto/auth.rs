use serde::Deserialize;

use sc_domain::{AuthStatus, LinkClaim, LinkCreate, LinkStatus, LoginStart, LoginStatus};

// Бэкенд auth отдаёт camelCase.

/// `GET /auth/status`. `has_session` тут не приходит — его ставит `sc-core` из
/// локального токена.
#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct RemoteStatusDto {
    #[serde(default)]
    pub authenticated: bool,
    #[serde(default)]
    pub session_id: Option<String>,
    #[serde(default)]
    pub username: Option<String>,
    #[serde(default)]
    pub token_state: Option<String>,
}

impl RemoteStatusDto {
    /// Доменный статус для случая «токен есть»: `has_session = true`.
    pub(crate) fn into_domain(self) -> AuthStatus {
        AuthStatus {
            has_session: true,
            authenticated: self.authenticated,
            session_id: self.session_id,
            username: self.username,
            token_state: self.token_state,
        }
    }
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct LoginStartDto {
    #[serde(default)]
    pub url: Option<String>,
    #[serde(default)]
    pub login_request_id: Option<String>,
}

impl LoginStartDto {
    pub(crate) fn into_domain(self) -> LoginStart {
        LoginStart {
            url: self.url.unwrap_or_default(),
            login_request_id: self.login_request_id.unwrap_or_default(),
        }
    }
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct LoginStatusDto {
    #[serde(default)]
    pub status: Option<String>,
    #[serde(default)]
    pub step: Option<String>,
    #[serde(default)]
    pub session_id: Option<String>,
    #[serde(default)]
    pub username: Option<String>,
    #[serde(default)]
    pub error: Option<String>,
    #[serde(default)]
    pub redirect_url: Option<String>,
}

impl LoginStatusDto {
    pub(crate) fn into_domain(self) -> LoginStatus {
        LoginStatus {
            status: self.status.unwrap_or_default(),
            step: self.step,
            session_id: self.session_id,
            username: self.username,
            error: self.error,
            redirect_url: self.redirect_url,
        }
    }
}

/// `POST /auth/link/create` → `{linkRequestId, claimToken, expiresAt}`.
#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct LinkCreateDto {
    #[serde(default)]
    pub link_request_id: Option<String>,
    #[serde(default)]
    pub claim_token: Option<String>,
    #[serde(default)]
    pub expires_at: Option<String>,
}

impl LinkCreateDto {
    /// `mode` приходит от вызывающего — бэкенд его в ответе не повторяет; он же
    /// нужен в `scd://link`-payload, который сканирует второй девайс.
    pub(crate) fn into_domain(self, mode: &str) -> LinkCreate {
        let claim_token = self.claim_token.unwrap_or_default();
        let payload = format!(
            "scd://link?token={}&mode={}",
            urlencoding::encode(&claim_token),
            urlencoding::encode(mode)
        );
        LinkCreate {
            link_request_id: self.link_request_id.unwrap_or_default(),
            claim_token,
            mode: mode.to_owned(),
            payload,
            expires_at: self.expires_at,
        }
    }
}

/// `GET /auth/link/status` → `{status, mode, sessionId?, error?}`.
#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct LinkStatusDto {
    #[serde(default)]
    pub status: Option<String>,
    #[serde(default)]
    pub mode: Option<String>,
    #[serde(default)]
    pub session_id: Option<String>,
    #[serde(default)]
    pub error: Option<String>,
}

impl LinkStatusDto {
    pub(crate) fn into_domain(self) -> LinkStatus {
        LinkStatus {
            status: self.status.unwrap_or_default(),
            mode: self.mode,
            session_id: self.session_id,
            error: self.error,
        }
    }
}

/// `POST /auth/link/claim` → `{sessionId, mode}`.
#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct LinkClaimDto {
    #[serde(default)]
    pub session_id: Option<String>,
    #[serde(default)]
    pub mode: Option<String>,
}

impl LinkClaimDto {
    pub(crate) fn into_domain(self) -> LinkClaim {
        LinkClaim {
            session_id: self.session_id,
            mode: self.mode,
        }
    }
}
