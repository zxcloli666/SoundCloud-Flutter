//! Порты платформенных адаптеров. Ядро дёргает их через `dyn`-трейты;
//! реализации живут снаружи (Desktop/depens, мобильная платформа). Каждый порт
//! имеет no-op заглушку, чтобы рантайм собирался без полного набора реализаций.

/// Системные медиа-контролы (MPRIS/SMTC/NowPlaying/MediaSession). Однонаправлен:
/// ядро сообщает состояние. Команды от медиа-клавиш (обратное направление)
/// добавим отдельным портом, когда понадобится (через Weak, без Arc-цикла).
pub trait MediaControls: Send + Sync {
    fn set_now_playing(&self, title: &str, artist: &str);
    fn set_playing(&self, playing: bool);
    fn clear(&self);
}

/// Заглушка: ничего не делает.
pub struct NoopMediaControls;

impl MediaControls for NoopMediaControls {
    fn set_now_playing(&self, _title: &str, _artist: &str) {}
    fn set_playing(&self, _playing: bool) {}
    fn clear(&self) {}
}
