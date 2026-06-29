use serde::Deserialize;

use sc_domain::{Cluster, ClusterNeighbor, Wave, WaveItem};

#[derive(Deserialize)]
pub(crate) struct HomeDto {
    #[serde(default)]
    pub clusters: Vec<ClusterDto>,
}

#[derive(Deserialize)]
pub(crate) struct ClusterDto {
    pub id: String,
    #[serde(default)]
    pub track_ids: Vec<String>,
    #[serde(default)]
    pub neighbors: Vec<NeighborDto>,
}

#[derive(Deserialize)]
pub(crate) struct NeighborDto {
    pub artist_id: String,
    #[serde(default)]
    pub artist_name: String,
    #[serde(default)]
    pub avatar_url: Option<String>,
    pub track_id: String,
}

impl HomeDto {
    pub(crate) fn into_domain(self) -> Vec<Cluster> {
        self.clusters
            .into_iter()
            .map(|c| Cluster {
                id: c.id,
                track_ids: c.track_ids,
                neighbors: c
                    .neighbors
                    .into_iter()
                    .map(|n| ClusterNeighbor {
                        artist_id: n.artist_id,
                        artist_name: n.artist_name,
                        avatar_url: n.avatar_url,
                        track_id: n.track_id,
                    })
                    .collect(),
            })
            .collect()
    }
}

#[derive(Deserialize)]
pub(crate) struct WaveDto {
    #[serde(default)]
    pub tracks: Vec<WaveItemDto>,
    #[serde(default)]
    pub cursor: Option<String>,
}

#[derive(Deserialize)]
pub(crate) struct WaveItemDto {
    #[serde(deserialize_with = "crate::dto::flex::de_i64")]
    pub id: i64,
    #[serde(default)]
    pub score: f32,
}

impl WaveDto {
    pub(crate) fn into_domain(self) -> Wave {
        Wave {
            items: self
                .tracks
                .into_iter()
                .map(|t| WaveItem {
                    id: t.id,
                    score: t.score,
                })
                .collect(),
            cursor: self.cursor,
        }
    }
}
