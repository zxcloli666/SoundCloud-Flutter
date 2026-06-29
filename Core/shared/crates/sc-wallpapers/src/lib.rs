//! Поиск онлайн-обоев (Wallhaven / Pinterest / Konachan / Safebooru) поверх
//! [`sc-net`](../sc_net). В Rust, потому что Wallhaven/Konachan отдают 403 на
//! не-браузерный `User-Agent`. Запросы **анонимные** (не светим `x-session-id`
//! на чужие сайты) и идут через наш транспорт — значит роутинг/пробив DPI
//! работают (важно для заблокированных в РФ источников). Чужой JSON не доверяем —
//! каждое поле защищено. Пагинация унифицирована непрозрачным `cursor`.

use std::sync::Arc;

use sc_net::{HttpRequest, NetClient};
use serde_json::Value;

mod store;
pub use store::WallpaperStore;

pub(crate) const BROWSER_UA: &str =
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36";
const BOORU_LIMIT: usize = 24;
const PINTEREST_PAGE: u32 = 25;

#[derive(Debug, thiserror::Error)]
pub enum WallpaperError {
    #[error(transparent)]
    Net(#[from] sc_net::NetError),
    #[error("http {0}")]
    Http(u16),
    #[error("decode: {0}")]
    Decode(String),
}

/// Параметры поиска (источник + запрос + опции).
#[derive(Clone, Debug, Default)]
pub struct WallpaperQuery {
    pub source: String,
    pub query: String,
    pub category: Option<String>,
    pub color: Option<String>,
    pub cursor: Option<String>,
    pub adult: bool,
    pub api_key: Option<String>,
}

#[derive(Clone, Debug)]
pub struct WallpaperHit {
    pub id: String,
    pub thumb: String,
    pub full: String,
    pub resolution: String,
}

#[derive(Clone, Debug)]
pub struct WallpaperPage {
    pub items: Vec<WallpaperHit>,
    pub cursor: Option<String>,
}

/// Клиент поиска обоев поверх [`NetClient`].
pub struct WallpaperClient {
    net: Arc<NetClient>,
}

impl WallpaperClient {
    pub fn new(net: Arc<NetClient>) -> Self {
        Self { net }
    }

    pub async fn search(&self, q: &WallpaperQuery) -> Result<WallpaperPage, WallpaperError> {
        match q.source.as_str() {
            "pinterest" => self.pinterest(q).await,
            "konachan" => self.konachan(q).await,
            "safebooru" => self.safebooru(q).await,
            _ => self.wallhaven(q).await,
        }
    }

    async fn get_json(&self, url: String, extra: &[(&str, &str)]) -> Result<Value, WallpaperError> {
        let mut req = HttpRequest::get(url)
            .header("User-Agent", BROWSER_UA)
            .header("Accept", "application/json");
        for (k, v) in extra {
            req = req.header(*k, *v);
        }
        let resp = self.net.request(req).await?;
        if !resp.is_success() {
            return Err(WallpaperError::Http(resp.status));
        }
        serde_json::from_slice(&resp.body).map_err(|e| WallpaperError::Decode(e.to_string()))
    }

    async fn wallhaven(&self, a: &WallpaperQuery) -> Result<WallpaperPage, WallpaperError> {
        let page = page_from_cursor(&a.cursor);
        let cat = match a.category.as_deref() {
            Some("general") => "100",
            Some("people") => "001",
            _ => "010",
        };
        let key = a.api_key.as_deref().map(str::trim).filter(|k| !k.is_empty());
        let purity = if a.adult && key.is_some() { "111" } else { "100" };
        let query = a.query.trim();
        let color = a
            .color
            .as_deref()
            .map(|c| c.trim_start_matches('#'))
            .filter(|c| !c.is_empty());
        let sorting = if !query.is_empty() || color.is_some() {
            "relevance"
        } else {
            "toplist"
        };
        let mut params = vec![
            ("categories", cat.to_owned()),
            ("purity", purity.to_owned()),
            ("atleast", "1920x1080".to_owned()),
            ("sorting", sorting.to_owned()),
            ("page", page.to_string()),
        ];
        if !query.is_empty() {
            params.push(("q", query.to_owned()));
        }
        if let Some(k) = key {
            params.push(("apikey", k.to_owned()));
        }
        if let Some(c) = color {
            params.push(("colors", c.to_owned()));
        }

        let json = self
            .get_json(url_with("https://wallhaven.cc/api/v1/search", &params), &[])
            .await?;

        let mut items = Vec::new();
        if let Some(data) = json.get("data").and_then(Value::as_array) {
            for d in data {
                let full = s(d, "path");
                if full.is_empty() {
                    continue;
                }
                let thumb = match d.get("thumbs") {
                    Some(t) => first_nonempty(&[s(t, "small"), s(t, "large"), full.clone()]),
                    None => full.clone(),
                };
                items.push(WallpaperHit {
                    id: id_of(d, &full),
                    thumb,
                    full,
                    resolution: s(d, "resolution"),
                });
            }
        }
        let last = json
            .get("meta")
            .and_then(|m| m.get("last_page"))
            .and_then(Value::as_u64)
            .unwrap_or(0);
        let cursor = ((page as u64) < last).then(|| (page + 1).to_string());
        Ok(WallpaperPage { items, cursor })
    }

    async fn konachan(&self, a: &WallpaperQuery) -> Result<WallpaperPage, WallpaperError> {
        let page = page_from_cursor(&a.cursor);
        let mut tags = tags_of(&a.query);
        if !a.adult {
            tags.push("rating:safe".to_owned());
        }
        if tags.is_empty() || (tags.len() == 1 && tags[0] == "rating:safe") {
            tags.push("order:score".to_owned());
        }
        let json = self
            .get_json(
                url_with(
                    "https://konachan.com/post.json",
                    &[
                        ("limit", BOORU_LIMIT.to_string()),
                        ("page", page.to_string()),
                        ("tags", tags.join(" ")),
                    ],
                ),
                &[],
            )
            .await?;
        let mut items = Vec::new();
        if let Some(arr) = json.as_array() {
            for d in arr {
                let full = first_nonempty(&[s(d, "file_url"), s(d, "jpeg_url"), s(d, "sample_url")]);
                if full.is_empty() {
                    continue;
                }
                let thumb = first_nonempty(&[s(d, "preview_url"), s(d, "sample_url"), full.clone()]);
                items.push(WallpaperHit {
                    id: id_of(d, &full),
                    thumb,
                    resolution: dims(d),
                    full,
                });
            }
        }
        let cursor = next_booru_cursor(items.len(), page);
        Ok(WallpaperPage { items, cursor })
    }

    async fn safebooru(&self, a: &WallpaperQuery) -> Result<WallpaperPage, WallpaperError> {
        let page = page_from_cursor(&a.cursor);
        let mut tags = tags_of(&a.query);
        if tags.is_empty() {
            tags.push("sort:score:desc".to_owned());
        }
        let json = self
            .get_json(
                url_with(
                    "https://safebooru.org/index.php",
                    &[
                        ("page", "dapi".to_owned()),
                        ("s", "post".to_owned()),
                        ("q", "index".to_owned()),
                        ("json", "1".to_owned()),
                        ("limit", BOORU_LIMIT.to_string()),
                        ("pid", (page - 1).to_string()),
                        ("tags", tags.join(" ")),
                    ],
                ),
                &[],
            )
            .await?;
        let empty: Vec<Value> = Vec::new();
        let arr = json
            .as_array()
            .or_else(|| json.get("post").and_then(Value::as_array))
            .unwrap_or(&empty);
        let mut items = Vec::new();
        for d in arr {
            let full = first_nonempty(&[s(d, "file_url"), s(d, "sample_url")]);
            if full.is_empty() {
                continue;
            }
            let thumb = first_nonempty(&[s(d, "preview_url"), s(d, "sample_url"), full.clone()]);
            items.push(WallpaperHit {
                id: id_of(d, &full),
                thumb,
                resolution: dims(d),
                full,
            });
        }
        let cursor = next_booru_cursor(items.len(), page);
        Ok(WallpaperPage { items, cursor })
    }

    async fn pinterest(&self, a: &WallpaperQuery) -> Result<WallpaperPage, WallpaperError> {
        let q = a.query.trim();
        let query = if q.is_empty() { "wallpaper" } else { q };
        let mut options =
            serde_json::json!({ "query": query, "scope": "pins", "page_size": PINTEREST_PAGE });
        if let Some(bm) = a.cursor.as_deref().filter(|c| !c.is_empty()) {
            options["bookmarks"] = serde_json::json!([bm]);
        }
        let data = serde_json::json!({ "options": options, "context": {} }).to_string();
        let source = format!("/search/pins/?q={query}");
        let json = self
            .get_json(
                url_with(
                    "https://www.pinterest.com/resource/BaseSearchResource/get/",
                    &[("source_url", source), ("data", data)],
                ),
                &[("x-pinterest-pws-handler", "www/search/[scope].js")],
            )
            .await?;
        let rr = json.get("resource_response");
        let data = rr.and_then(|r| r.get("data"));
        let results = data
            .and_then(Value::as_array)
            .or_else(|| data.and_then(|d| d.get("results")).and_then(Value::as_array));
        let mut items = Vec::new();
        if let Some(arr) = results {
            for r in arr {
                let imgs = r.get("images");
                let orig = imgs.and_then(|i| i.get("orig"));
                let full = orig.map(|o| s(o, "url")).unwrap_or_default();
                if full.is_empty() {
                    continue;
                }
                let t474 = imgs.and_then(|i| i.get("474x")).map(|o| s(o, "url")).unwrap_or_default();
                let t236 = imgs.and_then(|i| i.get("236x")).map(|o| s(o, "url")).unwrap_or_default();
                let thumb = first_nonempty(&[t474, t236, full.clone()]);
                let resolution = orig.map(dims).unwrap_or_default();
                items.push(WallpaperHit {
                    id: id_of(r, &full),
                    thumb,
                    full,
                    resolution,
                });
            }
        }
        let bm = rr.map(|r| s(r, "bookmark")).unwrap_or_default();
        let cursor = (!items.is_empty() && !bm.is_empty() && bm != "-end-").then_some(bm);
        Ok(WallpaperPage { items, cursor })
    }
}

fn url_with(base: &str, params: &[(&str, String)]) -> String {
    let mut url = String::from(base);
    for (i, (k, v)) in params.iter().enumerate() {
        url.push(if i == 0 { '?' } else { '&' });
        url.push_str(k);
        url.push('=');
        url.push_str(&urlencoding::encode(v));
    }
    url
}

fn s(v: &Value, key: &str) -> String {
    v.get(key).and_then(Value::as_str).unwrap_or("").to_owned()
}

fn first_nonempty(opts: &[String]) -> String {
    opts.iter().find(|s| !s.is_empty()).cloned().unwrap_or_default()
}

fn id_of(v: &Value, fallback: &str) -> String {
    match v.get("id") {
        Some(Value::String(s)) => s.clone(),
        Some(Value::Number(n)) => n.to_string(),
        _ => fallback.to_owned(),
    }
}

fn dims(v: &Value) -> String {
    let w = v.get("width").and_then(Value::as_u64).unwrap_or(0);
    let h = v.get("height").and_then(Value::as_u64).unwrap_or(0);
    if w > 0 && h > 0 {
        format!("{w}x{h}")
    } else {
        String::new()
    }
}

fn page_from_cursor(c: &Option<String>) -> u32 {
    c.as_deref()
        .and_then(|s| s.parse::<u32>().ok())
        .filter(|n| *n >= 1)
        .unwrap_or(1)
}

fn next_booru_cursor(count: usize, page: u32) -> Option<String> {
    (count >= BOORU_LIMIT).then(|| (page + 1).to_string())
}

fn tags_of(query: &str) -> Vec<String> {
    query.split_whitespace().map(|t| t.to_owned()).collect()
}
