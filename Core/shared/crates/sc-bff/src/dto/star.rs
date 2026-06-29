use serde::Deserialize;

use sc_domain::{ArtistStar, Aura, WebProfile};

#[derive(Deserialize)]
pub(crate) struct ArtistStarDto {
    #[serde(default)]
    pub premium: bool,
    #[serde(default)]
    pub aura_id: Option<String>,
    #[serde(default)]
    pub custom_hex: Option<String>,
    #[serde(default)]
    pub source_sc_user_id: Option<String>,
}

impl ArtistStarDto {
    pub(crate) fn into_domain(self) -> ArtistStar {
        ArtistStar {
            premium: self.premium,
            aura_id: self.aura_id,
            custom_hex: self.custom_hex,
            source_sc_user_id: self.source_sc_user_id,
        }
    }
}

#[derive(Deserialize)]
pub(crate) struct AuraDto {
    #[serde(default)]
    pub aura_id: Option<String>,
    #[serde(default)]
    pub custom_hex: Option<String>,
}

impl AuraDto {
    pub(crate) fn into_domain(self) -> Aura {
        Aura {
            aura_id: self.aura_id,
            custom_hex: self.custom_hex,
        }
    }
}

/// Веб-профиль из сырого SC (`network` иногда зовётся `service`).
#[derive(Deserialize)]
pub(crate) struct WebProfileDto {
    #[serde(default, alias = "service")]
    pub network: Option<String>,
    #[serde(default)]
    pub title: Option<String>,
    #[serde(default)]
    pub url: Option<String>,
    #[serde(default)]
    pub username: Option<String>,
}

impl WebProfileDto {
    pub(crate) fn into_domain(self) -> WebProfile {
        WebProfile {
            network: self.network,
            title: self.title,
            url: self.url.unwrap_or_default(),
            username: self.username,
        }
    }
}

/// SC waveform-JSON (`{width, height, samples:[0..height]}`).
#[derive(Deserialize)]
pub(crate) struct WaveformDto {
    #[serde(default)]
    pub height: f32,
    #[serde(default)]
    pub samples: Vec<f32>,
}

impl WaveformDto {
    /// Нормированные в 0..1 семплы (делим на пик/высоту, защищаясь от нуля).
    pub(crate) fn into_normalized(self) -> Vec<f32> {
        let peak = if self.height > 0.0 {
            self.height
        } else {
            self.samples.iter().copied().fold(0.0_f32, f32::max)
        };
        if peak <= 0.0 {
            return self.samples.iter().map(|_| 0.0).collect();
        }
        self.samples.into_iter().map(|s| (s / peak).clamp(0.0, 1.0)).collect()
    }
}
