use serde::{Deserialize, Serialize};

use crate::playlist::PlaylistSummary;
use crate::track::Track;

/// Редакционный спотлайт (`/featured`): один пик — трек или плейлист.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Featured {
    pub kind: String,
    pub pick: FeaturedPick,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub enum FeaturedPick {
    Track(Box<Track>),
    Playlist(Box<PlaylistSummary>),
    /// Тип, который не смогли разобрать в трек/плейлист.
    Unknown,
}
