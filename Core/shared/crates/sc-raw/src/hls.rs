//! Скачивание потоков: progressive (один GET) и HLS (init + конкатенация
//! сегментов). Повторы на уровне сегмента не делаем — это слой `sc-cache`/выше.
//! Оба пути отдают прогресс скачки (доля 0..1): progressive — по байтам тела,
//! HLS — по доле скачанных сегментов.

use bytes::{BufMut, Bytes, BytesMut};
use futures::StreamExt;

use sc_net::{HttpRequest, NetClient, NetStream, RetryPolicy};

use crate::Progress;
use crate::error::RawError;

pub(crate) async fn download_progressive(
    net: &NetClient,
    url: &str,
    progress: Option<Progress<'_>>,
) -> Result<Bytes, RawError> {
    let stream = net.download(HttpRequest::get(url.to_owned())).await?;
    collect(stream, progress).await
}

pub(crate) async fn download_hls_full(
    net: &NetClient,
    m3u8_url: &str,
    progress: Option<Progress<'_>>,
) -> Result<Bytes, RawError> {
    let resp = net.request(HttpRequest::get(m3u8_url)).await?;
    if !resp.is_success() {
        return Err(RawError::Stream(format!("m3u8 {}", resp.status)));
    }
    let playlist = String::from_utf8_lossy(&resp.body);
    let segments = parse_m3u8(&playlist);
    if segments.is_empty() {
        return Err(RawError::Stream("empty m3u8".into()));
    }

    let total = segments.len();
    let mut buffer = BytesMut::new();
    for (index, segment) in segments.into_iter().enumerate() {
        let resp = net
            .request_with(HttpRequest::get(&segment), &RetryPolicy::none())
            .await?;
        if !resp.is_success() {
            return Err(RawError::Stream(format!("segment {}", resp.status)));
        }
        buffer.put(resp.body);
        if let Some(report) = progress {
            report((index + 1) as f64 / total as f64);
        }
    }
    Ok(buffer.freeze())
}

/// Слить тело потока в байты, отдавая долю по `content-length` (если известна).
async fn collect(stream: NetStream, progress: Option<Progress<'_>>) -> Result<Bytes, RawError> {
    let total = stream.content_length.unwrap_or(0);
    let mut body = stream.body;
    let mut buffer = BytesMut::new();
    let mut downloaded = 0u64;
    while let Some(chunk) = body.next().await {
        let chunk = chunk?;
        downloaded += chunk.len() as u64;
        buffer.put(chunk);
        if let Some(report) = progress {
            if total > 0 {
                report((downloaded as f64 / total as f64).clamp(0.0, 1.0));
            }
        }
    }
    if buffer.is_empty() {
        return Err(RawError::Stream("progressive empty body".into()));
    }
    Ok(buffer.freeze())
}

/// URL init-сегмента (`#EXT-X-MAP`) + URL медиасегментов в порядке плейлиста.
fn parse_m3u8(content: &str) -> Vec<String> {
    let mut urls = Vec::new();
    for line in content.lines() {
        let line = line.trim();
        if line.is_empty() {
            continue;
        }
        if let Some(rest) = line.strip_prefix("#EXT-X-MAP:") {
            if let Some(uri) = extract_uri(rest) {
                urls.push(uri);
            }
            continue;
        }
        if line.starts_with('#') {
            continue;
        }
        urls.push(line.to_owned());
    }
    urls
}

fn extract_uri(attrs: &str) -> Option<String> {
    let key = "URI=\"";
    let start = attrs.find(key)? + key.len();
    let end = attrs[start..].find('"')? + start;
    Some(attrs[start..end].to_owned())
}
