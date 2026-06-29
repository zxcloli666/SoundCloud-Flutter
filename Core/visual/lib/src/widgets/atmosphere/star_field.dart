import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../ambient_clock.dart';
import '../../perf.dart';
import '../../theme.dart';

/// Звёздное поле фона (порт легаси `StarField`): мерцающие точки + блёстки,
/// окрашенные тремя орб-цветами из акцента. Атмосфера, поэтому перф-гейтед:
/// в light не рисуется, в medium частиц меньше и без свечения, в beauty — всё.
/// Один тикер на все звёзды; статичен (без перерисовок), если idle-анимаций нет.
class ScStarField extends StatefulWidget {
  /// Масштаб яркости мерцания (0..1).
  final double intensity;

  /// Разрешить per-звёздное свечение (в beauty). Дешёвые страницы шлют false.
  final bool glow;

  /// Орб-цвета (3 шт). По умолчанию выводятся из акцента темы.
  final List<Color>? orbs;

  const ScStarField({
    super.key,
    this.intensity = 0.6,
    this.glow = true,
    this.orbs,
  });

  @override
  State<ScStarField> createState() => _ScStarFieldState();
}

class _ScStarFieldState extends State<ScStarField> {
  // Мерцание гоним ОБЩИМИ амбиент-часами (один ~10fps-таймер на всё приложение),
  // а не своим AnimationController/таймером: один источник кадров для всей фоновой
  // анимации (обложки/река/портал/звёзды) → не плодим параллельные кадры. Плюс
  // RepaintBoundary (ниже) изолирует репейнт звёзд от страницы.
  bool _sub = false;

  late final List<_Dot> _dots = _buildDots();
  late final List<_Star> _stars = _buildStars();

  void _sync(bool animate) {
    if (animate && !_sub) {
      _sub = true;
      AmbientClock.instance.subscribe();
    } else if (!animate && _sub) {
      _sub = false;
      AmbientClock.instance.unsubscribe();
    }
  }

  @override
  void dispose() {
    if (_sub) AmbientClock.instance.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final perf = PerfProfile.of(context);
    if (!perf.atmosphere) {
      _sync(false);
      return const SizedBox.shrink();
    }

    final orbs = widget.orbs ?? _orbsFromAccent(ScTheme.paletteOf(context).accent);
    final dots = _dots.take(perf.particles(_dots.length)).toList();
    final stars = _stars.take(perf.particles(_stars.length)).toList();
    if (dots.isEmpty && stars.isEmpty) {
      _sync(false);
      return const SizedBox.shrink();
    }
    _sync(perf.idleAnim);

    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _StarFieldPainter(
            dots: dots,
            stars: stars,
            orbs: orbs,
            intensity: widget.intensity,
            glow: widget.glow && perf.glow,
            time: AmbientClock.instance.tick,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

/// Три орб-цвета из акцента: сам акцент + сдвиги по тону (±28°).
List<Color> _orbsFromAccent(Color accent) {
  final hsl = HSLColor.fromColor(accent);
  Color shift(double deg, double light) => hsl
      .withHue((hsl.hue + deg) % 360)
      .withLightness((hsl.lightness * light).clamp(0.0, 1.0))
      .toColor();
  return [accent, shift(28, 1.12), shift(-28, 0.92)];
}

class _Dot {
  final double size, left, top, delay, duration, min, max;
  final int orb;
  const _Dot(this.size, this.left, this.top, this.delay, this.duration,
      this.min, this.max, this.orb);
}

class _Star {
  final double size, left, top, rot, delay, duration, min, max;
  final int orb;
  const _Star(this.size, this.left, this.top, this.rot, this.delay,
      this.duration, this.min, this.max, this.orb);
}

List<_Dot> _buildDots() => [
      for (var i = 0; i < 44; i++)
        _Dot(
          2 + (i % 3).toDouble(),
          ((i * 71) % 100).toDouble(),
          ((i * 29) % 100).toDouble(),
          (i * 0.31) % 4,
          3 + (i % 4).toDouble(),
          0.2 + (i % 3) * 0.1,
          0.55 + (i % 3) * 0.12,
          i % 3,
        ),
    ];

List<_Star> _buildStars() => [
      for (var i = 0; i < 46; i++)
        () {
          final k = i + 7;
          return _Star(
            6 + ((k * 7) % 14).toDouble(),
            ((k * 37) % 100).toDouble(),
            ((k * 53) % 100).toDouble(),
            ((k * 41) % 360).toDouble(),
            (k * 0.27) % 5,
            4 + (k % 5).toDouble(),
            0.18 + (k % 4) * 0.06,
            0.55 + (k % 4) * 0.12,
            i % 3,
          );
        }(),
    ];

class _StarFieldPainter extends CustomPainter {
  final List<_Dot> dots;
  final List<_Star> stars;
  final List<Color> orbs;
  final double intensity;
  final bool glow;

  /// Источник времени (таймер ~11fps): репейнт триггерится им, без 165Гц-тикера.
  final ValueListenable<double> time;

  _StarFieldPainter({
    required this.dots,
    required this.stars,
    required this.orbs,
    required this.intensity,
    required this.glow,
    required this.time,
  }) : super(repaint: time);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;
    final t = time.value;

    for (final d in dots) {
      final opacity = _twinkle(t, d.duration, d.delay, d.min, d.max);
      _drawDot(canvas, Offset(d.left / 100 * w, d.top / 100 * h), d.size,
          orbs[d.orb].withValues(alpha: opacity));
    }
    for (final s in stars) {
      final opacity = _twinkle(t, s.duration, s.delay, s.min, s.max);
      _drawStar(canvas, Offset(s.left / 100 * w, s.top / 100 * h), s.size,
          s.rot * math.pi / 180, orbs[s.orb].withValues(alpha: opacity));
    }
  }

  /// Мерцание: синус между min и max по собственным периоду/фазе звезды.
  double _twinkle(double t, double duration, double delay, double min, double max) {
    final phase = (t / duration + delay) * 2 * math.pi;
    final v = min + (max - min) * 0.5 * (1 + math.sin(phase));
    return (v * intensity).clamp(0.0, 1.0);
  }

  void _drawDot(Canvas canvas, Offset center, double size, Color color) {
    // Дешёвое «свечение» без blur: больший полупрозрачный круг в screen-бленде
    // (per-star MaskFilter.blur пожирал CPU). Затем — само ядро.
    if (glow) {
      canvas.drawCircle(
        center,
        size * 1.6,
        Paint()
          ..color = color.withValues(alpha: color.a * 0.22)
          ..blendMode = BlendMode.screen,
      );
    }
    canvas.drawCircle(center, size / 2, Paint()..color = color);
  }

  void _drawStar(Canvas canvas, Offset center, double size, double rot, Color color) {
    final path = _sparkle(center, size / 2, rot);
    if (glow) {
      canvas.drawCircle(
        center,
        size * 0.7,
        Paint()
          ..color = color.withValues(alpha: color.a * 0.22)
          ..blendMode = BlendMode.screen,
      );
    }
    canvas.drawPath(path, Paint()..color = color);
  }

  /// 4-лучевая блёстка: внешние точки по осям, вогнутые внутренние между ними.
  Path _sparkle(Offset c, double r, double rot) {
    final inner = r * 0.32;
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final radius = i.isEven ? r : inner;
      final a = rot + i * math.pi / 4;
      final p = c + Offset(math.cos(a) * radius, math.sin(a) * radius);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(_StarFieldPainter old) =>
      old.glow != glow ||
      old.intensity != intensity ||
      old.orbs != orbs ||
      old.time != time;
}
