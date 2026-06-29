import 'package:flutter/material.dart';
import 'package:sc_visual/sc_visual.dart';

import 'star_data.dart';

/// Глифы провайдеров (легаси `ProviderGlyph.tsx`). СБП держит фирменный
/// фиолетово-синий (единственное функциональное исключение цвета); остальное —
/// из accent / нейтральных чернил. Рисуем path'ами через [CustomPaint].
class ProviderGlyph extends StatelessWidget {
  final ActivationKind kind;
  const ProviderGlyph({super.key, required this.kind});

  @override
  Widget build(BuildContext context) {
    final accent = ScTheme.paletteOf(context).accent;
    return SizedBox(
      width: 22,
      height: 22,
      child: CustomPaint(painter: _GlyphPainter(kind, accent)),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  final ActivationKind kind;
  final Color accent;
  _GlyphPainter(this.kind, this.accent);

  // Все легаси-глифы в системе координат viewBox 24×24.
  static const double _vb = 24;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / _vb;
    canvas.scale(k);
    switch (kind) {
      case ActivationKind.sbp:
        _path(canvas, 'M5 12L9 5l4 7-4 7L5 12z', fill: accent);
        _path(canvas, 'M11 12l4-7 4 7-4 7-4-7z',
            fill: const Color(0xFF7A5CFF).withValues(alpha: 0.85));
      case ActivationKind.cardRu:
        final ink = const Color(0xFFFFFFFF).withValues(alpha: 0.8);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTWH(2.5, 5, 19, 14), const Radius.circular(2.5)),
          _stroke(ink, 1.5),
        );
        canvas.drawLine(const Offset(2.5, 9), const Offset(21.5, 9), _stroke(ink, 1.5));
      case ActivationKind.cardIntl:
        final ink = const Color(0xFFFFFFFF).withValues(alpha: 0.8);
        canvas.drawCircle(const Offset(12, 12), 9, _stroke(ink, 1.5));
        final ink2 = const Color(0xFFFFFFFF).withValues(alpha: 0.7);
        canvas.drawLine(const Offset(3, 12), const Offset(21, 12), _stroke(ink2, 1.2));
        _path(canvas, 'M12 3c2.5 2.5 2.5 15 0 18', stroke: ink2, sw: 1.2);
        _path(canvas, 'M12 3c-2.5 2.5-2.5 15 0 18', stroke: ink2, sw: 1.2);
      case ActivationKind.cryptoPlatega:
        canvas.drawCircle(const Offset(12, 12), 9, _stroke(accent, 1.5));
        _path(
          canvas,
          'M9.5 8h4a2 2 0 010 4h-4m0 0h4.3a2 2 0 010 4H9.5m0-8v10M11 6.5v1.5M11 16v1.5',
          stroke: accent,
          sw: 1.4,
        );
      case ActivationKind.cryptoBot:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTWH(3, 6, 18, 13), const Radius.circular(3)),
          _stroke(accent, 1.5),
        );
        _path(canvas, 'M3 10h13a2 2 0 012 2v0a2 2 0 01-2 2H3', stroke: accent, sw: 1.5);
        canvas.drawCircle(const Offset(16.5, 12), 1.2, Paint()..color = accent);
      case ActivationKind.tgStars:
        _path(
          canvas,
          'M12 3l2.6 5.7 6.2.6-4.7 4.1 1.4 6.1L12 16.4 6.5 19.6l1.4-6.1L3.2 9.3l6.2-.6L12 3z',
          fill: accent,
        );
    }
  }

  Paint _stroke(Color c, double w) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = c;

  void _path(Canvas canvas, String svg, {Color? fill, Color? stroke, double sw = 1.5}) {
    final path = _parse(svg);
    if (fill != null) canvas.drawPath(path, Paint()..color = fill);
    if (stroke != null) canvas.drawPath(path, _stroke(stroke, sw));
  }

  // Минимальный SVG path-парсер для M/L/C/Z (абс/отн) — покрывает наши глифы.
  Path _parse(String d) {
    final path = Path();
    final tokens = RegExp(r'[MmLlCcZzHhVv]|-?\d*\.?\d+').allMatches(d).map((m) => m.group(0)!).toList();
    var i = 0;
    double cx = 0, cy = 0, sx = 0, sy = 0;
    String cmd = '';
    double num() => double.parse(tokens[i++]);
    bool isCmd(String s) => RegExp(r'^[A-Za-z]$').hasMatch(s);
    while (i < tokens.length) {
      if (isCmd(tokens[i])) cmd = tokens[i++];
      switch (cmd) {
        case 'M':
          cx = num(); cy = num(); sx = cx; sy = cy; path.moveTo(cx, cy); cmd = 'L';
        case 'm':
          cx += num(); cy += num(); sx = cx; sy = cy; path.moveTo(cx, cy); cmd = 'l';
        case 'L':
          cx = num(); cy = num(); path.lineTo(cx, cy);
        case 'l':
          cx += num(); cy += num(); path.lineTo(cx, cy);
        case 'H':
          cx = num(); path.lineTo(cx, cy);
        case 'h':
          cx += num(); path.lineTo(cx, cy);
        case 'V':
          cy = num(); path.lineTo(cx, cy);
        case 'v':
          cy += num(); path.lineTo(cx, cy);
        case 'C':
          final x1 = num(), y1 = num(), x2 = num(), y2 = num(), x = num(), y = num();
          path.cubicTo(x1, y1, x2, y2, x, y); cx = x; cy = y;
        case 'c':
          final x1 = cx + num(), y1 = cy + num(), x2 = cx + num(), y2 = cy + num(), x = cx + num(), y = cy + num();
          path.cubicTo(x1, y1, x2, y2, x, y); cx = x; cy = y;
        case 'Z':
        case 'z':
          path.close(); cx = sx; cy = sy;
        default:
          i++; // неизвестный токен — пропускаем
      }
    }
    return path;
  }

  @override
  bool shouldRepaint(_GlyphPainter old) => old.kind != kind || old.accent != accent;
}
