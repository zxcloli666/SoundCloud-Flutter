//! Пробив DPI-блокировок: локальный SOCKS5-прокси, который фрагментирует TLS
//! ClientHello по выбранной стратегии. Сетевой крейт ([`sc-net`](../sc_net))
//! поднимает [`Desync`], получает `socks5h://`-адрес и гонит через него тот
//! трафик, который иначе режет провайдер.
//!
//! Перенос проверенного `dpi-desync`. Логика стратегий ([`tamper`]) — чистая и
//! работает на любой платформе; SOCKS-сервер и подстройка MSS завязаны на
//! Unix-сокеты (см. `cfg(unix)` в [`socks`]).

mod probe;
mod socks;
mod state;
mod tamper;

use std::net::SocketAddr;
use std::sync::Arc;

use tokio::net::TcpListener;

pub use tamper::Strategy;

/// Запущенный локальный SOCKS5-десинхронизатор. Живёт, пока жив `Desync`.
pub struct Desync {
    addr: SocketAddr,
    state: Arc<state::State>,
}

impl Desync {
    /// Поднять прокси на `127.0.0.1:<случайный порт>`.
    pub async fn spawn(enabled: bool) -> std::io::Result<Self> {
        let listener = TcpListener::bind(SocketAddr::from(([127, 0, 0, 1], 0))).await?;
        let addr = listener.local_addr()?;
        let state = state::State::new(enabled);
        let accept_state = state.clone();
        tokio::spawn(async move { socks::run(listener, accept_state).await });
        Ok(Self { addr, state })
    }

    pub fn addr(&self) -> SocketAddr {
        self.addr
    }

    /// Адрес для `reqwest::Proxy::all(..)`.
    pub fn proxy_url(&self) -> String {
        format!("socks5h://{}", self.addr)
    }

    pub fn set_enabled(&self, enabled: bool) {
        self.state.set_enabled(enabled);
    }

    pub fn is_enabled(&self) -> bool {
        self.state.is_enabled()
    }

    pub fn strategy(&self) -> Strategy {
        self.state.strategy()
    }

    pub fn set_strategy(&self, strategy: Strategy) {
        self.state.set_strategy(strategy);
    }

    /// Перебрать стратегии и выбрать первую, через которую `probe_url` отвечает.
    pub async fn probe(&self, probe_url: &str) -> Strategy {
        probe::run(&self.state, &self.proxy_url(), probe_url).await
    }
}
