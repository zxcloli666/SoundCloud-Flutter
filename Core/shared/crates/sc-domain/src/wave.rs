use serde::{Deserialize, Serialize};

/// Кластер домашней реки (`/recommendations`): id треков (resolve отдельно) +
/// соседи-артисты (для «От любимых»/«Близкие миры» — артист-карточки).
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Cluster {
    pub id: String,
    pub track_ids: Vec<String>,
    #[serde(default)]
    pub neighbors: Vec<ClusterNeighbor>,
}

/// Сосед-артист кластера: артист + его репрезентативный трек (`track_id`).
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ClusterNeighbor {
    pub artist_id: String,
    pub artist_name: String,
    pub avatar_url: Option<String>,
    pub track_id: String,
}

/// Элемент волны: id трека + score близости.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct WaveItem {
    pub id: i64,
    pub score: f32,
}

/// Волна (`/recommendations/wave`): треки + курсор продолжения.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Wave {
    pub items: Vec<WaveItem>,
    pub cursor: Option<String>,
}
