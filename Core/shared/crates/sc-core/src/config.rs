use std::path::PathBuf;

use sc_net::NetConfig;

/// Конфигурация рантайма. Пути вычисляет оболочка под платформу и передаёт сюда.
#[derive(Clone, Debug)]
pub struct ScConfig {
    /// Данные (сессия и пр.).
    pub data_dir: PathBuf,
    /// Кэш треков.
    pub cache_dir: PathBuf,
    /// Сетевая политика (режим, прокси, пробив, retry).
    pub net: NetConfig,
    /// Пробив DPI как fallback: при блокировке Direct/прокси хост добивается через
    /// TLS-фрагментацию ([`NetConfig::with_bypass_fallback`]). Применяется в сборке.
    pub dpi_bypass: bool,
}

impl ScConfig {
    pub fn new(data_dir: impl Into<PathBuf>, cache_dir: impl Into<PathBuf>) -> Self {
        Self {
            data_dir: data_dir.into(),
            cache_dir: cache_dir.into(),
            net: NetConfig::default(),
            dpi_bypass: false,
        }
    }

    pub fn with_net(mut self, net: NetConfig) -> Self {
        self.net = net;
        self
    }

    pub fn with_dpi_bypass(mut self, enabled: bool) -> Self {
        self.dpi_bypass = enabled;
        self
    }
}
