use serde::Serialize;

use sc_domain::{ListPage, PlaylistSummary, Track, Urn};

use crate::client::BffClient;
use crate::dto::envelope::ListEnvelope;
use crate::dto::playlist::PlaylistSummaryDto;
use crate::dto::track::TrackDto;
use crate::error::BffError;

// Дельта membership плейлиста: `POST /playlists/{urn}/tracks`, ровно одно из
// add|remove|order. Возвращает свежий авторитетный список треков.
#[derive(Serialize)]
struct EditBody<'a> {
    #[serde(skip_serializing_if = "Option::is_none")]
    add: Option<&'a str>,
    #[serde(skip_serializing_if = "Option::is_none")]
    remove: Option<&'a str>,
    #[serde(skip_serializing_if = "Option::is_none")]
    order: Option<&'a [String]>,
}

impl BffClient {
    pub async fn playlist_add_track(
        &self,
        playlist_urn: &Urn,
        track_urn: &Urn,
    ) -> Result<ListPage<Track>, BffError> {
        self.edit_tracks(
            playlist_urn,
            EditBody {
                add: Some(track_urn.as_str()),
                remove: None,
                order: None,
            },
        )
        .await
    }

    pub async fn playlist_remove_track(
        &self,
        playlist_urn: &Urn,
        track_urn: &Urn,
    ) -> Result<ListPage<Track>, BffError> {
        self.edit_tracks(
            playlist_urn,
            EditBody {
                add: None,
                remove: Some(track_urn.as_str()),
                order: None,
            },
        )
        .await
    }

    pub async fn playlist_reorder(
        &self,
        playlist_urn: &Urn,
        track_urns: &[String],
    ) -> Result<ListPage<Track>, BffError> {
        self.edit_tracks(
            playlist_urn,
            EditBody {
                add: None,
                remove: None,
                order: Some(track_urns),
            },
        )
        .await
    }

    async fn edit_tracks(
        &self,
        playlist_urn: &Urn,
        body: EditBody<'_>,
    ) -> Result<ListPage<Track>, BffError> {
        let path = format!("/playlists/{playlist_urn}/tracks");
        let env: ListEnvelope<TrackDto> = self.post_json(&path, &body).await?;
        Ok(env.into_page(TrackDto::into_domain))
    }

    /// `POST /playlists` — создать. Тело SC-формы: `{playlist:{title, sharing,
    /// tracks:[{id}]}}`. Возвращает сводку созданного плейлиста.
    pub async fn create_playlist(
        &self,
        title: &str,
        track_urns: &[String],
    ) -> Result<PlaylistSummary, BffError> {
        let tracks: Vec<TrackIdBody> = track_urns
            .iter()
            .map(|u| TrackIdBody {
                id: Urn::new(u.clone()).bare().to_owned(),
            })
            .collect();
        let body = CreateBody {
            playlist: CreatePlaylist {
                title,
                sharing: "private",
                tracks,
            },
        };
        let dto: PlaylistSummaryDto = self.post_json("/playlists", &body).await?;
        Ok(dto.into_domain())
    }

    /// `DELETE /playlists/{urn}`.
    pub async fn delete_playlist(&self, playlist_urn: &Urn) -> Result<(), BffError> {
        let path = format!("/playlists/{playlist_urn}");
        let resp = self.delete(&path).await?;
        if resp.is_success() {
            Ok(())
        } else {
            Err(BffError::Status {
                status: resp.status,
                path,
            })
        }
    }
}

#[derive(Serialize)]
struct CreateBody<'a> {
    playlist: CreatePlaylist<'a>,
}

#[derive(Serialize)]
struct CreatePlaylist<'a> {
    title: &'a str,
    sharing: &'a str,
    tracks: Vec<TrackIdBody>,
}

#[derive(Serialize)]
struct TrackIdBody {
    id: String,
}
