use serde::{Deserialize, Serialize};

use crate::track::Track;

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Serialize, Deserialize)]
pub enum RepeatMode {
    #[default]
    Off,
    One,
    All,
}

/// Очередь воспроизведения. Источник продолжения (лайки доигрываются до конца,
/// потом волна) живёт уровнем выше — здесь только сам список и курсор.
#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct Queue {
    pub items: Vec<Track>,
    pub index: usize,
    pub repeat: RepeatMode,
    pub shuffle: bool,
}

impl Queue {
    pub fn current(&self) -> Option<&Track> {
        self.items.get(self.index)
    }

    /// Индекс следующего трека с учётом repeat. `None` — очередь кончилась.
    pub fn next_index(&self) -> Option<usize> {
        match self.repeat {
            RepeatMode::One => Some(self.index),
            _ if self.index + 1 < self.items.len() => Some(self.index + 1),
            RepeatMode::All if !self.items.is_empty() => Some(0),
            _ => None,
        }
    }
}
