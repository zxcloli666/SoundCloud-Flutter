import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../providers.dart';
import '../../rust/api.dart' show TrackDto;
import '../../rust/dto.dart' show PlaylistSummaryDto, UserDto;
import 'user_aura.dart';
import 'user_connection_grid.dart';
import 'user_load_more.dart';

/// Вкладки профиля (легаси `TabId`). Поиск поддерживают только popular/tracks/
/// playlists (на followers/following/likes контент принадлежит другим людям/SC).
enum UserTab {
  popular('Popular'),
  tracks('Tracks'),
  playlists('Playlists'),
  likes('Likes'),
  followers('Followers'),
  following('Following');

  final String label;
  const UserTab(this.label);

  bool get searchable =>
      this == UserTab.popular || this == UserTab.tracks || this == UserTab.playlists;

  String get searchScopeLabel => this == UserTab.playlists ? 'playlists' : 'tracks';
}

/// Рендер активной вкладки. При активном [query] в searchable-табе показываем
/// DB-поиск (мост даёт только глобальный, не user-scoped — см. notes).
class UserTabView extends ConsumerWidget {
  final String urn;
  final UserTab tab;
  final UserAura aura;
  final String query;

  const UserTabView({
    super.key,
    required this.urn,
    required this.tab,
    required this.aura,
    required this.query,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searching = query.isNotEmpty && tab.searchable;

    if (searching && tab == UserTab.playlists) {
      return _PlaylistSearchTab(query: query);
    }
    if (searching) {
      return _TrackSearchTab(query: query, aura: aura);
    }

    return switch (tab) {
      UserTab.popular => _UserTracksTab(urn: urn, aura: aura, popular: true),
      UserTab.tracks => _UserTracksTab(urn: urn, aura: aura),
      UserTab.playlists => _UserPlaylistsTab(urn: urn),
      UserTab.likes =>
        _UserTracksTab(urn: urn, aura: aura, likes: true, emptyText: 'No liked tracks'),
      UserTab.followers => _UserConnectionsTab(urn: urn, mode: _Conn.followers),
      UserTab.following => _UserConnectionsTab(urn: urn, mode: _Conn.following),
    };
  }
}

/// Треки/popular/likes юзера через накопительные провайдеры. [popular] сортирует
/// загруженные треки по play_count (легаси «loop all pages → sort»); [likes]
/// читает лайкнутые. Провайдер шарится между юзерами — рисуем лишь когда держит
/// наш urn (иначе ждём `load`, дёрнутый страницей).
class _UserTracksTab extends ConsumerWidget {
  final String urn;
  final UserAura aura;
  final bool popular;
  final bool likes;
  final String emptyText;

  const _UserTracksTab({
    required this.urn,
    required this.aura,
    this.popular = false,
    this.likes = false,
    this.emptyText = 'No tracks yet',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = likes ? userLikedTracksProvider : userTracksProvider;
    final async = ref.watch(provider);
    return _paged<TrackDto>(
      async: async,
      urn: urn,
      emptyText: emptyText,
      builder: (s) {
        final tracks = popular ? _byPlayCount(s.items) : s.items;
        return _ListWithMore(
          child: _TrackList(tracks: tracks, aura: aura),
          // popular читает все треки разом, без догрузки (легаси).
          hasMore: !popular && s.hasMore,
          loadingMore: s.loadingMore,
          onMore: () => ref.read(provider.notifier).more(),
        );
      },
    );
  }

  List<TrackDto> _byPlayCount(List<TrackDto> tracks) {
    final sorted = [...tracks];
    sorted.sort((a, b) => (b.playCount ?? BigInt.zero).compareTo(a.playCount ?? BigInt.zero));
    return sorted;
  }
}

/// Плейлисты юзера (накопительный провайдер) + догрузка.
class _UserPlaylistsTab extends ConsumerWidget {
  final String urn;

  const _UserPlaylistsTab({required this.urn});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(userPlaylistsProvider);
    return _paged<PlaylistSummaryDto>(
      async: async,
      urn: urn,
      emptyText: 'No playlists yet',
      builder: (s) => _ListWithMore(
        child: _PlaylistGrid(playlists: s.items),
        hasMore: s.hasMore,
        loadingMore: s.loadingMore,
        onMore: () => ref.read(userPlaylistsProvider.notifier).more(),
      ),
    );
  }
}

enum _Conn { followers, following }

/// Followers/Following: сетка карточек-связей (накопительный провайдер) + догрузка.
class _UserConnectionsTab extends ConsumerWidget {
  final String urn;
  final _Conn mode;

  const _UserConnectionsTab({required this.urn, required this.mode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider =
        mode == _Conn.followers ? userFollowersProvider : userFollowingsProvider;
    final async = ref.watch(provider);
    final emptyText =
        mode == _Conn.followers ? 'No followers yet' : 'Not following anyone';
    return _paged<UserDto>(
      async: async,
      urn: urn,
      emptyText: emptyText,
      builder: (s) => _ListWithMore(
        child: UserConnectionGrid(
          users: s.items,
          onOpen: (u) =>
              ref.read(routerProvider.notifier).push(UserRoute(u.urn)),
        ),
        hasMore: s.hasMore,
        loadingMore: s.loadingMore,
        onMore: () => ref.read(provider.notifier).more(),
      ),
    );
  }
}

/// Общий каркас вкладки на [UserPagedState]: спиннер до загрузки нашего urn,
/// пустое состояние, иначе — контент через [builder].
Widget _paged<T>({
  required AsyncValue<UserPagedState<T>> async,
  required String urn,
  required String emptyText,
  required Widget Function(UserPagedState<T> state) builder,
}) {
  return async.when(
    loading: () => const TabWrapper(loading: true, empty: false, child: SizedBox.shrink()),
    error: (_, __) =>
        TabWrapper(loading: false, empty: true, emptyText: emptyText, child: const SizedBox.shrink()),
    data: (s) {
      final bare = urn.split(':').last;
      // Провайдер ещё держит другой urn — ждём load, дёрнутый страницей.
      if (s.urn.split(':').last != bare) {
        return const TabWrapper(loading: true, empty: false, child: SizedBox.shrink());
      }
      return TabWrapper(
        loading: false,
        empty: s.items.isEmpty,
        emptyText: emptyText,
        child: builder(s),
      );
    },
  );
}

/// Виртуализированный контент + сентинел «показать ещё» под ним. Внешний скролл
/// панели фиксированной высоты держит [TabWrapper], так что список самоскроллится.
class _ListWithMore extends StatelessWidget {
  final Widget child;
  final bool hasMore;
  final bool loadingMore;
  final VoidCallback onMore;

  const _ListWithMore({
    required this.child,
    required this.hasMore,
    required this.loadingMore,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasMore) return child;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: child),
        const SizedBox(height: 12),
        UserLoadMore(loading: loadingMore, onTap: onMore),
      ],
    );
  }
}

/// Обёртка контента таба (легаси `TabWrapper`): min-h 420; loading-спиннер;
/// пустое состояние — иконка-плитка + строка; иначе fade-in контента.
class TabWrapper extends StatelessWidget {
  final bool loading;
  final bool empty;
  final String emptyText;
  final Widget child;

  const TabWrapper({
    super.key,
    required this.loading,
    required this.empty,
    required this.child,
    this.emptyText = 'Nothing here yet',
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return const _CenterSpinner();
    if (empty) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 420),
        child: Center(
          child: EmptyState(icon: const Icon(LucideIcons.music), title: emptyText),
        ),
      );
    }
    // Списки/сетки сами скроллятся: даём ограниченный по высоте вьюпорт, чтобы
    // не конфликтовать с внешним SingleChildScrollView страницы.
    final viewport = (MediaQuery.sizeOf(context).height - 220).clamp(420.0, 900.0);
    return SizedBox(height: viewport, child: child);
  }
}

class _CenterSpinner extends StatelessWidget {
  const _CenterSpinner();

  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 420,
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: Color(0x33FFFFFF)),
          ),
        ),
      );
}

/// Список треков с аура-подсветкой (легаси `ThemedTrackRow` в `VirtualList`
/// rowHeight 72). Резолв обложек ленив — `TrackRow` сам тянет видимые тайлы.
class _TrackList extends ConsumerWidget {
  final List<TrackDto> tracks;
  final UserAura aura;

  const _TrackList({required this.tracks, required this.aura});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(playerProvider)?.urn;
    return VirtualList<TrackDto>(
      items: tracks,
      rowHeight: 76, // 72 row + 4 gap
      overscan: 8,
      getItemKey: (t, _) => ValueKey(t.urn),
      renderItem: (context, track, i) {
        final isCurrent = track.urn == current;
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: TrackRow(
            data: TrackRowData(
              title: track.title,
              artistLine: track.artistName,
              artworkUrl: track.artworkUrl,
              durationMs: track.durationMs.toInt(),
              meta: TrackStatusMeta(
                storageState: track.storageState,
                storageQuality: track.storageQuality,
                indexState: track.indexState,
              ),
              liked: track.userFavorite ?? false,
              playbackCount: track.playCount?.toInt(),
              likesCount: track.likesCount?.toInt(),
            ),
            index: i + 1,
            highlight: aura.accent,
            lightHighlight: aura.isLight,
            current: isCurrent,
            showStats: true,
            // Очередь = весь видимый список треков (queue-continuation §queue):
            // сначала доигрываем его, потом волна.
            onPlay: () => ref.read(playerProvider.notifier).play(track, queue: tracks),
          ),
        );
      },
    );
  }
}

/// Сетка плейлистов (легаси `VirtualGrid` itemHeight 320 minCol 200 gap 28).
class _PlaylistGrid extends ConsumerWidget {
  final List<PlaylistSummaryDto> playlists;

  const _PlaylistGrid({required this.playlists});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return VirtualGrid<PlaylistSummaryDto>(
      items: playlists,
      itemHeight: 320,
      minColumnWidth: 200,
      gap: 28,
      overscan: 3,
      getItemKey: (p, _) => ValueKey(p.urn),
      renderItem: (context, p, _) => PlaylistCard(
        data: PlaylistCardData(
          title: p.title,
          artworkUrl: p.artworkUrl,
          trackCount: p.trackCount,
          typeLabel: p.isAlbum ? 'Album' : 'Playlist',
          likesLabel: p.likesCount != null ? formatCount(p.likesCount!.toInt()) : null,
          uploader: p.ownerUsername,
        ),
        showPlayback: true,
        onTap: () => ref.read(routerProvider.notifier).push(PlaylistRoute(p.urn)),
      ),
    );
  }
}

/// Поиск треков (DB-backed, глобальный — мост не даёт user-scoped, см. notes).
class _TrackSearchTab extends ConsumerWidget {
  final String query;
  final UserAura aura;

  const _TrackSearchTab({required this.query, required this.aura});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(searchTracksProvider(query));
    return async.when(
      loading: () => const TabWrapper(loading: true, empty: false, child: SizedBox.shrink()),
      error: (_, __) => const TabWrapper(loading: false, empty: true, child: SizedBox.shrink(), emptyText: 'Nothing found'),
      data: (tracks) => TabWrapper(
        loading: false,
        empty: tracks.isEmpty,
        emptyText: 'Nothing found',
        child: _TrackList(tracks: tracks, aura: aura),
      ),
    );
  }
}

/// Поиск плейлистов (DB-backed, глобальный — см. notes).
class _PlaylistSearchTab extends ConsumerWidget {
  final String query;

  const _PlaylistSearchTab({required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(searchPlaylistsProvider(query));
    return async.when(
      loading: () => const TabWrapper(loading: true, empty: false, child: SizedBox.shrink()),
      error: (_, __) => const TabWrapper(loading: false, empty: true, child: SizedBox.shrink(), emptyText: 'Nothing found'),
      data: (page) => TabWrapper(
        loading: false,
        empty: page.items.isEmpty,
        emptyText: 'Nothing found',
        child: _PlaylistGrid(playlists: page.items),
      ),
    );
  }
}

