import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../providers.dart';
import '../../rust/api.dart';
import 'shared.dart';

const _shelfCap = 24;

/// «Архив эфира» — лайкнутое и рекомендованное вне эфирной сетки, одним блоком
/// (легаси `ArchiveStation`). Две полки: 01 лайки · 02 рекомендации (берём из
/// резолвленной реки — `same_vibe`/`deep_cuts`, реальные рекомендации движка).
/// Скрывается целиком, если обе пусты.
class ArchiveStation extends ConsumerWidget {
  const ArchiveStation({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liked = ref.watch(likedTracksProvider);
    final river = ref.watch(homeRiverProvider);

    final likedTracks = liked.value?.items ?? const <TrackDto>[];
    final recommended = _recommended(river.value);
    final likedLoading = liked.isLoading;
    final recLoading = river.isLoading;

    if (!likedLoading &&
        likedTracks.isEmpty &&
        !recLoading &&
        recommended.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ref.tr('soundwave.river.archiveTitle'),
                style: const TextStyle(
                  color: Color(0xEBFFFFFF),
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.33,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                ref.tr('soundwave.river.archiveWhy'),
                style: const TextStyle(color: Color(0x80FFFFFF), fontSize: 13, height: 1.2),
              ),
            ],
          ),
        ),
        _SubShelf(
          index: '01',
          label: ref.tr('library.likedTracks'),
          loading: likedLoading,
          tracks: likedTracks,
          // Лайки играют как очередь: доигрываются до конца, потом волна
          // продолжает (см. PlaybackQueueNotifier / queue continuation).
          queue: likedTracks,
        ),
        if (recommended.isNotEmpty || recLoading) ...[
          const SizedBox(height: 32),
          _SubShelf(
            index: '02',
            label: ref.tr('home.recommended'),
            loading: recLoading,
            tracks: recommended,
          ),
        ],
      ],
    );
  }

  List<TrackDto> _recommended(List<ResolvedCluster>? clusters) {
    if (clusters == null) return const [];
    final out = <TrackDto>[];
    final seen = <String>{};
    for (final id in const ['same_vibe', 'deep_cuts', 'adjacent']) {
      final c = clusters.where((x) => x.id == id).firstOrNull;
      if (c == null) continue;
      for (final t in c.tracks) {
        if (seen.add(t.urn)) out.add(t);
      }
    }
    return out;
  }
}

class _SubShelf extends ConsumerWidget {
  final String index;
  final String label;
  final bool loading;
  final List<TrackDto> tracks;

  /// Список-контекст для воспроизведения: задан — трек играет в очереди этого
  /// списка (лайки доигрываются, потом волна); null — одиночный старт (сразу волна).
  final List<TrackDto>? queue;

  const _SubShelf({
    required this.index,
    required this.label,
    required this.loading,
    required this.tracks,
    this.queue,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!loading && tracks.isEmpty) return const SizedBox.shrink();
    final items = tracks.take(_shelfCap).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              Text(
                index,
                style: const TextStyle(
                  color: Color(0x40FFFFFF),
                  fontSize: 10.5,
                  fontFamily: 'monospace',
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  color: Color(0x8CFFFFFF),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.7,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(child: Divider(height: 1, color: Color(0x0DFFFFFF))),
            ],
          ),
        ),
        if (loading)
          const _ShelfSkeleton()
        else
          HomeHScroll(
            itemCount: items.length,
            itemBuilder: (context, i) {
              final track = items[i];
              return SizedBox(
                width: 176,
                child: TrackCardTile(
                  data: TrackCardTileData(
                    title: track.title,
                    artistLine: track.artistName,
                    artworkUrl: track.artworkUrl,
                    durationMs: track.durationMs.toInt(),
                    playbackCount: track.playCount?.toInt(),
                    meta: trackScdMeta(track),
                    liked: track.userFavorite ?? false,
                  ),
                  onPlay: () => playHomeTrack(ref, context, track, queue: queue),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _ShelfSkeleton extends StatelessWidget {
  const _ShelfSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 252,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.centerLeft,
          maxWidth: double.infinity,
          child: Row(
            children: [
              for (var i = 0; i < 8; i++) ...[
                if (i > 0) const SizedBox(width: 16),
                const SizedBox(
                  width: 176,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Skeleton(width: 176, height: 176, rounded: SkeletonRound.lg),
                      SizedBox(height: 10),
                      Skeleton(width: 130, height: 14, rounded: SkeletonRound.sm),
                      SizedBox(height: 6),
                      Skeleton(width: 88, height: 12, rounded: SkeletonRound.sm),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
