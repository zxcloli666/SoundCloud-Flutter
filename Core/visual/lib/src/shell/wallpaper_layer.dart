import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../perf.dart';

/// Слой фоновой обоины (легаси `AppShell.CustomBackground`): фото на самом заднем
/// плане, кинематографичная виньетка топит края (чтобы орбы читались как свет из
/// углов), хром-градиенты держат читаемость титлбара/дока/сайдбара, плюс мягкий
/// плёночный грейн. Орбы/звёзды монтируются ПОВЕРХ этого (см. AppShell).
///
/// [opacity] — рамка читаемости (виньетка+хром), [dim] — равномерное затемнение,
/// [blur] — логический CSS-радиус (через [PerfProfile.blur]). Без анимаций — это
/// статичный бэкдроп под `RepaintBoundary`.
class ScWallpaperLayer extends StatelessWidget {
  final ImageProvider image;
  final double opacity;
  final double dim;
  final double blur;

  const ScWallpaperLayer({
    super.key,
    required this.image,
    this.opacity = 0.15,
    this.dim = 0,
    this.blur = 0,
  });

  @override
  Widget build(BuildContext context) {
    final perf = PerfProfile.of(context);
    final sigma = perf.sigma(blur);
    final d = opacity; // виньетка/хром = рамка читаемости

    Widget photo = Image(
      image: image,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
    if (sigma > 0) {
      photo = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: photo,
      );
    }

    return IgnorePointer(
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            photo,
            // Кинематографичная виньетка — яркий центр, утопленные края.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.24),
                  radius: 1.1,
                  colors: [
                    const Color(0x00000000),
                    _ink(0.4 + d * 0.45),
                  ],
                  stops: const [0.38, 1.0],
                ),
              ),
            ),
            // Хром-градиенты читаемости (верх/низ/левый край).
            _chrome(Alignment.topCenter, Alignment.bottomCenter, 144,
                _ink(0.45 + d * 0.4)),
            _chrome(Alignment.bottomCenter, Alignment.topCenter, 208,
                _ink(0.52 + d * 0.4)),
            _chromeH(160, _ink(0.28 + d * 0.35)),
            // Равномерное затемнение поверх (укрощает яркие обои целиком).
            if (dim > 0) ColoredBox(color: _ink(dim)),
            if (perf.atmosphere)
              Opacity(
                opacity: 0.06,
                child: RepaintBoundary(
                  child: CustomPaint(painter: const _GrainPainter()),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Чёрный «#060609» с заданной альфой (база легаси `rgba(6,6,9,a)`).
  static Color _ink(double alpha) =>
      const Color(0xFF060609).withValues(alpha: alpha.clamp(0, 1));

  Widget _chrome(Alignment begin, Alignment end, double height, Color from) {
    return Align(
      alignment: begin,
      child: SizedBox(
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: begin,
              end: end,
              colors: [from, const Color(0x00000000)],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chromeH(double width, Color from) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: width,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [from, const Color(0x00000000)],
            ),
          ),
        ),
      ),
    );
  }
}

/// Статичный плёночный грейн (легаси SVG `feTurbulence`): детерминированные
/// крапинки, рисуется один раз под `RepaintBoundary` (без анимации).
class _GrainPainter extends CustomPainter {
  const _GrainPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFFFFFFF);
    // Плотность ~1 крапинка на 90 px² — заметная фактура без тяжести.
    final count = (size.width * size.height / 90).clamp(0, 60000).toInt();
    var seed = 0x9e3779b9;
    int next() {
      // LCG (детерминирован — без Random, shouldRepaint=false).
      seed = (seed * 1664525 + 1013904223) & 0x7fffffff;
      return seed;
    }

    for (var i = 0; i < count; i++) {
      final x = (next() % 100000) / 100000 * size.width;
      final y = (next() % 100000) / 100000 * size.height;
      canvas.drawRect(Rect.fromLTWH(x, y, 1, 1), paint);
    }
  }

  @override
  bool shouldRepaint(_GrainPainter oldDelegate) => false;
}
