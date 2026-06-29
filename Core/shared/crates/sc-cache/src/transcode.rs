//! Транскод в m4a через ffmpeg-sidecar. Блокирующий — вызывать в spawn_blocking.

use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicU64, Ordering};

use ffmpeg_sidecar::command::FfmpegCommand;

use crate::CacheError;
use crate::cache::has_ftyp_file;

/// Целевая громкость нормализации (LUFS), как у стриминговых сервисов. Все треки
/// приводятся к ней на транскоде — тихий и громкий звучат одинаково ровно, а
/// пользовательская громкость крутится уже поверх единого уровня.
const LOUDNORM_TARGET_LUFS: &str = "loudnorm=I=-14:TP=-1.5:LRA=11";

/// Привести вход к m4a/AAC через ffmpeg + нормализовать громкость к единому
/// уровню (EBU R128 loudnorm). ВСЕГДА перекодируем в AAC: stream-copy клал бы
/// исходный кодек (напр. MP3) в MP4-контейнер — ftyp есть, но rodio собран без
/// mp3-фичи и такое не декодит. Инвариант плеера = именно AAC-в-m4a.
pub(crate) fn to_m4a_blocking(input: &Path, output: &Path) -> Result<(), CacheError> {
    ensure_ffmpeg()?;
    // Пишем в УНИКАЛЬНЫЙ временный файл и только потом атомарно вносим на место.
    // Иначе убитый (rapid-клики) или конкурентный (два транскода на один путь)
    // ffmpeg оставил бы битый файл прямо на финальном пути — `ftyp` есть, но mdat
    // обрезан/перемешан → плеер давится «isomp4: overread atom». На финальном
    // пути появляется только полностью готовый и провалидированный файл.
    let tmp = temp_path(output);
    let result = run(input, &tmp).and_then(|()| {
        if has_ftyp_file(&tmp) {
            Ok(())
        } else {
            Err(CacheError::InvalidOutput)
        }
    });
    match result {
        Ok(()) => commit(&tmp, output),
        Err(e) => {
            let _ = std::fs::remove_file(&tmp);
            Err(e)
        }
    }
}

/// Уникальный временный путь рядом с целью (тот же каталог → rename атомарен).
/// Уникальность (pid + счётчик) разводит конкурентные транскоды одного трека.
fn temp_path(output: &Path) -> PathBuf {
    static SEQ: AtomicU64 = AtomicU64::new(0);
    let n = SEQ.fetch_add(1, Ordering::Relaxed);
    let mut name = output.as_os_str().to_owned();
    name.push(format!(".{}.{n}.part", std::process::id()));
    PathBuf::from(name)
}

/// Внести готовый файл на место атомарно: быстрый `rename`; при кросс-девайс
/// (tmp и кэш на разных ФС) — `copy` + удаление времянки.
fn commit(tmp: &Path, output: &Path) -> Result<(), CacheError> {
    if std::fs::rename(tmp, output).is_ok() {
        return Ok(());
    }
    let copied = std::fs::copy(tmp, output);
    let _ = std::fs::remove_file(tmp);
    copied
        .map(|_| ())
        .map_err(|e| CacheError::Io(e.to_string()))
}

fn run(input: &Path, output: &Path) -> Result<(), CacheError> {
    let mut command = FfmpegCommand::new();
    command
        .arg("-y")
        .input(input.to_string_lossy())
        .args(["-vn", "-map", "0:a:0?"])
        .args(["-af", LOUDNORM_TARGET_LUFS])
        .args(["-c:a", "aac", "-b:a", "256k"])
        // `-map_metadata -1` + `-bitexact` срезают udta/meta/encoder-теги: их
        // mp4-атомы тоже спотыкают демуксер symphonia на части файлов.
        .args(["-map_metadata", "-1"])
        .args(["-movflags", "+faststart", "-bitexact", "-f", "mp4"])
        .output(output.to_string_lossy());

    let mut child = command
        .spawn()
        .map_err(|e| CacheError::Transcode(e.to_string()))?;
    let status = child
        .wait()
        .map_err(|e| CacheError::Transcode(e.to_string()))?;
    if status.success() {
        Ok(())
    } else {
        Err(CacheError::Transcode("ffmpeg exited non-zero".into()))
    }
}

/// Достать рабочий ffmpeg: системный (на PATH / в известных местах) предпочтён —
/// бережёт загрузку; иначе качаем под целевую ОС. Зеркалит Tauri
/// `track_cache/transcode.rs::acquire_ffmpeg`. Идемпотентно — no-op если уже есть.
pub(crate) fn ensure_ffmpeg() -> Result<(), CacheError> {
    if ffmpeg_sidecar::command::ffmpeg_is_installed() {
        return Ok(());
    }
    ffmpeg_sidecar::download::auto_download().map_err(|e| CacheError::Transcode(e.to_string()))?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::cache::has_ftyp_file;

    /// Минимальный валидный WAV (PCM s16le mono 8kHz, тишина) — не mp4, форсит
    /// encode-ветку. Доказывает raw→m4a (ftyp на выходе).
    fn write_silence_wav(path: &Path) {
        let sample_rate = 8000u32;
        let samples = 4000usize; // 0.5s mono
        let data_len = (samples * 2) as u32;
        let mut buf = Vec::with_capacity(44 + data_len as usize);
        buf.extend_from_slice(b"RIFF");
        buf.extend_from_slice(&(36 + data_len).to_le_bytes());
        buf.extend_from_slice(b"WAVE");
        buf.extend_from_slice(b"fmt ");
        buf.extend_from_slice(&16u32.to_le_bytes());
        buf.extend_from_slice(&1u16.to_le_bytes()); // PCM
        buf.extend_from_slice(&1u16.to_le_bytes()); // mono
        buf.extend_from_slice(&sample_rate.to_le_bytes());
        buf.extend_from_slice(&(sample_rate * 2).to_le_bytes()); // byte rate
        buf.extend_from_slice(&2u16.to_le_bytes()); // block align
        buf.extend_from_slice(&16u16.to_le_bytes()); // bits
        buf.extend_from_slice(b"data");
        buf.extend_from_slice(&data_len.to_le_bytes());
        buf.extend(std::iter::repeat_n(0u8, data_len as usize));
        std::fs::write(path, buf).expect("write wav");
    }

    #[test]
    fn raw_wav_transcodes_to_m4a_with_ftyp() {
        // Скип если ffmpeg недоступен (offline CI) — иначе тест не про нас.
        if ensure_ffmpeg().is_err() {
            eprintln!("[smoke] ffmpeg unavailable — skipping transcode smoke");
            return;
        }
        let dir = std::env::temp_dir().join(format!("sc-cache-smoke-{}", std::process::id()));
        std::fs::create_dir_all(&dir).expect("mk smoke dir");
        let input = dir.join("in.wav");
        let output = dir.join("out.m4a");
        write_silence_wav(&input);

        to_m4a_blocking(&input, &output).expect("transcode raw→m4a");
        assert!(has_ftyp_file(&output), "transcoded output must be an mp4/m4a (ftyp)");

        let _ = std::fs::remove_dir_all(&dir);
    }
}
