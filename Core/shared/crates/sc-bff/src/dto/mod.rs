//! Приватные serde-DTO под точный JSON бэкенда. Чужой контракт живёт только
//! здесь и не протекает выше — наверх отдаём доменные модели через `into_domain`.

pub(crate) mod album;
pub(crate) mod artist;
pub(crate) mod auth;
pub(crate) mod comment;
pub(crate) mod discover;
pub(crate) mod envelope;
pub(crate) mod featured;
pub(crate) mod flex;
pub(crate) mod misc;
pub(crate) mod playlist;
pub(crate) mod search;
pub(crate) mod star;
pub(crate) mod tag_list;
pub(crate) mod track;
pub(crate) mod user;
pub(crate) mod wave;
