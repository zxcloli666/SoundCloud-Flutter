use serde::Serialize;

use sc_domain::{Cluster, Wave};

use crate::client::BffClient;
use crate::dto::wave::{HomeDto, WaveDto};
use crate::error::BffError;

/// Дописывает к пути query-фильтры волны (легаси): `languages` (CSV, если есть)
/// и всегда `hide_listened` (0/1).
fn with_wave_filters(mut path: String, languages: &[String], hide_listened: bool) -> String {
    if !languages.is_empty() {
        path.push_str("&languages=");
        path.push_str(&crate::client::enc(&languages.join(",")));
    }
    path.push_str(if hide_listened {
        "&hide_listened=1"
    } else {
        "&hide_listened=0"
    });
    path
}

#[derive(Serialize)]
struct FeedbackBody<'a> {
    #[serde(rename = "clusterId")]
    cluster_id: &'a str,
    #[serde(rename = "type")]
    kind: &'a str,
}

#[derive(Serialize)]
struct WaveFeedbackBody<'a> {
    cursor: &'a str,
    negatives: u32,
    positives: u32,
}

impl BffClient {
    /// Кластеры домашней реки (`/recommendations`): только id треков. Фильтры
    /// волны (легаси): `languages` (CSV, если непусто) и `hide_listened` (0/1).
    pub async fn home_clusters(
        &self,
        limit: u32,
        languages: &[String],
        hide_listened: bool,
    ) -> Result<Vec<Cluster>, BffError> {
        let path = with_wave_filters(
            format!("/recommendations?limit={limit}"),
            languages,
            hide_listened,
        );
        let dto: HomeDto = self.get_json(&path).await?;
        Ok(dto.into_domain())
    }

    pub async fn wave(
        &self,
        limit: u32,
        cursor: Option<&str>,
        languages: &[String],
        hide_listened: bool,
    ) -> Result<Wave, BffError> {
        let mut path = format!("/recommendations/wave?limit={limit}");
        if let Some(cursor) = cursor {
            path.push_str("&cursor=");
            path.push_str(&crate::client::enc(cursor));
        }
        let path = with_wave_filters(path, languages, hide_listened);
        let dto: WaveDto = self.get_json(&path).await?;
        Ok(dto.into_domain())
    }

    /// Кластеры «похоже на трек» (`/recommendations/similar/{track_id}`).
    /// Тот же `{clusters}`-формат, что и домашняя река.
    pub async fn recommendations_similar(
        &self,
        track_id: &str,
        limit: u32,
    ) -> Result<Vec<Cluster>, BffError> {
        let path = format!("/recommendations/similar/{}?limit={limit}", crate::client::enc(track_id));
        let dto: HomeDto = self.get_json(&path).await?;
        Ok(dto.into_domain())
    }

    /// Кластеры волны артиста (`/recommendations/artist/{artist_id}`).
    pub async fn recommendations_artist(
        &self,
        artist_id: &str,
        limit: u32,
    ) -> Result<Vec<Cluster>, BffError> {
        let path = format!("/recommendations/artist/{artist_id}?limit={limit}");
        let dto: HomeDto = self.get_json(&path).await?;
        Ok(dto.into_domain())
    }

    /// Сигнал по кластеру (`POST /recommendations/feedback`): `kind` =
    /// click|complete — питает бандиты ранжирования. Best-effort.
    pub async fn recommendations_feedback(
        &self,
        cluster_id: &str,
        kind: &str,
    ) -> Result<(), BffError> {
        let body = FeedbackBody { cluster_id, kind };
        self.post_ok("/recommendations/feedback", &body).await
    }

    /// Сигнал по волне (`POST /recommendations/wave/feedback`). Возвращает новый
    /// курсор продолжения, если бэкенд его пересобрал.
    pub async fn wave_feedback(
        &self,
        cursor: &str,
        negatives: u32,
        positives: u32,
    ) -> Result<Option<String>, BffError> {
        let body = WaveFeedbackBody {
            cursor,
            negatives,
            positives,
        };
        let resp: WaveFeedbackResp = self.post_json("/recommendations/wave/feedback", &body).await?;
        Ok(resp.cursor)
    }
}

#[derive(serde::Deserialize)]
struct WaveFeedbackResp {
    #[serde(default)]
    cursor: Option<String>,
}
