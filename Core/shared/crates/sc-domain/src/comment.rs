use serde::{Deserialize, Serialize};

use crate::ids::Urn;

/// Комментарий слушателя под треком («голос комнаты»). [`timestamp_ms`] —
/// привязка к моменту трека (мс от начала), `None` — комментарий без таймкода.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Comment {
    pub id: i64,
    pub body: String,
    pub timestamp_ms: Option<i64>,
    pub created_at: Option<String>,
    pub user: CommentUser,
}

/// Автор комментария (облегчённая ссылка на пользователя).
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct CommentUser {
    pub id: Urn,
    pub username: String,
    pub avatar_url: Option<String>,
    pub permalink_url: Option<String>,
}
