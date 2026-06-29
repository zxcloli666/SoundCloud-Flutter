import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../theme.dart';

/// Окно превью при наведении (легаси `PREVIEW_WINDOW_MS`).
const previewWindow = Duration(milliseconds: 15000);

/// Кольцо прогресса превью поверх квадратного тайла: акцентный sweep по
/// периметру скруглённого прямоугольника, открывается слева сверху по часовой.
/// [progress] 0..1 — доля проигранного окна (вызывающий тикает её от audio).
/// Рисуем только активное превью; покой → пусто.
class PreviewRing extends StatelessWidget {
  final double progress;
  final double radius; // должен совпадать с радиусом тайла
  final double strokeWidth;

  const PreviewRing({
    super.key,
    required this.progress,
    this.radius = 16,
    this.strokeWidth = 2.5,
  });

  @override
  Widget build(BuildContext context) {
    final p = progress.clamp(0.0, 1.0);
    if (p <= 0) return const SizedBox.shrink();
    return IgnorePointer(
      child: CustomPaint(
        painter: _PreviewRingPainter(
          progress: p,
          radius: radius,
          strokeWidth: strokeWidth,
          accent: ScTheme.paletteOf(context).accent,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _PreviewRingPainter extends CustomPainter {
  final double progress;
  final double radius;
  final double strokeWidth;
  final Color accent;

  _PreviewRingPainter({
    required this.progress,
    required this.radius,
    required this.strokeWidth,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final inset = strokeWidth / 2;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius - inset));
    final full = Path()..addRRect(rrect);

    final metrics = full.computeMetrics().toList();
    final total = metrics.fold<double>(0, (sum, m) => sum + m.length);
    var target = total * progress;

    final swept = Path();
    // Старт с левого-верхнего угла по часовой: addRRect начинается справа от
    // верхнего-левого скругления, что и даёт открытие слева→направо.
    for (final m in metrics) {
      if (target <= 0) break;
      final take = math.min(m.length, target);
      swept.addPath(m.extractPath(0, take), Offset.zero);
      target -= take;
    }

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = accent
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 1);
    canvas.drawPath(swept, paint);
  }

  @override
  bool shouldRepaint(_PreviewRingPainter old) =>
      old.progress != progress || old.accent != accent || old.radius != radius;
}
