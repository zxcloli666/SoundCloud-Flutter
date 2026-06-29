# SoundCloud — Flutter + Rust

Кросс-платформенный клиент SoundCloud: интерфейс на **Flutter**, вся нативная
логика (сеть, аудио-движок, кэш, авторизация) — на **Rust**. Мост между ними —
`flutter_rust_bridge`.

## Структура

```
Core/
  visual/   дизайн-система (стекло, NowBar, атмосфера, waveform)
  engine/   экраны, навигация, локализация, биндинги к Rust
  shared/   Rust-ядро: сеть, аудио, кэш, авторизация, данные
Desktop/
  app/      десктопная оболочка (Linux)
  depens/   десктоп-нативка: медиа-контролы (MPRIS), трей, Discord
Mobile/     мобильная оболочка (плейсхолдер)
```

## Установка

Готовая сборка под Linux — на вкладке [Releases](../../releases): скачай архив,
распакуй и запусти `sc_desktop`.

## Сборка из исходников (Linux)

Нужны Flutter SDK 3.44+ и Rust (stable). Нативные библиотеки собираются
автоматически.

```bash
cd Desktop/app
flutter pub get
flutter build linux --release
./build/linux/x64/release/bundle/sc_desktop
```

## Лицензия

MIT — см. `LICENSE`.
