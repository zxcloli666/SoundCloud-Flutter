import 'package:flutter/widgets.dart';

import '../theme.dart';

/// `DockLoadingRing`: периметр дока (rounded-rect rx=27) — серый трек + акцентная
/// дуга, заполняемая по `loadPercent` (dashoffset). Рисуется поверх всего дока,
/// пока трек грузится. Плавный переход прогресса 300ms.
class NowBarLoadingRing extends StatelessWidget {
  final int loadPercent;
  final double radius;

  const NowBarLoadingRing({super.key, required this.loadPercent, required this.radius});

  @override
  Widget build(BuildContext context) {
    final palette = ScTheme.paletteOf(context);
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: (loadPercent / 100).clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        builder: (context, value, _) {
          return CustomPaint(
            painter: _RingPainter(progress: value, radius: radius, accent: palette.accent, glow: palette.accentGlow),
          );
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final double radius;
  final Color accent;
  final Color glow;

  const _RingPainter({
    required this.progress,
    required this.radius,
    required this.accent,
    required this.glow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
      Radius.circular(radius - 1),
    );
    final path = Path()..addRRect(rect);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0x12FFFFFF); // white .07
    canvas.drawPath(path, track);

    if (progress <= 0) return;
    final metrics = path.computeMetrics().toList();
    final total = metrics.fold<double>(0, (a, m) => a + m.length);
    var remaining = total * progress;

    final fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = accent
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
    for (final m in metrics) {
      if (remaining <= 0) break;
      final take = remaining < m.length ? remaining : m.length;
      canvas.drawPath(m.extractPath(0, take), fill);
      remaining -= take;
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.radius != radius || old.accent != accent;
}
