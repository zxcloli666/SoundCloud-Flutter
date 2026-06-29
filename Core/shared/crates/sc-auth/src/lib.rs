//! Сессия — единственный источник истины (owned ядром, не UI).
//!
//! UI только читает [`Session`] и реагирует на изменения; все мутации (вход по
//! QR, logout, рефреш) идут через [`SessionStore`] и атомарно пишутся на диск.
//! Токен отдаётся сетевому слою как `x-session-id` (через адаптер в `sc-core`,
//! чтобы `sc-auth` не зависел от `sc-net`).

mod store;

pub use store::SessionStore;

use serde::{Deserialize, Serialize};

#[derive(Debug, thiserror::Error)]
pub enum AuthError {
    #[error("storage: {0}")]
    Storage(String),
}

#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct Session {
    pub token: Option<String>,
    pub premium: bool,
}

impl Session {
    pub fn is_authenticated(&self) -> bool {
        self.token.is_some()
    }
}
