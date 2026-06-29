/// Дизайн-система SoundCloud (легаси-вид): токены, стекло, атмосфера, оболочка,
/// компоненты (примитивы, треки, коллекции, панели, навигация, виртуализация).
library sc_visual;

// Атмосфера и стеклослой.
export 'src/atmosphere.dart' show Atmosphere, AtmosphereVariant, BlendMask;
export 'src/widgets/atmosphere/star_field.dart' show ScStarField;
export 'src/glass.dart' show GlassButton, GlassCard, GlassPanel, GlassVariant;
export 'src/image_proxy.dart' show ScImageProxy;
export 'src/palette.dart' show ScPalette;
export 'package:lucide_icons_flutter/lucide_icons.dart' show LucideIcons;

export 'src/ambient_clock.dart' show AmbientClock;
export 'src/perf.dart' show PerfMode, PerfProfile, ScPerf;
export 'src/scroll.dart' show ScScrollBehavior;
export 'src/smooth_scroll_controller.dart' show SmoothScrollController;
export 'src/theme.dart' show ScTheme, scDarkTheme;
export 'src/tokens.dart' show ScTokens;

// Оболочка.
export 'src/shell/app_shell.dart' show AppShell;
export 'src/shell/mini_player.dart'
    show ScMiniPlayer, ScMiniPlayerData, ScMiniPlayerCallbacks;
export 'src/shell/wallpaper_layer.dart' show ScWallpaperLayer;
export 'src/shell/now_bar.dart'
    show
        NowBar,
        NowBarData,
        NowBarCallbacks,
        NowBarRepeat,
        NowBarQuality,
        NowBarSource;
export 'src/shell/sidebar.dart'
    show Sidebar, SidebarDestination, SidebarPlaylist, SidebarUser;

// Примитивы.
export 'src/widgets/primitives/avatar.dart' show Avatar;
export 'src/widgets/primitives/avatar_artifact.dart' show AvatarArtifact;
export 'src/widgets/primitives/empty_state.dart' show EmptyState;
export 'src/widgets/primitives/quality_badge.dart'
    show QualityBadge, ScdMeta, ScdTier, ScdBadgeVariant;
export 'src/widgets/primitives/sc_tooltip.dart' show ScTooltip;
export 'src/widgets/primitives/skeleton.dart' show Skeleton, SkeletonRound;
export 'src/widgets/primitives/specular_hairline.dart' show SpecularHairline;
export 'src/widgets/primitives/star_badge.dart' show StarBadge, StarBadgeSize;

// Треки.
export 'src/widgets/track/cluster_bars.dart' show ClusterBars;
export 'src/widgets/track/cluster_header.dart' show ClusterHeader;
export 'src/widgets/track/like_button.dart' show LikeButton;
export 'src/widgets/track/live_waveform.dart'
    show LiveWaveform, waveformBarCount;
export 'src/widgets/track/preview_ring.dart' show PreviewRing, previewWindow;
export 'src/widgets/track/room_voices.dart'
    show RoomVoices, VoiceCardData, RoomVoicesLabels;
export 'src/widgets/track/track_art.dart' show TrackArtwork, ArtSize, artUrl;
export 'src/widgets/track/track_card_tile.dart'
    show TrackCardTile, TrackCardTileData;
export 'src/widgets/track/track_format.dart'
    show formatDuration, formatDurationLong, formatCount;
export 'src/widgets/track/track_row.dart' show TrackRow, TrackRowData;
export 'src/widgets/track/track_status_badge.dart'
    show TrackStatusBadge, TrackStatusMeta, BadgeVariant;
// Каноничный UploadKindDot — типизированный (несёт enum UploadKind), его и
// потребляют TrackRow/TrackCardTile. Строковый вариант из primitives/ — дубль,
// не экспортируется во избежание коллизии имён.
export 'src/widgets/track/upload_kind_dot.dart' show UploadKindDot, UploadKind;

// Карточки/тайлы верхнего уровня.
export 'src/widgets/cover_tile.dart'
    show CoverTile, CoverTileData, CoverTileVariant;
export 'src/widgets/sc_qr_code.dart' show ScQrCode;
export 'src/widgets/track_card.dart' show TrackCard, TrackCardData;

// Коллекции.
export 'src/widgets/collections/album_card.dart' show AlbumCard, AlbumCardData;
export 'src/widgets/collections/artist_card.dart'
    show ArtistCard, ArtistCardData, ArtistStat;
export 'src/widgets/collections/artist_tile.dart'
    show ArtistTile, ArtistTileData;
export 'src/widgets/collections/collection_art.dart'
    show upscaleArtwork, gradientForId, fnv1a, monogramOf;
export 'src/widgets/collections/playlist_card.dart'
    show PlaylistCard, PlaylistCardData;

// Панели.
export 'src/widgets/panels/equalizer_panel.dart'
    show
        EqualizerPanel,
        EqualizerBand,
        EqualizerPreset,
        eqBandCount,
        eqBandLabels,
        eqFlatGains,
        eqPresets;
export 'src/widgets/panels/glass_content_panel.dart'
    show GlassContentPanel, GlassContentSliver, GlassContentRecipe;
export 'src/widgets/panels/lyrics_line.dart' show LyricsLine;
export 'src/widgets/panels/lyrics_panel.dart'
    show LyricsPanel, LyricLineData, LyricsStatus;
export 'src/widgets/panels/lyrics_playhead.dart'
    show LyricsPlayhead, LyricLineState;
export 'src/widgets/panels/lyrics_visualizer.dart' show LyricsWaveVisualizer;
export 'src/widgets/panels/queue_panel.dart' show QueuePanel, QueueEntry;
export 'src/widgets/panels/queue_row.dart' show QueueRow;

// Навигация / overlay.
export 'src/widgets/nav/context_menu.dart'
    show ContextMenu, ContextMenuItem, showContextMenu;
export 'src/widgets/nav/sc_modal.dart' show ScModal, ScModalSize, showScModal;
export 'src/widgets/nav/search_input.dart' show SearchInput;
export 'src/widgets/nav/tab_dock.dart' show TabDock, TabDockItem;
export 'src/widgets/nav/toast.dart'
    show Toast, ToastKind, NewsToast, ToastController, ToastOverlay, ToastScope;

// Виртуализация.
export 'src/widgets/virtual/grid_metrics.dart' show GridMetrics;
export 'src/widgets/virtual/virtual_grid.dart' show VirtualGrid;
export 'src/widgets/virtual/virtual_list.dart' show VirtualList;
export 'src/widgets/virtual/wall_metrics.dart'
    show WallMetrics, hashStr, isHeroUrn, isHeroPos, isHeroIndex;
