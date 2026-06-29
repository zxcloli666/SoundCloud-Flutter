//! Мапперы домен→DTO: треки, артисты, альбомы, плейлисты. Сверху вниз: страница,
//! затем элемент. (Профиль/волна/каталог/история/лирика — в [`crate::map_misc`].)

use sc_domain::{
    AlbumArtist, AlbumCard, AlbumDetail, AlbumRef, AlbumYearBucket, ArtistCard, ArtistDetail,
    CursorPage, ListPage, PlaylistSummary, SpotlightItem, Track,
};

use crate::api::track_to_dto;
use crate::dto::{
    AlbumArtistDto, AlbumCardDto, AlbumCardPageDto, AlbumDetailDto, AlbumRefDto, ArtistCardDto,
    ArtistCardPageDto, ArtistDetailDto, PlaylistSummaryDto, PlaylistSummaryPageDto, RelatedArtistDto,
    ScAccountDto, SocialDto, TrackPageDto,
};
use crate::dto_social::{
    AlbumYearBucketDto, DiscoverAlbumsPageDto, DiscoverArtistsPageDto, SpotlightFeedDto,
    SpotlightItemDto,
};

pub(crate) fn track_page(page: ListPage<Track>) -> TrackPageDto {
    TrackPageDto {
        items: page.items.iter().map(track_to_dto).collect(),
        page: page.page,
        page_size: page.page_size,
        has_more: page.has_more,
    }
}

pub(crate) fn artist_card(c: ArtistCard) -> ArtistCardDto {
    ArtistCardDto {
        id: c.id,
        name: c.name,
        country: c.country,
        avatar_url: c.avatar_url,
        confidence: c.confidence,
        star: c.star,
        track_count_primary: c.track_count_primary,
        track_count_featured: c.track_count_featured,
        album_count: c.album_count,
        monthly_listeners: c.monthly_listeners,
        trending: c.trending,
        popularity: c.popularity,
        tags: c.tags,
        aura_id: c.aura_id,
        custom_hex: c.custom_hex,
    }
}

pub(crate) fn artist_card_page(page: ListPage<ArtistCard>) -> ArtistCardPageDto {
    ArtistCardPageDto {
        items: page.items.into_iter().map(artist_card).collect(),
        page: page.page,
        page_size: page.page_size,
        has_more: page.has_more,
    }
}

pub(crate) fn artist_detail(d: ArtistDetail) -> ArtistDetailDto {
    ArtistDetailDto {
        id: d.id,
        name: d.name,
        country: d.country,
        bio: d.bio,
        avatar_url: d.avatar_url,
        confidence: d.confidence,
        track_count: d.track_count,
        track_count_primary: d.track_count_primary,
        track_count_featured: d.track_count_featured,
        album_count: d.album_count,
        socials: d
            .socials
            .into_iter()
            .map(|s| SocialDto {
                kind: s.kind,
                url: s.url,
                source: s.source,
                verified: s.verified,
            })
            .collect(),
        sc_accounts: d
            .sc_accounts
            .into_iter()
            .map(|a| ScAccountDto {
                sc_user_id: a.sc_user_id,
                role: a.role,
                source: a.source,
                verified: a.verified,
            })
            .collect(),
        related_artists: d
            .related_artists
            .into_iter()
            .map(|r| RelatedArtistDto {
                id: r.id,
                name: r.name,
                country: r.country,
                avatar_url: r.avatar_url,
                weight: r.weight,
            })
            .collect(),
        popular_tracks: d.popular_tracks.iter().map(track_to_dto).collect(),
    }
}

fn album_artist(a: AlbumArtist) -> AlbumArtistDto {
    AlbumArtistDto {
        id: a.id,
        name: a.name,
        role: a.role,
        avatar_url: a.avatar_url,
    }
}

pub(crate) fn album_card(c: AlbumCard) -> AlbumCardDto {
    AlbumCardDto {
        id: c.id,
        title: c.title,
        release_year: c.release_year,
        release_month: c.release_month,
        cover_url: c.cover_url,
        confidence: c.confidence,
        track_count: c.track_count,
        total_duration_ms: c.total_duration_ms,
        popularity: c.popularity,
        star: c.star,
        primary_artist: album_artist(c.primary_artist),
    }
}

pub(crate) fn album_card_page(page: ListPage<AlbumCard>) -> AlbumCardPageDto {
    AlbumCardPageDto {
        items: page.items.into_iter().map(album_card).collect(),
        page: page.page,
        page_size: page.page_size,
        has_more: page.has_more,
    }
}

pub(crate) fn album_ref(r: AlbumRef) -> AlbumRefDto {
    AlbumRefDto {
        id: r.id,
        title: r.title,
        release_year: r.release_year,
        role: r.role,
    }
}

pub(crate) fn album_year_bucket(b: AlbumYearBucket) -> AlbumYearBucketDto {
    AlbumYearBucketDto {
        year: b.year,
        items: b.items.into_iter().map(album_card).collect(),
    }
}

pub(crate) fn discover_artists_page(page: CursorPage<ArtistCard>) -> DiscoverArtistsPageDto {
    DiscoverArtistsPageDto {
        items: page.items.into_iter().map(artist_card).collect(),
        next_cursor: page.next_cursor,
    }
}

pub(crate) fn discover_albums_page(page: CursorPage<AlbumCard>) -> DiscoverAlbumsPageDto {
    DiscoverAlbumsPageDto {
        items: page.items.into_iter().map(album_card).collect(),
        next_cursor: page.next_cursor,
    }
}

pub(crate) fn spotlight_feed(items: Vec<SpotlightItem>) -> SpotlightFeedDto {
    SpotlightFeedDto {
        items: items.into_iter().map(spotlight_item).collect(),
    }
}

fn spotlight_item(item: SpotlightItem) -> SpotlightItemDto {
    match item {
        SpotlightItem::Artist(a) => SpotlightItemDto::Artist(artist_card(a)),
        SpotlightItem::Album(a) => SpotlightItemDto::Album(album_card(a)),
    }
}

pub(crate) fn album_detail(d: AlbumDetail) -> AlbumDetailDto {
    AlbumDetailDto {
        id: d.id,
        title: d.title,
        release_year: d.release_year,
        cover_url: d.cover_url,
        confidence: d.confidence,
        primary_artist: album_artist(d.primary_artist),
        artists: d.artists.into_iter().map(album_artist).collect(),
        tracks: d.tracks.iter().map(track_to_dto).collect(),
    }
}

pub(crate) fn playlist_summary(p: PlaylistSummary) -> PlaylistSummaryDto {
    let owner = p.owner;
    PlaylistSummaryDto {
        urn: p.id.as_str().to_owned(),
        title: p.title,
        artwork_url: p.artwork_url,
        is_album: p.is_album,
        track_count: p.track_count,
        duration_ms: p.duration_ms,
        likes_count: p.likes_count,
        reposts_count: p.reposts_count,
        permalink_url: p.permalink_url,
        created_at: p.created_at,
        release_year: p.release_year,
        owner_id: owner.as_ref().map(|o| o.id.as_str().to_owned()),
        owner_username: owner.as_ref().map(|o| o.username.clone()),
        owner_avatar_url: owner.as_ref().and_then(|o| o.avatar_url.clone()),
        user_favorite: p.user_favorite,
        description: p.description,
        last_modified: p.last_modified,
        kind: p.kind,
    }
}

pub(crate) fn playlist_summary_page(page: ListPage<PlaylistSummary>) -> PlaylistSummaryPageDto {
    PlaylistSummaryPageDto {
        items: page.items.into_iter().map(playlist_summary).collect(),
        page: page.page,
        page_size: page.page_size,
        has_more: page.has_more,
    }
}
