import 'package:flutter/material.dart';
import 'package:sc_visual/sc_visual.dart';

/// Искры над горном: фиксированный массив из 4 частиц, взлетающих вверх
/// (`off-spark`: translateY 0→-44, scale 1→0.4, opacity всплеск). Кол-во
/// деградирует через `perf.particles`; в light не монтируется вовсе.
class ForgeSparks extends StatefulWidget {
  const ForgeSparks({super.key});

  @override
  State<ForgeSparks> createState() => _ForgeSparksState();
}

class _ForgeSparksState extends State<ForgeSparks>
    with SingleTickerProviderStateMixin {
  static const _seeds = [
    (left: 0.08, dur: 2100, delay: 0.10, size: 3.0),
    (left: 0.42, dur: 2700, delay: 0.48, size: 2.0),
    (left: 0.70, dur: 2400, delay: 0.79, size: 3.0),
    (left: 0.24, dur: 3100, delay: 0.26, size: 2.0),
  ];

  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 1))
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = PerfProfile.of(context).particles(_seeds.length);
    if (n == 0) return const SizedBox(width: 56, height: 40);
    final seeds = _seeds.take(n).toList();
    return SizedBox(
      width: 56,
      height: 40,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          return Stack(
            children: [
              for (final s in seeds) _spark(s),
            ],
          );
        },
      ),
    );
  }

  Widget _spark(({double left, int dur, double delay, double size}) s) {
    final cycle = (_c.value + s.delay) % 1.0;
    final t = (cycle * (1000 / s.dur)) % 1.0;
    final opacity = t < 0.12 ? (t / 0.12) * 0.9 : (1 - (t - 0.12) / 0.88) * 0.9;
    final scale = 1 - 0.6 * t;
    return Positioned(
      left: 56 * s.left,
      bottom: 44 * t,
      child: Opacity(
        opacity: opacity.clamp(0, 1),
        child: Transform.scale(
          scale: scale,
          child: Container(
            width: s.size,
            height: s.size,
            decoration: BoxDecoration(
              color: ScTheme.paletteOf(context).accentHover,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
