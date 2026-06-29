//! Смена аудиовыхода: перечисление устройств и переключение на лету. Переезд
//! сохраняет текущий трек, позицию, паузу и нормализацию-гейн (инвариант
//! device-switch: звук авто-переезжает, трек не снимается заранее).

use std::sync::atomic::Ordering;

use crate::AudioError;
use crate::device::{self, DeviceInfo};
use crate::engine::{AudioEngine, lock};

impl AudioEngine {
    /// Доступные выходные устройства (для пикера в настройках).
    pub fn output_devices(&self) -> Vec<DeviceInfo> {
        device::list_outputs()
    }

    /// Идём ли за системным выходом по умолчанию (для следящей задачи в `sc-core`).
    pub fn is_following_default(&self) -> bool {
        self.following_default.load(Ordering::Relaxed)
    }

    /// Имя текущего системного выхода по умолчанию (детект смены дефолта ОС).
    pub fn current_default_output(&self) -> Option<String> {
        device::default_output_name()
    }

    /// Переключить аудиовыход: `Some(name)` — на устройство по имени, `None` — на
    /// системное по умолчанию. Текущий трек переезжает на новое устройство с той
    /// же позиции/состояния; при ошибке открытия остаёмся на старом. Громкость
    /// нормализована на транскоде — гейн источника здесь 1.0. `None` включает
    /// слежение за дефолтом ([`is_following_default`](Self::is_following_default)).
    pub fn set_output_device(&self, name: Option<String>) -> Result<(), AudioError> {
        let follow = name.is_none();
        let new_mixer = self.output.switch(name)?;
        *lock(&self.mixer) = new_mixer;
        self.following_default.store(follow, Ordering::Relaxed);
        self.reload_with_gain(1.0)
    }
}
