//! Auth-гейт рантайма: статус сессии, старт/поллинг OAuth-логина, логаут.
//! `has_session` — локальный Rust-owned токен; `authenticated` — подтверждение
//! бэкендом. Сетевой сбой не валит гейт: остаёмся `has_session:true`,
//! `authenticated:false` (шелл рисуется, premium/auth-UI гейтятся отдельно).

use sc_domain::{AuthStatus, LinkClaim, LinkCreate, LinkStatus, LoginStart, LoginStatus};

use crate::{CoreError, ScRuntime};

impl ScRuntime {
    /// Статус для бутстрапа. Нет локального токена → без сети. Есть токен →
    /// `GET /auth/status`; сетевой сбой → `has_session:true, authenticated:false`.
    pub async fn auth_status(&self) -> AuthStatus {
        if !self.has_local_session() {
            return AuthStatus::default();
        }
        match self.bff().fetch_remote_status().await {
            Ok(status) => status,
            Err(_) => AuthStatus {
                has_session: true,
                ..AuthStatus::default()
            },
        }
    }

    pub async fn start_login(&self) -> Result<LoginStart, CoreError> {
        Ok(self.bff().start_login().await?)
    }

    pub async fn poll_login(&self, login_request_id: &str) -> Result<LoginStatus, CoreError> {
        Ok(self.bff().poll_login(login_request_id).await?)
    }

    /// Логаут: сперва чистим локальную сессию (это должно случиться даже при
    /// сетевом сбое), затем best-effort revoke на бэкенде.
    pub async fn logout(&self) -> Result<(), CoreError> {
        self.set_session(None)?;
        let _ = self.bff().logout().await;
        Ok(())
    }

    // --- QR-перенос сессии ---

    pub async fn auth_link_create(&self, mode: &str) -> Result<LinkCreate, CoreError> {
        Ok(self.bff().link_create(mode).await?)
    }

    pub async fn auth_link_status(&self, link_request_id: &str) -> Result<LinkStatus, CoreError> {
        Ok(self.bff().link_status(link_request_id).await?)
    }

    pub async fn auth_link_claim(&self, payload: &str) -> Result<LinkClaim, CoreError> {
        Ok(self.bff().link_claim(payload).await?)
    }
}
