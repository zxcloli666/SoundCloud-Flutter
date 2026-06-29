//! Выходные аудиоустройства. На Linux — через PulseAudio (`pactl`): cpal/ALSA
//! отдаёт кучу мусорных виртуальных устройств, а pactl показывает реальные синки
//! и умеет маршрутизировать дефолт. На прочих ОС — нативная cpal-перечисление.
//! Живёт на потоке-владельце (cpal-устройство `!Send`) — см. [`crate::output`].

use rodio::cpal;
use rodio::stream::{DeviceSinkBuilder, MixerDeviceSink};

use crate::AudioError;

/// Выходное устройство для пикера: `name` — идентификатор для переключения,
/// `description` — человекочитаемое имя для UI (на cpal они совпадают).
#[derive(Clone, Debug)]
pub struct DeviceInfo {
    pub name: String,
    pub description: String,
    pub is_default: bool,
}

/// Перечислить выходные устройства. Ошибки → пустой список (пикер покажет «по
/// умолчанию»).
pub(crate) fn list_outputs() -> Vec<DeviceInfo> {
    #[cfg(target_os = "linux")]
    {
        list_pactl()
    }
    #[cfg(not(target_os = "linux"))]
    {
        list_cpal()
    }
}

/// Открыть выход: `Some(name)` — конкретное устройство, `None` — системное по
/// умолчанию. На Linux маршрутизация — через `pactl set-default-sink`, затем
/// открываем cpal-дефолт (он теперь указывает на выбранный синк).
pub(crate) fn open(name: Option<&str>) -> Result<MixerDeviceSink, AudioError> {
    #[cfg(target_os = "linux")]
    {
        if let Some(name) = name {
            let _ = std::process::Command::new("pactl")
                .args(["set-default-sink", name])
                .status();
        }
        build_sink(default_device()?)
    }
    #[cfg(not(target_os = "linux"))]
    {
        let device = match name.and_then(find_by_name) {
            Some(device) => device,
            None => default_device()?,
        };
        build_sink(device)
    }
}

fn default_device() -> Result<cpal::Device, AudioError> {
    use rodio::cpal::traits::HostTrait;
    cpal::default_host()
        .default_output_device()
        .ok_or_else(|| AudioError::Device("no default output device".into()))
}

/// Имя текущего системного выхода по умолчанию — для детекта смены дефолта ОС
/// (follow-default). На Linux источник — `pactl` (как и маршрутизация), иначе cpal.
#[cfg(target_os = "linux")]
pub(crate) fn default_output_name() -> Option<String> {
    let out = std::process::Command::new("pactl")
        .args(["get-default-sink"])
        .output()
        .ok()?;
    let name = String::from_utf8_lossy(&out.stdout).trim().to_owned();
    (!name.is_empty()).then_some(name)
}

#[cfg(not(target_os = "linux"))]
pub(crate) fn default_output_name() -> Option<String> {
    use rodio::cpal::traits::HostTrait;
    cpal::default_host()
        .default_output_device()
        .and_then(device_name)
}

fn build_sink(device: cpal::Device) -> Result<MixerDeviceSink, AudioError> {
    let mut sink = DeviceSinkBuilder::from_device(device)
        .map_err(|e| AudioError::Device(e.to_string()))?
        .open_stream()
        .map_err(|e| AudioError::Device(e.to_string()))?;
    sink.log_on_drop(false);
    Ok(sink)
}

#[cfg(target_os = "linux")]
fn list_pactl() -> Vec<DeviceInfo> {
    use std::process::Command;

    let output = match Command::new("pactl")
        .args(["--format=json", "list", "sinks"])
        .output()
    {
        Ok(out) if out.status.success() => out.stdout,
        _ => return Vec::new(),
    };
    let default = Command::new("pactl")
        .args(["get-default-sink"])
        .output()
        .ok()
        .map(|out| String::from_utf8_lossy(&out.stdout).trim().to_owned())
        .unwrap_or_default();

    let sinks: Vec<serde_json::Value> = serde_json::from_slice(&output).unwrap_or_default();
    sinks
        .iter()
        .filter_map(|sink| {
            let name = sink.get("name")?.as_str()?.to_owned();
            let description = sink
                .get("description")
                .and_then(|d| d.as_str())
                .unwrap_or(&name)
                .to_owned();
            Some(DeviceInfo {
                is_default: name == default,
                name,
                description,
            })
        })
        .collect()
}

#[cfg(not(target_os = "linux"))]
fn list_cpal() -> Vec<DeviceInfo> {
    use rodio::cpal::traits::HostTrait;

    let host = cpal::default_host();
    let default_name = host.default_output_device().and_then(device_name);
    let Ok(devices) = host.output_devices() else {
        return Vec::new();
    };
    devices
        .filter_map(|device| {
            let name = device_name(device)?;
            let is_default = Some(&name) == default_name.as_ref();
            Some(DeviceInfo {
                description: name.clone(),
                name,
                is_default,
            })
        })
        .collect()
}

#[cfg(not(target_os = "linux"))]
fn find_by_name(name: &str) -> Option<cpal::Device> {
    use rodio::cpal::traits::HostTrait;
    cpal::default_host()
        .output_devices()
        .ok()?
        .find(|device| device_name(device.clone()).as_deref() == Some(name))
}

/// Имя устройства (через `description` — `name()` помечен deprecated в cpal 0.17).
#[cfg(not(target_os = "linux"))]
fn device_name(device: cpal::Device) -> Option<String> {
    use rodio::cpal::traits::DeviceTrait;
    device.description().ok().map(|d| d.name().to_string())
}
