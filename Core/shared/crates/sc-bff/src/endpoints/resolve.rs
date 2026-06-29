use sc_domain::Track;

use crate::client::{BffClient, enc};
use crate::dto::track::TrackDto;
use crate::error::BffError;

impl BffClient {
    /// Резолв SC-ссылки (`/resolve?url=`). Возвращает трек только если сущность —
    /// трек (`kind == "track"`); для плейлиста/юзера → `Ok(None)`.
    pub async fn resolve_url(&self, url: &str) -> Result<Option<Track>, BffError> {
        let path = format!("/resolve?url={}", enc(url));
        let resp = self.get(&path).await?;
        match resp.status {
            404 | 410 => return Ok(None),
            s if !(200..300).contains(&s) => {
                return Err(BffError::Status { status: s, path });
            }
            _ => {}
        }
        let kind: KindPeek =
            serde_json::from_slice(&resp.body).map_err(|e| BffError::Decode(e.to_string()))?;
        if kind.kind.as_deref() != Some("track") {
            return Ok(None);
        }
        let dto: TrackDto =
            serde_json::from_slice(&resp.body).map_err(|e| BffError::Decode(e.to_string()))?;
        Ok(Some(dto.into_domain()))
    }
}

#[derive(serde::Deserialize)]
struct KindPeek {
    #[serde(default)]
    kind: Option<String>,
}
