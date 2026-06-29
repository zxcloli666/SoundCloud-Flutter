use sc_domain::{
    AlbumCard, AlbumYearBucket, ArtistCard, CursorPage, DiscoverSummary, SpotlightItem, Tag,
};

use crate::client::{BffClient, enc};
use crate::dto::album::AlbumCardDto;
use crate::dto::artist::ArtistCardDto;
use crate::dto::discover::{DiscoverSummaryDto, SpotlightItemDto, SpotlightResponseDto, TagDto};
use crate::dto::envelope::ItemsEnvelope;
use crate::error::BffError;

impl BffClient {
    pub async fn discover_summary(&self) -> Result<DiscoverSummary, BffError> {
        let dto: DiscoverSummaryDto = self.get_json("/discover/summary").await?;
        Ok(dto.into_domain())
    }

    /// Каталог артистов — курсорная пагинация (`cursor` ↔ `next_cursor`).
    /// `sort` (popular/trending/...), `tag` и `q` опциональны.
    pub async fn discover_artists(
        &self,
        limit: u32,
        cursor: Option<&str>,
        sort: Option<&str>,
        tag: Option<&str>,
        q: Option<&str>,
    ) -> Result<CursorPage<ArtistCard>, BffError> {
        let mut path = format!("/discover/artists?limit={limit}");
        push_opt(&mut path, "cursor", cursor);
        push_opt(&mut path, "sort", sort);
        push_opt(&mut path, "tag", tag);
        push_opt(&mut path, "q", q);
        let env: ItemsEnvelope<ArtistCardDto> = self.get_json(&path).await?;
        Ok(CursorPage::new(
            env.items.into_iter().map(ArtistCardDto::into_domain).collect(),
            env.next_cursor,
        ))
    }

    /// Каталог альбомов — курсорная пагинация. `sort`, `kind` (album/single/ep)
    /// и `q` опциональны.
    pub async fn discover_albums(
        &self,
        limit: u32,
        cursor: Option<&str>,
        sort: Option<&str>,
        kind: Option<&str>,
        q: Option<&str>,
    ) -> Result<CursorPage<AlbumCard>, BffError> {
        let mut path = format!("/discover/albums?limit={limit}");
        push_opt(&mut path, "cursor", cursor);
        push_opt(&mut path, "sort", sort);
        push_opt(&mut path, "kind", kind);
        push_opt(&mut path, "q", q);
        let env: ItemsEnvelope<AlbumCardDto> = self.get_json(&path).await?;
        Ok(CursorPage::new(
            env.items.into_iter().map(AlbumCardDto::into_domain).collect(),
            env.next_cursor,
        ))
    }

    /// Альбомы, сгруппированные по годам (`/discover/albums/by-year`).
    pub async fn discover_albums_by_year(
        &self,
        years: u32,
        per_year: u32,
        kind: Option<&str>,
    ) -> Result<Vec<AlbumYearBucket>, BffError> {
        let mut path = format!("/discover/albums/by-year?years={years}&per_year={per_year}");
        push_opt(&mut path, "kind", kind);
        let dto: YearBucketsDto = self.get_json(&path).await?;
        Ok(dto.into_domain())
    }

    /// Случайный артефакт для «surprise me» (`/discover/random?type=`).
    /// `Ok(None)` если каталог пуст (404).
    pub async fn discover_random(&self, kind: Option<&str>) -> Result<Option<String>, BffError> {
        let mut path = String::from("/discover/random");
        if let Some(kind) = kind.filter(|v| !v.is_empty()) {
            path.push_str("?type=");
            path.push_str(&enc(kind));
        }
        let dto: Option<RandomDto> = self.get_optional(&path).await?;
        Ok(dto.map(|d| d.id))
    }

    pub async fn discover_tags(&self) -> Result<Vec<Tag>, BffError> {
        let env: ItemsEnvelope<TagDto> = self.get_json("/discover/tags").await?;
        Ok(env.items.into_iter().map(TagDto::into_domain).collect())
    }

    /// «В центре внимания» (`/discover/spotlight`) — курируемые карточки
    /// (артист|альбом), без пагинации. `limit` опционален.
    pub async fn discover_spotlight(
        &self,
        limit: Option<u32>,
    ) -> Result<Vec<SpotlightItem>, BffError> {
        let mut path = String::from("/discover/spotlight");
        if let Some(limit) = limit.filter(|v| *v > 0) {
            path.push_str("?limit=");
            path.push_str(&limit.to_string());
        }
        let dto: SpotlightResponseDto = self.get_json(&path).await?;
        Ok(dto.items.into_iter().map(SpotlightItemDto::into_domain).collect())
    }
}

fn push_opt(path: &mut String, key: &str, value: Option<&str>) {
    if let Some(value) = value.filter(|v| !v.is_empty()) {
        path.push('&');
        path.push_str(key);
        path.push('=');
        path.push_str(&enc(value));
    }
}

#[derive(serde::Deserialize)]
struct RandomDto {
    id: String,
}

#[derive(serde::Deserialize)]
struct YearBucketsDto {
    #[serde(default)]
    buckets: Vec<YearBucketDto>,
}

#[derive(serde::Deserialize)]
struct YearBucketDto {
    #[serde(default)]
    year: i32,
    #[serde(default)]
    items: Vec<AlbumCardDto>,
}

impl YearBucketsDto {
    fn into_domain(self) -> Vec<AlbumYearBucket> {
        self.buckets
            .into_iter()
            .map(|b| AlbumYearBucket {
                year: b.year,
                items: b.items.into_iter().map(AlbumCardDto::into_domain).collect(),
            })
            .collect()
    }
}
