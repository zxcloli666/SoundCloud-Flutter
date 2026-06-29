import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../providers.dart';
import '../../rust/api.dart';
import '../track/track_aura.dart';

/// Форма сета: один штрих на трек (высота = энергия жанра, цвет = жанр), с
/// плейхедом, скользящим через всё путешествие. Клик по штриху — прыгнуть туда.
/// Плейхед гонит позиция из стрима ядра (без пере-рендера всего — только узкая
/// полоска двигается через [Align]).
class SetRibbon extends ConsumerWidget {
  final List<TrackDto> tracks;
  final ValueChanged<int> onJump;

  const SetRibbon({super.key, required this.tracks, required this.onJump});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = tracks.length;
    if (n == 0) return const SizedBox.shrink();

    final current = ref.watch(playerProvider);
    final viewerAccent = ScTheme.paletteOf(context).accent;
    final currentIndex =
        current == null ? -1 : tracks.indexWhere((t) => t.urn == current.urn);

    return SizedBox(
      height: 64,
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (int i = 0; i < n; i++)
                Expanded(
                  child: _Slice(
                    color: TrackAura.resolve(tracks[i].genre, viewerAccent).accent,
                    energy: _energy(tracks[i].genre),
                    active: i == currentIndex,
                    title: tracks[i].title,
                    onTap: () => onJump(i),
                  ),
                ),
            ],
          ),
          if (currentIndex >= 0) _Playhead(currentIndex: currentIndex, count: n),
        ],
      ),
    );
  }
}

/// Энергия жанра: горячие (танцевальные/бас) выше, спокойные ниже. Из имени
/// детерминированно — нет таблицы, но устойчиво между заходами.
double _energy(String? genre) {
  final g = genre?.trim().toLowerCase();
  if (g == null || g.isEmpty) return 0.5;
  const hot = ['techno', 'house', 'dnb', 'drum', 'bass', 'trap', 'dubstep', 'edm', 'hardstyle', 'rave'];
  const cold = ['ambient', 'lo-fi', 'lofi', 'chill', 'classical', 'acoustic', 'piano', 'jazz'];
  if (hot.any(g.contains)) return 0.85;
  if (cold.any(g.contains)) return 0.2;
  return 0.5;
}

class _Slice extends StatefulWidget {
  final Color color;
  final double energy;
  final bool active;
  final String title;
  final VoidCallback onTap;

  const _Slice({
    required this.color,
    required this.energy,
    required this.active,
    required this.title,
    required this.onTap,
  });

  @override
  State<_Slice> createState() => _SliceState();
}

class _SliceState extends State<_Slice> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final h = (widget.energy * 100).clamp(12.0, 100.0) / 100;
    final lit = widget.active || _hover;
    return ScTooltip(
      message: widget.title,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0.75),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: h,
                widthFactor: 1,
                child: AnimatedOpacity(
                  duration: ScTokens.dFast,
                  opacity: lit ? 1 : 0.5,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: widget.color,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                      boxShadow: widget.active
                          ? [BoxShadow(color: widget.color, blurRadius: 10)]
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Акцентная вертикальная полоска, проезжающая через ленту по позиции трека.
class _Playhead extends ConsumerWidget {
  final int currentIndex;
  final int count;

  const _Playhead({required this.currentIndex, required this.count});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pos = ref.watch(positionStreamProvider).value ?? 0.0;
    final track = ref.watch(playerProvider);
    final durSecs = (track?.durationMs.toInt() ?? 0) / 1000.0;
    final frac = durSecs > 0 ? (pos / durSecs).clamp(0.0, 1.0) : 0.0;
    final x = ((currentIndex + frac) / count).clamp(0.0, 1.0);
    final palette = ScTheme.paletteOf(context);

    return Align(
      // Align маппит [-1..1] на края; x∈[0..1] → 2x-1.
      alignment: Alignment(x * 2 - 1, 0),
      child: Container(
        width: 2,
        decoration: BoxDecoration(
          color: palette.accent,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [BoxShadow(color: palette.accentGlow, blurRadius: 12)],
        ),
      ),
    );
  }
}
