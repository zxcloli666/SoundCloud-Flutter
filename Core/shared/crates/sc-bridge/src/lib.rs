//! Мост ядра в Flutter (flutter_rust_bridge v2).
//!
//! Тонкая трансляция [`sc-core`](../sc_core) в вызовы и потоки для Dart: DTO,
//! ошибки, подписки. Бизнес-логики нет.
//!
//! Кодоген `flutter_rust_bridge_codegen generate` создаёт `frb_generated.rs` и
//! Dart-биндинги; после него в lib добавляется `mod frb_generated;`. До кодогена
//! крейт собирается как обычная либа (проверка API-поверхности).

pub mod api;
pub mod data;
pub mod data_pay;
pub mod data_social;
pub mod dto;
pub mod dto_pay;
pub mod dto_social;
mod frb_generated;
mod map;
mod map_misc;
mod map_pay;
