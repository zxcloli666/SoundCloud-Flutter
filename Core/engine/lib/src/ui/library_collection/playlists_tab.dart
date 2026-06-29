import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../providers.dart';
import '../../rust/dto.dart';
import 'collection_body.dart';

/// Какой набор плейлистов показывает раздел.
enum PlaylistCollection { mine, liked }

/// Раздел плейлистов (свои или лайкнутые): виртуализированная сетка карточек с
/// клиентским фильтром по названию (легаси `PlaylistsTab`). Под фильтром тянем
/// все страницы. Возвращает сливеры для страничного `CustomScrollView`.
List<Widget> playlistsTabSlivers(
  WidgetRef ref, {
  required PlaylistCollection collection,
  required String filter,
  required String emptyMessage,
  required String noMatchesMessage,
}) {
  final mine = collection == PlaylistCollection.mine;
  final value =
      mine ? ref.watch(myPlaylistsProvider) : ref.watch(likedPlaylistsProvider);
  final Future<void> Function() loadMore = mine
      ? ref.read(myPlaylistsProvider.notifier).loadMore
      : ref.read(likedPlaylistsProvider.notifier).loadMore;
  final paged = value.value;
  final all = paged?.items ?? const <PlaylistSummaryDto>[];
  final hasMore = paged?.hasMore ?? false;
  final loadingMore = paged?.loadingMore ?? false;

  final q = filter.trim().toLowerCase();
  final items = q.isEmpty
      ? all
      : all.where((p) => p.title.toLowerCase().contains(q)).toList();

  if (q.isNotEmpty && hasMore && !loadingMore) {
    WidgetsBinding.instance.addPostFrameCallback((_) => loadMore());
  }

  return collectionBodySlivers(
    state: value,
    hasItems: items.isNotEmpty,
    filtered: q.isNotEmpty,
    hasMore: hasMore,
    loadingMore: loadingMore,
    emptyMessage: emptyMessage,
    noMatchesMessage: noMatchesMessage,
    onLoadMore: loadMore,
    content: () => [
      VirtualGrid<PlaylistSummaryDto>(
        items: items,
        itemHeight: 320,
        minColumnWidth: 180,
        gap: 24,
        overscan: 3,
        getItemKey: (p, _) => ValueKey(p.urn),
        renderItem: (context, p, _) => PlaylistCard(
          data: PlaylistCardData(
            title: p.title,
            artworkUrl: p.artworkUrl,
            trackCount: p.trackCount,
            uploader: p.ownerUsername,
          ),
          onTap: () =>
              ref.read(routerProvider.notifier).push(PlaylistRoute(p.urn)),
        ),
      ).sliver(),
    ],
  );
}
