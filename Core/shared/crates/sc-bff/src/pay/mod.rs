//! Платёжный слой STAR: чтение/запись `pay.scdinternal.site` через [`PayClient`].
//! Отдельный хост от BFF, но тот же транспорт `sc-net` и та же `x-session-id`
//! авторизация (декоратор вешает её на любой хост; на бэке `UserCtx` резолвит
//! сессию в main backend).

mod client;
mod dto;
mod endpoints;

pub use client::PayClient;
