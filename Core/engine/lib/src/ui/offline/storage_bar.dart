import 'package:flutter/material.dart';
import 'package:sc_visual/sc_visual.dart';

/// Полоса объёма: сегмент лайков (акцент + диагональная штриховка) →
/// сегмент кэша (white/32) → тиковая сетка-оверлей (8 делений).
class StorageBar extends StatelessWidget {
  final int likedBytes;
  final int cacheBytes;
  final int denomBytes;

  const StorageBar({
    super.key,
    required this.likedBytes,
    required this.cacheBytes,
    required this.denomBytes,
  });

  @override
  Widget build(BuildContext context) {
    final denom = denomBytes <= 0 ? 1 : denomBytes;
    final likedPct = (likedBytes / denom).clamp(0.0, 1.0);
    final cachePct = (cacheBytes / denom).clamp(0.0, 1.0 - likedPct);
    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: SizedBox(
        height: 10,
        child: CustomPaint(
          painter: _StorageBarPainter(
            likedPct: likedPct,
            cachePct: cachePct,
            accent: ScTheme.paletteOf(context).accent,
          ),
        ),
      ),
    );
  }
}

class _StorageBarPainter extends CustomPainter {
  final double likedPct;
  final double cachePct;
  final Color accent;

  _StorageBarPainter({
    required this.likedPct,
    required this.cachePct,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final track = Paint()..color = const Color(0x0DFFFFFF);
    canvas.drawRect(Offset.zero & size, track);

    final likedW = size.width * likedPct;
    final likedRect = Rect.fromLTWH(0, 0, likedW, size.height);
    canvas.drawRect(likedRect,
        Paint()..color = accent.withValues(alpha: 0.85));
    _hatch(canvas, likedRect);

    final cacheRect =
        Rect.fromLTWH(likedW, 0, size.width * cachePct, size.height);
    canvas.drawRect(cacheRect, Paint()..color = const Color(0x52FFFFFF));

    _ticks(canvas, size);
  }

  void _hatch(Canvas canvas, Rect rect) {
    if (rect.width <= 0) return;
    canvas.save();
    canvas.clipRect(rect);
    final p = Paint()
      ..color = const Color(0x800A0A0C)
      ..strokeWidth = 4;
    const spacing = 8.0;
    for (double x = -rect.height; x < rect.width + rect.height; x += spacing) {
      canvas.drawLine(
          Offset(rect.left + x, rect.height), Offset(rect.left + x + rect.height, 0), p);
    }
    canvas.restore();
  }

  void _ticks(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xE60A0A0C)
      ..strokeWidth = 1;
    for (int i = 1; i < 8; i++) {
      final x = size.width * (i / 8);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
  }

  @override
  bool shouldRepaint(_StorageBarPainter old) =>
      old.likedPct != likedPct ||
      old.cachePct != cachePct ||
      old.accent != accent;
}
