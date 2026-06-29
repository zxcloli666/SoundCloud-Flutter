use sc_domain::{AuthStatus, LoginStart, LoginStatus};

use crate::client::{BffClient, enc};
use crate::dto::auth::{LoginStartDto, LoginStatusDto, RemoteStatusDto};
use crate::error::BffError;

impl BffClient {
    /// `GET /auth/status`. Только сетевое подтверждение — локальный `has_session`
    /// проставляет `sc-core` (BFF не видит SessionStore). При «токен есть».
    pub async fn fetch_remote_status(&self) -> Result<AuthStatus, BffError> {
        let dto: RemoteStatusDto = self.get_json("/auth/status").await?;
        Ok(dto.into_domain())
    }

    pub async fn start_login(&self) -> Result<LoginStart, BffError> {
        let dto: LoginStartDto = self.get_json("/auth/login").await?;
        Ok(dto.into_domain())
    }

    pub async fn poll_login(&self, login_request_id: &str) -> Result<LoginStatus, BffError> {
        let path = format!("/auth/login/status?id={}", enc(login_request_id));
        let dto: LoginStatusDto = self.get_json(&path).await?;
        Ok(dto.into_domain())
    }

    /// `POST /auth/logout` — best-effort revoke. Не-2xx игнорируем; пробрасываем
    /// только транспортную ошибку.
    pub async fn logout(&self) -> Result<(), BffError> {
        self.post_empty("/auth/logout").await?;
        Ok(())
    }
}
