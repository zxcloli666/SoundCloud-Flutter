//! Доменные модели SoundCloud-клиента: треки, артисты, альбомы, плейлисты,
//! каталог, волна, библиотека, история.
//!
//! Чистые данные — никакого IO, сети или платформенной специфики. Любой крейт
//! ядра и любой UI работают с этими типами, поэтому держим их минимальными и
//! стабильными. Всё сериализуемо (`serde`) для кэша и моста в Flutter.

pub mod album;
pub mod artist;
pub mod auth;
pub mod cache;
pub mod comment;
pub mod discover;
pub mod featured;
pub mod history;
pub mod ids;
pub mod lyrics;
pub mod page;
pub mod pay;
pub mod playlist;
pub mod queue;
pub mod star;
pub mod streams;
pub mod track;
pub mod user;
pub mod wave;

pub use album::{AlbumArtist, AlbumCard, AlbumDetail, AlbumRef, AlbumYearBucket};
pub use artist::{ArtistCard, ArtistDetail, RelatedArtist, ScAccount, Social};
pub use auth::{AuthStatus, LinkClaim, LinkCreate, LinkStatus, LoginStart, LoginStatus};
pub use cache::CacheEntry;
pub use comment::{Comment, CommentUser};
pub use discover::{DiscoverSummary, SpotlightItem, Tag};
pub use featured::{Featured, FeaturedPick};
pub use history::{HistoryEntry, HistoryPage};
pub use ids::Urn;
pub use lyrics::{LyricHit, LyricLine, Lyrics};
pub use page::{CursorPage, ListPage};
pub use pay::{Checkout, Entitlement, Order, PayTarget, Plan, Redeem, Subscription};
pub use playlist::{Playlist, PlaylistDetail, PlaylistSummary};
pub use queue::{Queue, RepeatMode};
pub use star::{Aura, ArtistStar, WebProfile};
pub use streams::TrackStreams;
pub use track::{ArtistRef, Track, TrackAlbum, TrackBadge, TrackParticipant, VibeResult};
pub use user::{Me, User, UserRef};
pub use wave::{Cluster, ClusterNeighbor, Wave, WaveItem};
