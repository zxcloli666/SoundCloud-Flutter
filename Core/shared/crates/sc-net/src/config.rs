use std::sync::Arc;

use crate::error::NetError;
use crate::retry::RetryPolicy;
use crate::route::{Route, Router};
use crate::transport::{BypassTransport, DirectTransport, ProxyTransport, RelayTransport, Transport};

#[derive(Clone, Debug)]
pub struct RelayConfig {
    pub base: String,
    /// Заголовок авторизации релея, напр. `("x-relay-key", token)`.
    pub auth: Option<(String, String)>,
}

/// Через что ходить.
#[derive(Clone, Debug, Default)]
pub enum Mode {
    #[default]
    Direct,
    /// `http://`, `socks5://`, ... (VPN — частный случай: его эндпоинт).
    Proxy(String),
    /// Локальный пробив DPI.
    Bypass,
    /// Через наш edge/relay.
    Relay(RelayConfig),
}

/// Декларативная конфигурация сети. Здесь живут «слать на другой домен», «эти
/// хосты только через прокси/VPN/relay», «при блокировке — пробивать». Меняешь
/// конфиг — весь трафик едет иначе, вызовы выше не трогаются.
#[derive(Clone, Debug, Default)]
pub struct NetConfig {
    pub mode: Mode,
    /// Добавить пробив DPI как фоллбэк к основному режиму.
    pub bypass_fallback: bool,
    /// Точечные правила `host → режим`.
    pub host_overrides: Vec<(String, Mode)>,
    /// Политика повторов/таймаутов.
    pub retry: RetryPolicy,
    /// User-Agent по умолчанию (если не задан — берётся встроенный).
    pub user_agent: Option<String>,
}

impl NetConfig {
    pub fn direct() -> Self {
        Self::default()
    }

    pub fn via_proxy(url: impl Into<String>) -> Self {
        Self {
            mode: Mode::Proxy(url.into()),
            ..Default::default()
        }
    }

    pub fn via_relay(base: impl Into<String>) -> Self {
        Self {
            mode: Mode::Relay(RelayConfig {
                base: base.into(),
                auth: None,
            }),
            ..Default::default()
        }
    }

    pub fn with_bypass_fallback(mut self) -> Self {
        self.bypass_fallback = true;
        self
    }

    pub fn route_host(mut self, host: impl Into<String>, mode: Mode) -> Self {
        self.host_overrides.push((host.into(), mode));
        self
    }

    /// Собрать роутер. Здесь связываются конкретные транспорты (DI).
    pub async fn build_router(&self) -> Result<Router, NetError> {
        // Поднять пробив DPI, если нужен. Сбой spawn НЕ валит запуск: деградируем
        // до без-bypass (Direct/прокси всё равно работают там, где нет блокировки).
        // Исключение — режим строго `Bypass`: там без него никак (ошибка наверх).
        let bypass: Option<Arc<dyn Transport>> = if self.needs_bypass() {
            match BypassTransport::spawn(true).await {
                Ok(transport) => Some(Arc::new(transport)),
                Err(error) => {
                    tracing::warn!("DPI bypass spawn failed, degrading: {error}");
                    if matches!(self.mode, Mode::Bypass) {
                        return Err(error);
                    }
                    None
                }
            }
        } else {
            None
        };

        let mut router = Router::with_retry(
            self.route_for_mode(&self.mode, &bypass)?,
            self.retry.clone(),
        );
        for (host, mode) in &self.host_overrides {
            router.route_host(host.clone(), self.route_for_mode(mode, &bypass)?);
        }
        Ok(router)
    }

    fn needs_bypass(&self) -> bool {
        self.bypass_fallback
            || matches!(self.mode, Mode::Bypass)
            || self
                .host_overrides
                .iter()
                .any(|(_, mode)| matches!(mode, Mode::Bypass))
    }

    fn route_for_mode(
        &self,
        mode: &Mode,
        bypass: &Option<Arc<dyn Transport>>,
    ) -> Result<Route, NetError> {
        let primary: Arc<dyn Transport> = match mode {
            Mode::Direct => Arc::new(DirectTransport::new()?),
            Mode::Proxy(url) => Arc::new(ProxyTransport::new(url)?),
            Mode::Bypass => bypass
                .clone()
                .ok_or_else(|| NetError::Io("bypass not initialized".into()))?,
            Mode::Relay(cfg) => {
                let mut transport = RelayTransport::new(cfg.base.clone())?;
                if let Some((header, value)) = &cfg.auth {
                    transport = transport.with_auth(header.clone(), value.clone());
                }
                Arc::new(transport)
            }
        };

        let mut chain = vec![primary];
        if self.bypass_fallback
            && !matches!(mode, Mode::Bypass)
            && let Some(bypass) = bypass
        {
            chain.push(bypass.clone());
        }
        Ok(Route::new(chain))
    }
}
