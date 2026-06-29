import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:sc_visual/sc_visual.dart';

/// Фиксированное accent-якорное поле-гало за STAR PASS (легаси `StarAtmosphere`):
/// тёплое металл-свечение top-right + низкий блум снизу, чтобы края вьюпорта не
/// были тёмными. Анимация — кейфреймы `star-halo` (26s/34s), которых не было в
/// легаси `index.css`; авторим их здесь как драйф-контроллер (масштаб+смещение).
/// Перф-гейт: light → один плоский радиальный tint без блюра/дрейфа.
class StarAtmosphere extends StatefulWidget {
  const StarAtmosphere({super.key});

  @override
  State<StarAtmosphere> createState() => _StarAtmosphereState();
}

class _StarAtmosphereState extends State<StarAtmosphere>
    with SingleTickerProviderStateMixin {
  // Один базовый цикл (26s); нижний блум берёт ту же фазу с периодом 34s и сдвигом.
  late final AnimationController _halo = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 26),
  );

  // Запуск/остановка драйфа гало зависит от perf (InheritedWidget) — читаем его в
  // didChangeDependencies (он вызывается сразу после initState), не в initState.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final idle = PerfProfile.of(context).idleAnim;
    if (idle && !_halo.isAnimating) {
      _halo.repeat();
    } else if (!idle && _halo.isAnimating) {
      _halo.stop();
    }
  }

  @override
  void dispose() {
    _halo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final perf = PerfProfile.of(context);
    final accent = ScTheme.paletteOf(context).accent;

    // light: один плоский радиальный tint (легаси !perf.atmosphere ветка).
    if (!perf.atmosphere) {
      return Positioned.fill(
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.6, -1.06),
                radius: 1.1,
                colors: [accent.withValues(alpha: 0.12), const Color(0x00000000)],
                stops: const [0, 0.6],
              ),
            ),
          ),
        ),
      );
    }

    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _halo,
          builder: (context, _) {
            // star-halo: ease-in-out пульс масштаба + лёгкое смещение (translate+scale).
            final t = _halo.value;
            final pulse = math.sin(t * 2 * math.pi);
            final pulse2 = math.sin((t + 0.46) * 2 * math.pi); // фаза для -12s @34s
            return Stack(
              children: [
                // базовая радиальная подложка (3 мягких пятна)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0.6, -1.1),
                        radius: 1.2,
                        colors: [accent.withValues(alpha: 0.18), const Color(0x00000000)],
                        stops: const [0, 0.6],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(-0.84, -0.76),
                        radius: 1.2,
                        colors: [accent.withValues(alpha: 0.10), const Color(0x00000000)],
                        stops: const [0, 0.6],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0, 1.4),
                        radius: 1.4,
                        colors: [accent.withValues(alpha: 0.09), const Color(0x00000000)],
                        stops: const [0, 0.55],
                      ),
                    ),
                  ),
                ),
                // дрейфующее accent-гало (top-right), mix-blend-screen
                _Halo(
                  accent: accent,
                  blurSigma: perf.sigma(120),
                  opacity: 0.28,
                  alignment: Alignment(0.94 + pulse * 0.04, -1.0 + pulse * 0.04),
                  sizeFactor: 0.70 + pulse * 0.04,
                ),
                // низкий блум снизу
                _Halo(
                  accent: accent,
                  blurSigma: perf.sigma(150),
                  opacity: 0.16,
                  alignment: Alignment(-0.46 + pulse2 * 0.04, 1.34 + pulse2 * 0.03),
                  sizeFactor: 0.60 + pulse2 * 0.04,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Одно радиальное гало в режиме screen (легаси `mix-blend-screen` орб).
class _Halo extends StatelessWidget {
  final Color accent;
  final double blurSigma;
  final double opacity;
  final Alignment alignment;
  final double sizeFactor;

  const _Halo({
    required this.accent,
    required this.blurSigma,
    required this.opacity,
    required this.alignment,
    required this.sizeFactor,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final d = c.maxWidth * sizeFactor;
        final orb = Container(
          width: d,
          height: d,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [accent.withValues(alpha: opacity), const Color(0x00000000)],
              stops: const [0, 0.62],
            ),
          ),
        );
        return Align(
          alignment: alignment,
          child: BlendMask(
            blendMode: BlendMode.screen,
            child: blurSigma <= 0
                ? orb
                : ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
                    child: orb,
                  ),
          ),
        );
      },
    );
  }
}
