use sc_domain::Urn;

use crate::client::BffClient;
use crate::error::BffError;
use sc_net::HttpResponse;

// Все мьютации возвращают непрозрачный JSON-результат; нам важен лишь успех
// (2xx). Не-2xx → `BffError::Status`, транспортная ошибка пробрасывается.
impl BffClient {
    pub async fn like_track(&self, track_urn: &Urn) -> Result<(), BffError> {
        let path = format!("/likes/tracks/{track_urn}");
        ok_2xx(&path, self.post_empty(&path).await?)
    }

    pub async fn unlike_track(&self, track_urn: &Urn) -> Result<(), BffError> {
        let path = format!("/likes/tracks/{track_urn}");
        ok_2xx(&path, self.delete(&path).await?)
    }

    pub async fn like_playlist(&self, playlist_urn: &Urn) -> Result<(), BffError> {
        let path = format!("/likes/playlists/{playlist_urn}");
        ok_2xx(&path, self.post_empty(&path).await?)
    }

    pub async fn unlike_playlist(&self, playlist_urn: &Urn) -> Result<(), BffError> {
        let path = format!("/likes/playlists/{playlist_urn}");
        ok_2xx(&path, self.delete(&path).await?)
    }

    /// `PUT /me/followings/{user_urn}`.
    pub async fn follow_user(&self, user_urn: &Urn) -> Result<(), BffError> {
        let path = format!("/me/followings/{user_urn}");
        ok_2xx(&path, self.put_empty(&path).await?)
    }

    /// `DELETE /me/followings/{user_urn}`.
    pub async fn unfollow_user(&self, user_urn: &Urn) -> Result<(), BffError> {
        let path = format!("/me/followings/{user_urn}");
        ok_2xx(&path, self.delete(&path).await?)
    }

    /// `POST /dislikes/{sc_track_id}` (`sc_track_id` — голый id или URN).
    pub async fn dislike_track(&self, sc_track_id: &str) -> Result<(), BffError> {
        let path = format!("/dislikes/{}", crate::client::enc(sc_track_id));
        ok_2xx(&path, self.post_empty(&path).await?)
    }

    pub async fn undislike_track(&self, sc_track_id: &str) -> Result<(), BffError> {
        let path = format!("/dislikes/{}", crate::client::enc(sc_track_id));
        ok_2xx(&path, self.delete(&path).await?)
    }

    /// `DELETE /history` — очистить историю прослушиваний.
    pub async fn clear_history(&self) -> Result<(), BffError> {
        let path = "/history";
        ok_2xx(path, self.delete(path).await?)
    }

    /// Дизлайкнут ли трек (`GET /dislikes/status/{sc_track_id}` → `{disliked}`).
    pub async fn dislike_status(&self, sc_track_id: &str) -> Result<bool, BffError> {
        let path = format!("/dislikes/status/{}", crate::client::enc(sc_track_id));
        let dto: DislikeStatusDto = self.get_json(&path).await?;
        Ok(dto.disliked)
    }

    /// Все дизлайкнутые id (`GET /dislikes/ids` → `{ids:[...]}`) — для пометки
    /// в списках. Бэкенд капит выдачу 1000.
    pub async fn dislike_ids(&self) -> Result<Vec<String>, BffError> {
        let dto: DislikeIdsDto = self.get_json("/dislikes/ids").await?;
        Ok(dto.ids)
    }
}

#[derive(serde::Deserialize)]
struct DislikeStatusDto {
    #[serde(default)]
    disliked: bool,
}

#[derive(serde::Deserialize)]
struct DislikeIdsDto {
    #[serde(default)]
    ids: Vec<String>,
}

fn ok_2xx(path: &str, resp: HttpResponse) -> Result<(), BffError> {
    if resp.is_success() {
        Ok(())
    } else {
        Err(BffError::Status {
            status: resp.status,
            path: path.to_owned(),
        })
    }
}
