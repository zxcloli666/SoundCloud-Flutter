//! Эндпоинты BFF — по одному `impl BffClient`-блоку на тему. Каждый метод =
//! один реальный эндпоинт из backend-contract.

mod album;
mod artist;
mod aura;
mod auth;
mod auth_link;
mod batch;
mod discover;
mod library;
mod misc;
mod mutations;
mod playlist;
mod playlist_edit;
mod reco;
mod resolve;
mod search;
mod track;
mod user;
