import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../rust/api.dart';
import 'shared.dart';

/// Полка треков (легаси `ClusterRow`/`DeepShelf` — горизонтальный ряд квадратных
/// карточек) с играть-по-тапу и подсветкой текущего. Виртуализируется через
/// [HomeHScroll] — рендерит только видимые карточки.
class ClusterShelf extends ConsumerWidget {
  final List<TrackDto> tracks;
  final String? currentUrn;
  final double cardWidth;

  const ClusterShelf({
    super.key,
    required this.tracks,
    required this.currentUrn,
    this.cardWidth = 176,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return HomeHScroll(
      itemCount: tracks.length,
      itemBuilder: (context, i) {
        final track = tracks[i];
        return SizedBox(
          width: cardWidth,
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
            playing: track.urn == currentUrn,
            width: cardWidth,
            onPlay: () => playHomeTrack(ref, context, track),
          ),
        );
      },
    );
  }
}

/// Полка «Тот же вайб» — каждая карточка тонируется по жанру (легаси `VibeShelf`).
class VibeShelf extends ConsumerWidget {
  final List<TrackDto> tracks;
  final String? currentUrn;

  const VibeShelf({super.key, required this.tracks, required this.currentUrn});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Выше дефолта: у карточки есть жанр-подпись под инфо (иначе bottom-overflow).
    return HomeHScroll(
      height: 270,
      itemCount: tracks.length,
      itemBuilder: (context, i) {
        final track = tracks[i];
        final tone = genreColor(track.genre);
        return SizedBox(
          width: 176,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [tone.withValues(alpha: 0.13), Colors.transparent],
                          stops: const [0, 0.72],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(6),
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
                      playing: track.urn == currentUrn,
                      width: 164,
                      onPlay: () => playHomeTrack(ref, context, track),
                    ),
                  ),
                ],
              ),
              if (track.genre != null && track.genre!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Padding(
                  // Жанр-подпись с отступом снизу 8px (как просил юзер) — карточки
                  // same_vibe с жанром выравниваются по низу.
                  padding: const EdgeInsets.only(left: 8, bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          track.genre!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Color(0x59FFFFFF), fontSize: 10.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Полка «Глубокие закопы» — приглушена, hover проявляет (легаси `DeepShelf`).
class DeepShelf extends StatefulWidget {
  final List<TrackDto> tracks;
  final String? currentUrn;

  const DeepShelf({super.key, required this.tracks, required this.currentUrn});

  @override
  State<DeepShelf> createState() => _DeepShelfState();
}

class _DeepShelfState extends State<DeepShelf> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedOpacity(
        opacity: _hover ? 1 : 0.75,
        duration: const Duration(milliseconds: 300),
        child: ColorFiltered(
          colorFilter: _hover ? _identity : _desaturate,
          child: ClusterShelf(
            tracks: widget.tracks,
            currentUrn: widget.currentUrn,
            cardWidth: 168,
          ),
        ),
      ),
    );
  }
}

const _identity = ColorFilter.matrix(<double>[
  1, 0, 0, 0, 0,
  0, 1, 0, 0, 0,
  0, 0, 1, 0, 0,
  0, 0, 0, 1, 0,
]);

// saturate(0.6): частичная десатурация (R'=0.6*R + 0.4*lum...).
const _desaturate = ColorFilter.matrix(<double>[
  0.7552, 0.1508, 0.0456, 0, 0,
  0.0876, 0.8184, 0.0456, 0, 0,
  0.0876, 0.1508, 0.7132, 0, 0,
  0, 0, 0, 1, 0,
]);

/// Скелет рядов кластеров (легаси `ClusterSkeletonState`): N рядов по M квадратов.
class ClusterSkeleton extends StatelessWidget {
  final int rows;
  final int itemsPerRow;

  const ClusterSkeleton({super.key, required this.rows, required this.itemsPerRow});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var r = 0; r < rows; r++) ...[
          if (r > 0) const SizedBox(height: 40),
          const Skeleton(width: 180, height: 18, rounded: SkeletonRound.sm),
          const SizedBox(height: 16),
          SizedBox(
            height: 230,
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.centerLeft,
                maxWidth: double.infinity,
                child: Row(
                  children: [
                    for (var i = 0; i < itemsPerRow; i++) ...[
                      if (i > 0) const SizedBox(width: 16),
                      const _SkeletonCard(),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
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
    );
  }
}
