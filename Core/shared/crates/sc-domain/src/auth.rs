use serde::{Deserialize, Serialize};

/// Состояние авторизации. `has_session` — локальное наличие токена (видит только
/// `sc-core`), `authenticated` — подтверждение бэкендом (`/auth/status`).
#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct AuthStatus {
    pub has_session: bool,
    pub authenticated: bool,
    pub session_id: Option<String>,
    pub username: Option<String>,
    pub token_state: Option<String>,
}

/// Старт OAuth-логина (`/auth/login`): url для системного браузера + id запроса.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct LoginStart {
    pub url: String,
    pub login_request_id: String,
}

/// Шаг поллинга логина (`/auth/login/status`).
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct LoginStatus {
    pub status: String,
    pub step: Option<String>,
    pub session_id: Option<String>,
    pub username: Option<String>,
    pub error: Option<String>,
    pub redirect_url: Option<String>,
}

/// Создан QR-линк переноса сессии (`POST /auth/link/create`). `payload` —
/// готовая строка `scd://link?token=…&mode=…` для QR.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct LinkCreate {
    pub link_request_id: String,
    pub claim_token: String,
    pub mode: String,
    pub payload: String,
    pub expires_at: Option<String>,
}

/// Поллинг QR-линка (`GET /auth/link/status`). На `claimed` приходит session_id.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct LinkStatus {
    pub status: String,
    pub mode: Option<String>,
    pub session_id: Option<String>,
    pub error: Option<String>,
}

/// Результат клейма сканирующим девайсом (`POST /auth/link/claim`).
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct LinkClaim {
    pub session_id: Option<String>,
    pub mode: Option<String>,
}
