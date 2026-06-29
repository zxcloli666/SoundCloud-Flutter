import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../providers.dart';
import '../../rust/api.dart';
import '../../rust/dto.dart';
import 'shared.dart';
import 'shelves.dart';

/// «От любимых»/«Близкие миры» (легаси `ArtistWire`): отмель — круглые аватары
/// артистов на линии воды + имя + мини-чип «что заиграет» (обложка трека-сида +
/// тайтл + длительность). Тап играет трек-сид артиста в очереди кластера. Если
/// соседей нет — обычная полка треков (фолбэк, как в легаси).
class ArtistWire extends ConsumerWidget {
  final ResolvedCluster cluster;
  final String? currentUrn;

  const ArtistWire({super.key, required this.cluster, required this.currentUrn});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final byId = {for (final t in cluster.tracks) t.urn.split(':').last: t};
    final pairs = <(ClusterNeighborDto, TrackDto)>[];
    for (final n in cluster.neighbors) {
      final t = byId[n.trackId];
      if (t != null) pairs.add((n, t));
    }
    if (pairs.isEmpty) {
      return ClusterShelf(tracks: cluster.tracks, currentUrn: currentUrn);
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Stack(
        children: [
          // Линия воды под рядом аватаров (центр круга ≈ y58), фикс под скроллом.
          const Positioned(top: 58, left: 0, right: 0, child: _WaterLine()),
          HomeHScroll(
            height: 176,
            gap: 28,
            itemCount: pairs.length,
            itemBuilder: (context, i) {
              final (neighbor, track) = pairs[i];
              return _NeighborBuoy(neighbor: neighbor, track: track);
            },
          ),
        ],
      ),
    );
  }
}

/// Горизонтальная «линия воды» — тонкий градиентный хайлайт white/0.2 с фейдом
/// по краям (легаси `linear-gradient(90deg, transparent, white/.2 8%..92%, transparent)`).
class _WaterLine extends StatelessWidget {
  const _WaterLine();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0x00FFFFFF),
              Color(0x33FFFFFF),
              Color(0x33FFFFFF),
              Color(0x00FFFFFF),
            ],
            stops: [0, 0.08, 0.92, 1],
          ),
        ),
      ),
    );
  }
}

class _NeighborBuoy extends ConsumerStatefulWidget {
  final ClusterNeighborDto neighbor;
  final TrackDto track;

  const _NeighborBuoy({required this.neighbor, required this.track});

  @override
  ConsumerState<_NeighborBuoy> createState() => _NeighborBuoyState();
}

class _NeighborBuoyState extends ConsumerState<_NeighborBuoy> {
  bool _hover = false;

  void _openArtist() =>
      ref.read(routerProvider.notifier).push(ArtistRoute(widget.neighbor.artistId));

  @override
  Widget build(BuildContext context) {
    final accent = ScTheme.paletteOf(context).accent;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => playHomeTrack(ref, context, widget.track),
        child: AnimatedContainer(
          duration: ScTokens.dFast,
          curve: ScTokens.easeApple,
          transform: Matrix4.translationValues(0, _hover ? -4 : 0, 0),
          width: 128,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: _avatar(accent)),
              const SizedBox(height: 10),
              Text(
                widget.neighbor.artistName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xD9FFFFFF),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              _trackChip(accent),
            ],
          ),
        ),
      ),
    );
  }

  /// Круглый аватар артиста на линии воды: кольцо white/0.14 → accent+glow на
  /// hover, плей-оверлей при наведении. Тап по аватару — на страницу артиста.
  Widget _avatar(Color accent) {
    return GestureDetector(
      onTap: _openArtist,
      child: Container(
        width: 92,
        height: 92,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _hover ? accent : const Color(0x24FFFFFF),
              spreadRadius: _hover ? 2 : 1,
              blurRadius: 0,
            ),
            if (_hover)
              BoxShadow(color: accent.withValues(alpha: 0.4), blurRadius: 24),
            const BoxShadow(
                color: Color(0x73000000), blurRadius: 28, offset: Offset(0, 12)),
          ],
        ),
        child: ClipOval(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Avatar(src: widget.neighbor.avatarUrl, size: 92),
              AnimatedOpacity(
                opacity: _hover ? 1 : 0,
                duration: ScTokens.dFast,
                child: const ColoredBox(
                  color: Color(0x66000000),
                  child: Center(
                    child: Icon(LucideIcons.play, size: 18, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Мини-чип «что заиграет»: обложка трека-сида + тайтл + длительность.
  Widget _trackChip(Color accent) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: _hover ? const Color(0x0DFFFFFF) : const Color(0x08FFFFFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _hover ? accent.withValues(alpha: 0.3) : const Color(0x0FFFFFFF),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 28,
              height: 28,
              child: TrackArtwork(url: widget.track.artworkUrl, size: ArtSize.row),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _hover ? const Color(0xD9FFFFFF) : const Color(0x99FFFFFF),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    height: 1.15,
                  ),
                ),
                Text(
                  formatDuration(widget.track.durationMs.toInt()),
                  style: const TextStyle(
                    color: Color(0x4DFFFFFF),
                    fontSize: 9.5,
                    height: 1.2,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
