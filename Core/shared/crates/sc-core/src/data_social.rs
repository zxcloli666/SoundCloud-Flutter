//! Социальный/мьютационный слой данных рантайма: vibe/lyrics-поиск, кавера и
//! звезда артиста, реко-кластеры, профили пользователей, подписки/лайки/дизлайки,
//! аура, waveform, resolve. Тонкие пасс-тру к [`sc_bff::BffClient`].

use sc_domain::{
    ArtistStar, Aura, Cluster, ListPage, LyricHit, PlaylistSummary, Track, Urn, User, VibeResult,
    WebProfile,
};

use crate::{CoreError, ScRuntime};

impl ScRuntime {
    // --- vibe / lyrics поиск ---

    pub async fn search_vibe(&self, query: &str, limit: u32) -> Result<VibeResult, CoreError> {
        Ok(self.bff().search_vibe(query, limit).await?)
    }

    /// Живой поиск треков прямо в SoundCloud (apiv2, через sc-raw) — источник «SC».
    pub async fn search_sc_tracks(
        &self,
        query: &str,
        limit: u32,
    ) -> Result<Vec<Track>, CoreError> {
        Ok(self.raw().search_tracks(query, limit, 0).await?.items)
    }

    pub async fn search_lyrics(
        &self,
        query: &str,
        limit: u32,
    ) -> Result<ListPage<LyricHit>, CoreError> {
        Ok(self.bff().search_lyrics(query, limit).await?)
    }

    // --- артист: кавера / звезда / реко ---

    pub async fn artist_covers(
        &self,
        id: &str,
        limit: u32,
        offset: u32,
    ) -> Result<ListPage<Track>, CoreError> {
        Ok(self.bff().artist_covers(id, limit, offset).await?)
    }

    pub async fn artist_star(&self, id: &str) -> Result<ArtistStar, CoreError> {
        Ok(self.bff().artist_star(id).await?)
    }

    pub async fn recommendations_similar(
        &self,
        track_id: &str,
        limit: u32,
    ) -> Result<Vec<Cluster>, CoreError> {
        Ok(self.bff().recommendations_similar(track_id, limit).await?)
    }

    pub async fn recommendations_artist(
        &self,
        artist_id: &str,
        limit: u32,
    ) -> Result<Vec<Cluster>, CoreError> {
        Ok(self.bff().recommendations_artist(artist_id, limit).await?)
    }

    // --- пользователь по URN ---

    pub async fn user(&self, urn: &Urn) -> Result<Option<User>, CoreError> {
        Ok(self.bff().user(urn).await?)
    }

    pub async fn user_tracks(
        &self,
        urn: &Urn,
        limit: u32,
        offset: u32,
    ) -> Result<ListPage<Track>, CoreError> {
        Ok(self.bff().user_tracks(urn, limit, offset).await?)
    }

    pub async fn user_playlists(
        &self,
        urn: &Urn,
        limit: u32,
        offset: u32,
    ) -> Result<ListPage<sc_domain::PlaylistSummary>, CoreError> {
        Ok(self.bff().user_playlists(urn, limit, offset).await?)
    }

    pub async fn user_liked_tracks(
        &self,
        urn: &Urn,
        limit: u32,
        offset: u32,
    ) -> Result<ListPage<Track>, CoreError> {
        Ok(self.bff().user_liked_tracks(urn, limit, offset).await?)
    }

    pub async fn user_followers(
        &self,
        urn: &Urn,
        limit: u32,
        offset: u32,
    ) -> Result<ListPage<User>, CoreError> {
        Ok(self.bff().user_followers(urn, limit, offset).await?)
    }

    pub async fn user_followings(
        &self,
        urn: &Urn,
        limit: u32,
        offset: u32,
    ) -> Result<ListPage<User>, CoreError> {
        Ok(self.bff().user_followings(urn, limit, offset).await?)
    }

    pub async fn user_web_profiles(&self, urn: &Urn) -> Result<Vec<WebProfile>, CoreError> {
        Ok(self.bff().user_web_profiles(urn).await?)
    }

    pub async fn user_subscription(&self, urn: &Urn) -> Result<bool, CoreError> {
        Ok(self.bff().user_subscription(urn).await?)
    }

    // --- мои подписки ---

    pub async fn me_followings(
        &self,
        limit: u32,
        offset: u32,
    ) -> Result<ListPage<User>, CoreError> {
        Ok(self.bff().me_followings(limit, offset).await?)
    }

    pub async fn me_followings_tracks(
        &self,
        limit: u32,
        offset: u32,
    ) -> Result<ListPage<Track>, CoreError> {
        Ok(self.bff().me_followings_tracks(limit, offset).await?)
    }

    // --- аура ---

    pub async fn user_aura(&self, urn: &Urn) -> Result<Aura, CoreError> {
        Ok(self.bff().user_aura(urn).await?)
    }

    pub async fn put_aura(
        &self,
        aura_id: &str,
        custom_hex: Option<&str>,
    ) -> Result<Aura, CoreError> {
        Ok(self.bff().put_aura(aura_id, custom_hex).await?)
    }

    // --- кто-вайбит / резолв / waveform ---

    pub async fn track_favoriters(
        &self,
        urn: &Urn,
        limit: u32,
    ) -> Result<ListPage<User>, CoreError> {
        Ok(self.bff().track_favoriters(urn, limit).await?)
    }

    pub async fn track_reposters(
        &self,
        urn: &Urn,
        limit: u32,
    ) -> Result<ListPage<User>, CoreError> {
        Ok(self.bff().track_reposters(urn, limit).await?)
    }

    pub async fn resolve_url(&self, url: &str) -> Result<Option<Track>, CoreError> {
        Ok(self.bff().resolve_url(url).await?)
    }

    pub async fn track_waveform(&self, waveform_url: &str) -> Result<Vec<f32>, CoreError> {
        Ok(self.bff().track_waveform(waveform_url).await?)
    }

    // --- мьютации ---

    pub async fn like_track(&self, track_urn: &Urn) -> Result<(), CoreError> {
        Ok(self.bff().like_track(track_urn).await?)
    }

    pub async fn unlike_track(&self, track_urn: &Urn) -> Result<(), CoreError> {
        Ok(self.bff().unlike_track(track_urn).await?)
    }

    pub async fn like_playlist(&self, playlist_urn: &Urn) -> Result<(), CoreError> {
        Ok(self.bff().like_playlist(playlist_urn).await?)
    }

    pub async fn unlike_playlist(&self, playlist_urn: &Urn) -> Result<(), CoreError> {
        Ok(self.bff().unlike_playlist(playlist_urn).await?)
    }

    pub async fn follow_user(&self, user_urn: &Urn) -> Result<(), CoreError> {
        Ok(self.bff().follow_user(user_urn).await?)
    }

    pub async fn unfollow_user(&self, user_urn: &Urn) -> Result<(), CoreError> {
        Ok(self.bff().unfollow_user(user_urn).await?)
    }

    pub async fn dislike_track(&self, sc_track_id: &str) -> Result<(), CoreError> {
        Ok(self.bff().dislike_track(sc_track_id).await?)
    }

    pub async fn undislike_track(&self, sc_track_id: &str) -> Result<(), CoreError> {
        Ok(self.bff().undislike_track(sc_track_id).await?)
    }

    pub async fn dislike_status(&self, sc_track_id: &str) -> Result<bool, CoreError> {
        Ok(self.bff().dislike_status(sc_track_id).await?)
    }

    pub async fn dislike_ids(&self) -> Result<Vec<String>, CoreError> {
        Ok(self.bff().dislike_ids().await?)
    }

    pub async fn clear_history(&self) -> Result<(), CoreError> {
        Ok(self.bff().clear_history().await?)
    }

    // --- батч-резолв (схлопывает N round-trip'ов home/wave/similar) ---

    pub async fn resolve_tracks(&self, urns: &[String]) -> Result<Vec<Track>, CoreError> {
        Ok(self.bff().resolve_tracks(urns).await?)
    }

    // --- мьютации плейлистов ---

    pub async fn playlist_add_track(
        &self,
        playlist_urn: &Urn,
        track_urn: &Urn,
    ) -> Result<ListPage<Track>, CoreError> {
        Ok(self.bff().playlist_add_track(playlist_urn, track_urn).await?)
    }

    pub async fn playlist_remove_track(
        &self,
        playlist_urn: &Urn,
        track_urn: &Urn,
    ) -> Result<ListPage<Track>, CoreError> {
        Ok(self.bff().playlist_remove_track(playlist_urn, track_urn).await?)
    }

    pub async fn playlist_reorder(
        &self,
        playlist_urn: &Urn,
        track_urns: &[String],
    ) -> Result<ListPage<Track>, CoreError> {
        Ok(self.bff().playlist_reorder(playlist_urn, track_urns).await?)
    }

    pub async fn create_playlist(
        &self,
        title: &str,
        track_urns: &[String],
    ) -> Result<PlaylistSummary, CoreError> {
        Ok(self.bff().create_playlist(title, track_urns).await?)
    }

    pub async fn delete_playlist(&self, playlist_urn: &Urn) -> Result<(), CoreError> {
        Ok(self.bff().delete_playlist(playlist_urn).await?)
    }
}
