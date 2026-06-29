//! Слой данных приложения: чтение **всех** данных бэкенда (`api.scdinternal.site`)
//! через единый [`BffClient`]. Это не сырой SoundCloud (`sc-raw`) — это наш BFF.
//!
//! Всё ходит через транспорт [`sc-net`](../sc_net) ([`NetClient`]): роутинг,
//! прокси и пробив работают даром, а `x-session-id` инъектирует декоратор
//! `ScCredentials` — авторизация прозрачна. Чужой JSON изолирован в приватных
//! DTO (`dto`), наверх отдаём доменные модели `sc-domain`.

mod client;
mod dto;
mod endpoints;
mod error;
mod pay;

pub use client::BffClient;
pub use error::BffError;
pub use pay::PayClient;
