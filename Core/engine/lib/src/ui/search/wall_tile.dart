import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../providers.dart';
import '../../rust/api.dart';
import 'track_wall.dart';

/// Плитка стены. Резолвнутый трек рисуется сразу; ленивый urn (лента/река)
/// резолвится через [trackProvider] только когда плитка попадает в DOM-окно.
/// Покой/hover/now-playing/dive — всё в [CoverTile] из дизайн-системы.
class WallTile extends ConsumerWidget {
  final WallItem item;
  final void Function(TrackDto) onPlay;
  final void Function(TrackDto)? onDive;

  const WallTile({
    super.key,
    required this.item,
    required this.onPlay,
    this.onDive,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolved = item.track;
    if (resolved != null) return _cover(ref, resolved);

    final async = ref.watch(trackProvider(item.urn));
    return async.when(
      data: (track) => track == null
          ? const Skeleton(rounded: SkeletonRound.lg)
          : _cover(ref, track),
      loading: () => const Skeleton(rounded: SkeletonRound.lg),
      error: (_, __) => const Skeleton(rounded: SkeletonRound.lg),
    );
  }

  Widget _cover(WidgetRef ref, TrackDto track) {
    final current = ref.watch(playerProvider);
    final playing = current?.urn == track.urn;
    // Только плитки, чьё превью-состояние реально флипнулось, ребилдятся (select);
    // прогресс кольца тикает в ValueNotifier контроллера — плитку не дёргает.
    final previewing =
        ref.watch(searchPreviewProvider.select((urn) => urn == track.urn));
    final preview = ref.read(searchPreviewProvider.notifier);
    return CoverTile(
      data: CoverTileData(
        urn: track.urn,
        title: track.title,
        artist: track.artistName,
        artworkUrl: track.artworkUrl,
        playing: playing,
        lyricLine: item.lyricLine,
      ),
      hero: item.hero,
      variant: item.lyricLine != null
          ? CoverTileVariant.lyric
          : item.variant,
      onTap: () {
        preview.stop();
        onPlay(track);
      },
      onDive: (item.hero && onDive != null) ? () => onDive!(track) : null,
      onHoverStart: () => preview.start(track.urn),
      onHoverEnd: preview.stop,
      previewProgress: previewing ? preview.progress : null,
    );
  }
}
