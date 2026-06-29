import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../providers.dart';
import '../../rust/api.dart';
import 'collection_body.dart';

/// Раздел «Лайкнутые треки»: виртуализированный список строк с клиентским
/// фильтром (title + артист). Под фильтром дотягиваем все страницы и прячем
/// хвост (легаси `LikesTab`). Возвращает сливеры для страничного `CustomScrollView`.
List<Widget> likesTabSlivers(
  BuildContext context,
  WidgetRef ref, {
  required String filter,
  required String emptyMessage,
  required String noMatchesMessage,
}) {
  final value = ref.watch(likedTracksProvider);
  final notifier = ref.read(likedTracksProvider.notifier);
  final paged = value.value;
  final all = paged?.items ?? const <TrackDto>[];
  final hasMore = paged?.hasMore ?? false;
  final loadingMore = paged?.loadingMore ?? false;

  final q = filter.trim().toLowerCase();
  final items = q.isEmpty
      ? all
      : all
          .where((t) =>
              t.title.toLowerCase().contains(q) ||
              t.artistName.toLowerCase().contains(q))
          .toList();

  // Под фильтром нужны все страницы, чтобы совпадения не прятались за хвостом.
  if (q.isNotEmpty && hasMore && !loadingMore) {
    WidgetsBinding.instance.addPostFrameCallback((_) => notifier.loadMore());
  }

  return collectionBodySlivers(
    state: value,
    hasItems: items.isNotEmpty,
    filtered: q.isNotEmpty,
    hasMore: hasMore,
    loadingMore: loadingMore,
    emptyMessage: emptyMessage,
    noMatchesMessage: noMatchesMessage,
    onLoadMore: notifier.loadMore,
    content: () => [
      VirtualList<TrackDto>(
        items: items,
        rowHeight: 68,
        overscan: 8,
        getItemKey: (t, _) => ValueKey(t.urn),
        renderItem: (context, track, i) => _LikeRow(
          track: track,
          index: i + 1,
          queue: items,
        ),
      ).sliver(context),
    ],
  );
}

/// Строка лайкнутого трека: воспроизведение в контексте всего отфильтрованного
/// списка ([queue]) и оптимистичный тоггл лайка через [socialControllerProvider]
/// (откат при ошибке). Локальный флаг лайка держим в стейте, чтобы клик отзывался
/// мгновенно, не дожидаясь перечитки [likedTracksProvider].
class _LikeRow extends ConsumerStatefulWidget {
  final TrackDto track;
  final int index;
  final List<TrackDto> queue;

  const _LikeRow({required this.track, required this.index, required this.queue});

  @override
  ConsumerState<_LikeRow> createState() => _LikeRowState();
}

class _LikeRowState extends ConsumerState<_LikeRow> {
  late bool _liked = widget.track.userFavorite ?? true;

  Future<void> _toggleLike(bool next) async {
    final messenger = ToastScope.maybeOf(context);
    setState(() => _liked = next);
    final social = ref.read(socialControllerProvider);
    try {
      if (next) {
        await social.likeTrack(widget.track.urn);
      } else {
        await social.unlikeTrack(widget.track.urn);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _liked = !next);
      messenger?.show('Не удалось обновить лайк: $e', kind: ToastKind.error);
    }
  }

  Future<void> _play() async {
    final messenger = ToastScope.maybeOf(context);
    try {
      await ref
          .read(playerProvider.notifier)
          .play(widget.track, queue: widget.queue);
    } catch (e) {
      messenger?.show('Не удалось воспроизвести: $e', kind: ToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final track = widget.track;
    final accent = ScTheme.paletteOf(context).accent;
    final current = ref.watch(playerProvider)?.urn == track.urn;
    return TrackRow(
      data: TrackRowData(
        title: track.title,
        artistLine: track.artistName,
        artworkUrl: track.artworkUrl,
        durationMs: track.durationMs.toInt(),
        liked: _liked,
        meta: TrackStatusMeta(
          storageState: track.storageState,
          storageQuality: track.storageQuality,
          indexState: track.indexState,
        ),
        playbackCount: track.playCount?.toInt(),
        likesCount: track.likesCount?.toInt(),
      ),
      index: widget.index,
      highlight: accent,
      current: current,
      playing: current,
      showStats: true,
      onToggleLike: _toggleLike,
      onPlay: _play,
    );
  }
}
