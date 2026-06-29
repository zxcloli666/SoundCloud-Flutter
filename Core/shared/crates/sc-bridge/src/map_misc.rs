//! Мапперы домен→DTO: профиль, волна, каталог, потоки, история, лирика,
//! редакционный пик, авторизация. (Треки/артисты/альбомы/плейлисты — в
//! [`crate::map`].)

use sc_domain::{
    ArtistStar, Aura, AuthStatus, CacheEntry, Cluster, Comment, DiscoverSummary, Featured,
    FeaturedPick, HistoryEntry, HistoryPage, LinkClaim, LinkCreate, LinkStatus, LoginStart,
    LoginStatus, LyricLine, Lyrics, Me, Tag, TrackStreams, User, Wave, WebProfile,
};

use crate::api::track_to_dto;
use crate::dto::{
    AuthStatusDto, ClusterDto, ClusterNeighborDto, CommentDto, CommentPageDto, DiscoverSummaryDto, FeaturedDto,
    HistoryEntryDto, HistoryPageDto, LinkClaimDto, LinkCreateDto, LinkStatusDto, LoginStartDto,
    LoginStatusDto, LyricLineDto, LyricsDto, MeDto, TagDto, TrackStreamsDto, UserDto, UserPageDto,
    WaveDto, WaveItemDto,
};
use crate::dto_social::{
    ArtistStarDto, AuraDto, CacheEntryDto, WallpaperHitDto, WallpaperPageDto, WebProfileDto,
};
use sc_core::{WallpaperHit, WallpaperPage};
use crate::map::playlist_summary;
use sc_domain::ListPage;

pub(crate) fn user(u: User) -> UserDto {
    UserDto {
        urn: u.id.as_str().to_owned(),
        username: u.username,
        permalink: u.permalink,
        permalink_url: u.permalink_url,
        avatar_url: u.avatar_url,
        full_name: u.full_name,
        city: u.city,
        country_code: u.country_code,
        description: u.description,
        verified: u.verified,
        followers_count: u.followers_count,
        followings_count: u.followings_count,
        track_count: u.track_count,
        playlist_count: u.playlist_count,
        public_favorites_count: u.public_favorites_count,
        plan: u.plan,
        created_at: u.created_at,
    }
}

pub(crate) fn user_page(page: ListPage<User>) -> UserPageDto {
    UserPageDto {
        items: page.items.into_iter().map(user).collect(),
        page: page.page,
        page_size: page.page_size,
        has_more: page.has_more,
    }
}

pub(crate) fn comment(c: Comment) -> CommentDto {
    CommentDto {
        id: c.id,
        body: c.body,
        timestamp_ms: c.timestamp_ms,
        created_at: c.created_at,
        user_urn: c.user.id.as_str().to_owned(),
        username: c.user.username,
        avatar_url: c.user.avatar_url,
        permalink_url: c.user.permalink_url,
    }
}

pub(crate) fn comment_page(page: ListPage<Comment>) -> CommentPageDto {
    CommentPageDto {
        items: page.items.into_iter().map(comment).collect(),
        page: page.page,
        page_size: page.page_size,
        has_more: page.has_more,
    }
}

pub(crate) fn me(m: Me) -> MeDto {
    MeDto {
        urn: m.id.as_str().to_owned(),
        username: m.username,
        permalink: m.permalink,
        permalink_url: m.permalink_url,
        avatar_url: m.avatar_url,
        plan: m.plan,
        premium: m.premium,
        followers_count: m.followers_count,
        followings_count: m.followings_count,
        public_favorites_count: m.public_favorites_count,
        private_playlists_count: m.private_playlists_count,
        playlist_count: m.playlist_count,
    }
}

pub(crate) fn cluster(c: Cluster) -> ClusterDto {
    ClusterDto {
        id: c.id,
        track_ids: c.track_ids,
        neighbors: c
            .neighbors
            .into_iter()
            .map(|n| ClusterNeighborDto {
                artist_id: n.artist_id,
                artist_name: n.artist_name,
                avatar_url: n.avatar_url,
                track_id: n.track_id,
            })
            .collect(),
    }
}

pub(crate) fn wave(w: Wave) -> WaveDto {
    WaveDto {
        items: w
            .items
            .into_iter()
            .map(|i| WaveItemDto {
                id: i.id,
                score: i.score,
            })
            .collect(),
        cursor: w.cursor,
    }
}

pub(crate) fn discover_summary(s: DiscoverSummary) -> DiscoverSummaryDto {
    DiscoverSummaryDto {
        artists_count: s.artists_count,
        albums_count: s.albums_count,
        fresh_count: s.fresh_count,
        fresh_window_days: s.fresh_window_days,
    }
}

pub(crate) fn tag(t: Tag) -> TagDto {
    TagDto {
        id: t.id,
        label: t.label,
        count: t.count,
    }
}

pub(crate) fn track_streams(s: TrackStreams) -> TrackStreamsDto {
    TrackStreamsDto {
        hls_aac_160_url: s.hls_aac_160_url,
        hls_mp3_128_url: s.hls_mp3_128_url,
        http_mp3_128_url: s.http_mp3_128_url,
        preview_mp3_128_url: s.preview_mp3_128_url,
    }
}

fn history_entry(e: HistoryEntry) -> HistoryEntryDto {
    HistoryEntryDto {
        id: e.id,
        sc_track_id: e.sc_track_id,
        title: e.title,
        artist_name: e.artist_name,
        artist_urn: e.artist_urn,
        artwork_url: e.artwork_url,
        duration_ms: e.duration_ms,
        played_at: e.played_at,
    }
}

pub(crate) fn history_page(p: HistoryPage) -> HistoryPageDto {
    HistoryPageDto {
        items: p.items.into_iter().map(history_entry).collect(),
        total: p.total,
    }
}

fn lyric_line(l: LyricLine) -> LyricLineDto {
    LyricLineDto {
        at_ms: l.at_ms,
        text: l.text,
    }
}

pub(crate) fn lyrics(l: Lyrics) -> LyricsDto {
    LyricsDto {
        synced: l.synced,
        source: l.source,
        lines: l.lines.into_iter().map(lyric_line).collect(),
    }
}

pub(crate) fn featured(f: Featured) -> FeaturedDto {
    let (track, playlist) = match f.pick {
        FeaturedPick::Track(t) => (Some(track_to_dto(&t)), None),
        FeaturedPick::Playlist(p) => (None, Some(playlist_summary(*p))),
        FeaturedPick::Unknown => (None, None),
    };
    FeaturedDto {
        kind: f.kind,
        track,
        playlist,
    }
}

pub(crate) fn auth_status(s: AuthStatus) -> AuthStatusDto {
    AuthStatusDto {
        has_session: s.has_session,
        authenticated: s.authenticated,
        session_id: s.session_id,
        username: s.username,
        token_state: s.token_state,
    }
}

pub(crate) fn login_start(s: LoginStart) -> LoginStartDto {
    LoginStartDto {
        url: s.url,
        login_request_id: s.login_request_id,
    }
}

pub(crate) fn login_status(s: LoginStatus) -> LoginStatusDto {
    LoginStatusDto {
        status: s.status,
        step: s.step,
        session_id: s.session_id,
        username: s.username,
        error: s.error,
        redirect_url: s.redirect_url,
    }
}

pub(crate) fn artist_star(s: ArtistStar) -> ArtistStarDto {
    ArtistStarDto {
        premium: s.premium,
        aura_id: s.aura_id,
        custom_hex: s.custom_hex,
        source_sc_user_id: s.source_sc_user_id,
    }
}

pub(crate) fn aura(a: Aura) -> AuraDto {
    AuraDto {
        aura_id: a.aura_id,
        custom_hex: a.custom_hex,
    }
}

pub(crate) fn web_profile(p: WebProfile) -> WebProfileDto {
    WebProfileDto {
        network: p.network,
        title: p.title,
        url: p.url,
        username: p.username,
    }
}

pub(crate) fn link_create(l: LinkCreate) -> LinkCreateDto {
    LinkCreateDto {
        link_request_id: l.link_request_id,
        claim_token: l.claim_token,
        mode: l.mode,
        payload: l.payload,
        expires_at: l.expires_at,
    }
}

pub(crate) fn link_status(l: LinkStatus) -> LinkStatusDto {
    LinkStatusDto {
        status: l.status,
        mode: l.mode,
        session_id: l.session_id,
        error: l.error,
    }
}

pub(crate) fn link_claim(l: LinkClaim) -> LinkClaimDto {
    LinkClaimDto {
        session_id: l.session_id,
        mode: l.mode,
    }
}

pub(crate) fn lyric_hit_page(page: ListPage<sc_domain::LyricHit>) -> crate::dto_social::LyricHitPageDto {
    crate::dto_social::LyricHitPageDto {
        items: page
            .items
            .into_iter()
            .map(|h| crate::dto_social::LyricHitDto {
                track: track_to_dto(&h.track),
                matched_line: h.matched_line,
            })
            .collect(),
        page: page.page,
        page_size: page.page_size,
        has_more: page.has_more,
    }
}

pub(crate) fn cache_entry(e: CacheEntry) -> CacheEntryDto {
    CacheEntryDto {
        urn: e.urn.as_str().to_owned(),
        sc_id: e.sc_id,
        bytes: e.bytes,
    }
}

fn wallpaper_hit(h: WallpaperHit) -> WallpaperHitDto {
    WallpaperHitDto {
        id: h.id,
        thumb: h.thumb,
        full: h.full,
        resolution: h.resolution,
    }
}

pub(crate) fn wallpaper_page(p: WallpaperPage) -> WallpaperPageDto {
    WallpaperPageDto {
        items: p.items.into_iter().map(wallpaper_hit).collect(),
        cursor: p.cursor,
    }
}
