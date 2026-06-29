//! Слой данных рантайма: тонкие пасс-тру к [`sc_bff::BffClient`]. Возвращают
//! доменные типы `sc-domain`, `BffError` маппится в [`CoreError`] через `?`.

use sc_domain::{
    AlbumCard, AlbumDetail, AlbumRef, AlbumYearBucket, ArtistCard, ArtistDetail, Cluster,
    Comment, CursorPage, DiscoverSummary, Featured, HistoryPage, ListPage, Lyrics, Me,
    PlaylistDetail, PlaylistSummary, SpotlightItem, Tag, Track, TrackStreams, Urn, User, Wave,
};

use crate::{CoreError, ScRuntime};

impl ScRuntime {
    // --- поиск ---

    pub async fn search_artists(
        &self,
        query: &str,
        limit: u32,
        offset: u32,
    ) -> Result<ListPage<ArtistCard>, CoreError> {
        Ok(self.bff().search_artists(query, limit, offset).await?)
    }

    pub async fn search_albums(
        &self,
        query: &str,
        limit: u32,
        offset: u32,
    ) -> Result<ListPage<AlbumCard>, CoreError> {
        Ok(self.bff().search_albums(query, limit, offset).await?)
    }

    pub async fn search_playlists(
        &self,
        query: &str,
        limit: u32,
        offset: u32,
    ) -> Result<ListPage<PlaylistSummary>, CoreError> {
        Ok(self.bff().search_playlists(query, limit, offset).await?)
    }

    pub async fn search_users(
        &self,
        query: &str,
        limit: u32,
        offset: u32,
    ) -> Result<ListPage<User>, CoreError> {
        Ok(self.bff().search_users(query, limit, offset).await?)
    }

    // --- треки ---

    pub async fn track_related(&self, urn: &Urn, limit: u32) -> Result<ListPage<Track>, CoreError> {
        Ok(self.bff().track_related(urn, limit).await?)
    }

    pub async fn track_streams(&self, urn: &Urn) -> Result<TrackStreams, CoreError> {
        Ok(self.bff().track_streams(urn).await?)
    }

    pub async fn track_comments(
        &self,
        urn: &Urn,
        limit: u32,
        offset: u32,
    ) -> Result<ListPage<Comment>, CoreError> {
        Ok(self.bff().track_comments(urn, limit, offset).await?)
    }

    pub async fn post_comment(
        &self,
        urn: &Urn,
        body: &str,
        timestamp_ms: Option<i64>,
    ) -> Result<Comment, CoreError> {
        Ok(self.bff().post_comment(urn, body, timestamp_ms).await?)
    }

    // --- дом/волна ---

    pub async fn home_clusters(
        &self,
        limit: u32,
        languages: &[String],
        hide_listened: bool,
    ) -> Result<Vec<Cluster>, CoreError> {
        Ok(self
            .bff()
            .home_clusters(limit, languages, hide_listened)
            .await?)
    }

    pub async fn wave(
        &self,
        limit: u32,
        cursor: Option<&str>,
        languages: &[String],
        hide_listened: bool,
    ) -> Result<Wave, CoreError> {
        Ok(self.bff().wave(limit, cursor, languages, hide_listened).await?)
    }

    pub async fn recommendations_feedback(
        &self,
        cluster_id: &str,
        kind: &str,
    ) -> Result<(), CoreError> {
        Ok(self.bff().recommendations_feedback(cluster_id, kind).await?)
    }

    pub async fn wave_feedback(
        &self,
        cursor: &str,
        negatives: u32,
        positives: u32,
    ) -> Result<Option<String>, CoreError> {
        Ok(self.bff().wave_feedback(cursor, negatives, positives).await?)
    }

    // --- каталог ---

    pub async fn discover_summary(&self) -> Result<DiscoverSummary, CoreError> {
        Ok(self.bff().discover_summary().await?)
    }

    pub async fn discover_artists(
        &self,
        limit: u32,
        cursor: Option<&str>,
        sort: Option<&str>,
        tag: Option<&str>,
        q: Option<&str>,
    ) -> Result<CursorPage<ArtistCard>, CoreError> {
        Ok(self.bff().discover_artists(limit, cursor, sort, tag, q).await?)
    }

    pub async fn discover_albums(
        &self,
        limit: u32,
        cursor: Option<&str>,
        sort: Option<&str>,
        kind: Option<&str>,
        q: Option<&str>,
    ) -> Result<CursorPage<AlbumCard>, CoreError> {
        Ok(self.bff().discover_albums(limit, cursor, sort, kind, q).await?)
    }

    pub async fn discover_albums_by_year(
        &self,
        years: u32,
        per_year: u32,
        kind: Option<&str>,
    ) -> Result<Vec<AlbumYearBucket>, CoreError> {
        Ok(self.bff().discover_albums_by_year(years, per_year, kind).await?)
    }

    pub async fn discover_random(&self, kind: Option<&str>) -> Result<Option<String>, CoreError> {
        Ok(self.bff().discover_random(kind).await?)
    }

    pub async fn discover_tags(&self) -> Result<Vec<Tag>, CoreError> {
        Ok(self.bff().discover_tags().await?)
    }

    pub async fn discover_spotlight(
        &self,
        limit: Option<u32>,
    ) -> Result<Vec<SpotlightItem>, CoreError> {
        Ok(self.bff().discover_spotlight(limit).await?)
    }

    // --- артист ---

    pub async fn artist_detail(&self, id: &str) -> Result<ArtistDetail, CoreError> {
        Ok(self.bff().artist_detail(id).await?)
    }

    pub async fn artist_tracks(
        &self,
        id: &str,
        role: &str,
        limit: u32,
        offset: u32,
    ) -> Result<ListPage<Track>, CoreError> {
        Ok(self.bff().artist_tracks(id, role, limit, offset).await?)
    }

    pub async fn artist_albums(&self, id: &str) -> Result<Vec<AlbumRef>, CoreError> {
        Ok(self.bff().artist_albums(id).await?)
    }

    // --- альбом / плейлист ---

    pub async fn album_detail(&self, id: &str) -> Result<AlbumDetail, CoreError> {
        Ok(self.bff().album_detail(id).await?)
    }

    pub async fn playlist_detail(
        &self,
        urn: &Urn,
        limit: u32,
        offset: u32,
    ) -> Result<PlaylistDetail, CoreError> {
        Ok(self.bff().playlist_detail(urn, limit, offset).await?)
    }

    pub async fn playlist_tracks(
        &self,
        urn: &Urn,
        limit: u32,
        offset: u32,
    ) -> Result<ListPage<Track>, CoreError> {
        Ok(self.bff().playlist_tracks(urn, limit, offset).await?)
    }

    // --- библиотека / профиль ---

    pub async fn me(&self) -> Result<Me, CoreError> {
        Ok(self.bff().me().await?)
    }

    pub async fn me_subscription(&self) -> Result<bool, CoreError> {
        Ok(self.bff().me_subscription().await?)
    }

    pub async fn library_likes_tracks(
        &self,
        limit: u32,
        offset: u32,
    ) -> Result<ListPage<Track>, CoreError> {
        Ok(self.bff().me_likes_tracks(limit, offset).await?)
    }

    pub async fn library_likes_playlists(
        &self,
        limit: u32,
        offset: u32,
    ) -> Result<ListPage<PlaylistSummary>, CoreError> {
        Ok(self.bff().me_likes_playlists(limit, offset).await?)
    }

    pub async fn library_playlists(
        &self,
        limit: u32,
        offset: u32,
    ) -> Result<ListPage<PlaylistSummary>, CoreError> {
        Ok(self.bff().me_playlists(limit, offset).await?)
    }

    pub async fn history(&self, limit: u32, offset: u32) -> Result<HistoryPage, CoreError> {
        Ok(self.bff().history(limit, offset).await?)
    }

    // --- редакторское / лирика ---

    pub async fn featured(&self) -> Result<Featured, CoreError> {
        Ok(self.bff().featured().await?)
    }

    pub async fn lyrics(&self, sc_track_id: &str) -> Result<Option<Lyrics>, CoreError> {
        Ok(self.bff().lyrics(sc_track_id).await?)
    }
}
