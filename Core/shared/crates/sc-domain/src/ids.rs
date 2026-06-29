//! Идентификаторы. У SoundCloud один объект приходит то как URN
//! (`soundcloud:tracks:123`), то как голый id (`123`) — поэтому единый тип с
//! явным [`Urn::bare`], чтобы не путать формы (см. историю багов с user_id).

use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct Urn(String);

impl Urn {
    pub fn new(value: impl Into<String>) -> Self {
        Self(value.into())
    }

    /// Голый id без префикса `soundcloud:<kind>:`.
    pub fn bare(&self) -> &str {
        self.0.rsplit(':').next().unwrap_or(&self.0)
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}

impl std::fmt::Display for Urn {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(&self.0)
    }
}

impl From<String> for Urn {
    fn from(value: String) -> Self {
        Self(value)
    }
}

impl From<&str> for Urn {
    fn from(value: &str) -> Self {
        Self(value.to_owned())
    }
}
