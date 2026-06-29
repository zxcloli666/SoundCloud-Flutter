import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:sc_visual/sc_visual.dart';

/// Витраж вкуса: лайкнутые обложки тайлами, сильно размытые и приглушённые,
/// дрейфуют за фростом мастхеда (легаси `ArtworkMosaic`). Только beauty —
/// блюр реально дорог, но стена кешируется одним слоем и только смещается.
class ArtworkMosaic extends StatefulWidget {
  final List<String?> covers;

  const ArtworkMosaic({super.key, required this.covers});

  @override
  State<ArtworkMosaic> createState() => _ArtworkMosaicState();
}

class _ArtworkMosaicState extends State<ArtworkMosaic>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift;

  @override
  void initState() {
    super.initState();
    _drift = AnimationController(vsync: this, duration: const Duration(seconds: 90))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final perf = ScPerf.of(context);
    final urls = widget.covers
        .map((u) => upscaleArtwork(u, size: 't200x200'))
        .whereType<String>()
        .take(21)
        .toList(growable: false);
    if (perf != PerfMode.beauty || urls.length < 8) {
      return const SizedBox.shrink();
    }

    final tiles = [...urls, ...urls];
    return Positioned.fill(
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _drift,
          builder: (context, child) {
            final t = _drift.value; // 0..1
            return Transform.translate(
              offset: Offset(-t * 22, -t * 11),
              child: child,
            );
          },
          child: Opacity(
            opacity: 0.16,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final url in tiles)
                    SizedBox(
                      width: 88,
                      height: 88,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(ScTokens.rCard),
                        child: Image(
                          image: ScImageProxy.provider(url),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
