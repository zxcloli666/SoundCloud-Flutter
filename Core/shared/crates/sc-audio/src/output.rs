//! Контроллер выходного устройства. cpal-устройство `!Send`, поэтому живёт на
//! выделенном потоке `audio-output`; этот тип — Send/Sync-ручка к нему. Умеет
//! переоткрыться на другое устройство, отдавая новый общий [`Mixer`].

use std::sync::mpsc::{Receiver, Sender, channel};

use rodio::mixer::Mixer;

use crate::AudioError;
use crate::device;

enum Cmd {
    Switch {
        device: Option<String>,
        reply: Sender<Result<Mixer, AudioError>>,
    },
}

pub(crate) struct Output {
    cmd_tx: Sender<Cmd>,
}

impl Output {
    /// Открыть устройство [`device`] (`None` — системное) и поднять поток-владелец.
    /// Возвращает ручку + начальный mixer.
    pub(crate) fn open(device: Option<String>) -> Result<(Self, Mixer), AudioError> {
        let (cmd_tx, cmd_rx) = channel();
        let (init_tx, init_rx) = channel();
        std::thread::Builder::new()
            .name("audio-output".into())
            .spawn(move || run(device, cmd_rx, init_tx))
            .map_err(|e| AudioError::Device(e.to_string()))?;
        let mixer = init_rx
            .recv()
            .map_err(|_| AudioError::Device("audio output thread exited".into()))??;
        Ok((Self { cmd_tx }, mixer))
    }

    /// Переключить вывод на [`device`] (`None` — системное). Блокирует до открытия
    /// нового устройства; при ошибке старое сохраняется. Отдаёт новый mixer.
    pub(crate) fn switch(&self, device: Option<String>) -> Result<Mixer, AudioError> {
        let (reply, reply_rx) = channel();
        self.cmd_tx
            .send(Cmd::Switch { device, reply })
            .map_err(|_| AudioError::Device("audio output thread gone".into()))?;
        reply_rx
            .recv()
            .map_err(|_| AudioError::Device("audio output thread gone".into()))?
    }
}

fn run(initial: Option<String>, cmd_rx: Receiver<Cmd>, init_tx: Sender<Result<Mixer, AudioError>>) {
    let mut sink = match device::open(initial.as_deref()) {
        Ok(sink) => sink,
        Err(error) => {
            let _ = init_tx.send(Err(error));
            return;
        }
    };
    if init_tx.send(Ok(sink.mixer().clone())).is_err() {
        return;
    }

    // Держим устройство живым и ждём переключений. Канал закрылся — движок ушёл,
    // выходим (cpal-устройство закрывается дропом `sink`).
    while let Ok(cmd) = cmd_rx.recv() {
        match cmd {
            Cmd::Switch { device: target, reply } => match device::open(target.as_deref()) {
                Ok(new_sink) => {
                    let mixer = new_sink.mixer().clone();
                    // Заменяем устройство; старое закрывается дропом (replace его читает).
                    drop(std::mem::replace(&mut sink, new_sink));
                    let _ = reply.send(Ok(mixer));
                }
                // Не удалось открыть выбранное — оставляем текущее, отдаём ошибку.
                Err(error) => {
                    let _ = reply.send(Err(error));
                }
            },
        }
    }
}
