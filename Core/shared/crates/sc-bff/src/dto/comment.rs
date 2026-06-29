use serde::{Deserialize, Serialize};

use sc_domain::{Comment, CommentUser, Urn};

#[derive(Deserialize)]
pub(crate) struct CommentDto {
    pub id: i64,
    pub body: String,
    #[serde(default)]
    pub timestamp: Option<i64>,
    #[serde(default)]
    pub created_at: Option<String>,
    pub user: CommentUserDto,
}

#[derive(Deserialize)]
pub(crate) struct CommentUserDto {
    #[serde(default)]
    pub id: Option<i64>,
    #[serde(default)]
    pub urn: Option<String>,
    pub username: String,
    #[serde(default)]
    pub avatar_url: Option<String>,
    #[serde(default)]
    pub permalink_url: Option<String>,
}

impl CommentDto {
    pub(crate) fn into_domain(self) -> Comment {
        Comment {
            id: self.id,
            body: self.body,
            timestamp_ms: self.timestamp,
            created_at: self.created_at,
            user: self.user.into_domain(),
        }
    }
}

impl CommentUserDto {
    fn into_domain(self) -> CommentUser {
        let urn = self
            .urn
            .unwrap_or_else(|| format!("soundcloud:users:{}", self.id.unwrap_or(0)));
        CommentUser {
            id: Urn::new(urn),
            username: self.username,
            avatar_url: self.avatar_url,
            permalink_url: self.permalink_url,
        }
    }
}

/// Тело POST-комментария: `{comment:{body, timestamp}}` (легаси `usePostComment`).
#[derive(Serialize)]
pub(crate) struct PostCommentBody<'a> {
    pub comment: CommentInput<'a>,
}

#[derive(Serialize)]
pub(crate) struct CommentInput<'a> {
    pub body: &'a str,
    pub timestamp: i64,
}
