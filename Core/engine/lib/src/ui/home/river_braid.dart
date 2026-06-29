import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:sc_visual/sc_visual.dart';

/// Роль якоря в русле (легаси `AnchorKind`): node — точка русла, branch — правый
/// приток (отводится веткой), delta — финальная точка-схождение.
enum RiverAnchorKind { node, branch, delta }

/// Слот якоря: ключ виджета (для измерения геометрии) + его роль. Регистрируется
/// секцией, читается [RiverBraid].
class RiverAnchorSlot {
  final GlobalKey key;
  final RiverAnchorKind kind;

  const RiverAnchorSlot({required this.key, required this.kind});
}

/// SVG-река через всю колонку секций: путь строится по геометрии якорей
/// (позиция/размер относительно обёртки), пересборка — после кадра и при смене
/// [layoutKey] (смена состава секций). Слои обводки (легаси `RiverBraid`):
/// широкое свечение → среднее → ядро → бегущий пунктир течения. Пунктир
/// анимируется `AnimationController` и паузится при сворачивании окна.
class RiverBraid extends StatefulWidget {
  final Map<String, RiverAnchorSlot> anchors;
  final String layoutKey;
  final Widget child;

  const RiverBraid({
    super.key,
    required this.anchors,
    required this.layoutKey,
    required this.child,
  });

  @override
  State<RiverBraid> createState() => _RiverBraidState();
}

class _RiverBraidState extends State<RiverBraid>
    with SingleTickerProviderStateMixin {
  final _wrapKey = GlobalKey();
  _RiverGeometry? _geo;

  // Течение реки — выделенный тикер (река = ОДИН CustomPaint, не десятки тайлов,
  // поэтому свой тикер оправдан). Кадры троттлятся до ~30fps: плавнее, чем
  // 10fps-AmbientClock, но не жжёт на 165Гц-vsync. Часы — repaint-listenable для
  // CustomPaint; тикер живёт ТОЛЬКО пока река видна и анимируется (gate idleAnim).
  late final Ticker _ticker = createTicker(_onTick);
  final ValueNotifier<double> _clock = ValueNotifier<double>(0);
  Duration _lastPaint = Duration.zero;
  static const _frame = Duration(milliseconds: 33); // ~30fps

  @override
  void initState() {
    super.initState();
    // Якоря-секции репортят геометрию в СВОИХ postFrame (позже нашего initState),
    // поэтому один замер на первом кадре видит пустой anchors. Доводим несколько
    // кадров, пока якоря не осядут (после — setState не срабатывает, цикл затихает).
    _settle(12);
  }

  void _onTick(Duration elapsed) {
    if (elapsed - _lastPaint < _frame) return;
    _lastPaint = elapsed;
    _clock.value = elapsed.inMicroseconds / 1e6;
  }

  /// Пере-замер на ближайших [tries] кадрах (ловит постепенно оседающие якоря).
  void _settle(int tries) {
    if (!mounted || tries <= 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rebuild();
      _settle(tries - 1);
    });
  }

  void _syncDash(bool animate) {
    if (animate && !_ticker.isActive) {
      _ticker.start();
    } else if (!animate && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void didUpdateWidget(RiverBraid old) {
    super.didUpdateWidget(old);
    if (old.layoutKey != widget.layoutKey) {
      _settle(12);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (!mounted) return;
    final geo = _measure();
    if (geo != null && geo != _geo) {
      setState(() => _geo = geo);
    }
  }

  _RiverGeometry? _measure() {
    final wrap = _wrapKey.currentContext?.findRenderObject() as RenderBox?;
    if (wrap == null || !wrap.hasSize || wrap.size.isEmpty) return null;

    final slots = widget.anchors.entries
        .where((e) => e.value.key.currentContext != null)
        .toList();
    if (slots.isEmpty) return null;

    final channel = <_AnchorRect>[];
    final branches = <_AnchorRect>[];
    for (final entry in slots) {
      final box = entry.value.key.currentContext!.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final origin = box.localToGlobal(Offset.zero, ancestor: wrap);
      final rect = _AnchorRect(
        kind: entry.value.kind,
        rect: origin & box.size,
      );
      if (entry.value.kind == RiverAnchorKind.branch) {
        branches.add(rect);
      } else {
        channel.add(rect);
      }
    }
    if (channel.isEmpty) return null;
    channel.sort((a, b) => a.rect.top.compareTo(b.rect.top));

    final w = wrap.size.width;
    final h = wrap.size.height;
    final pts = <Offset>[Offset(w * 0.56, -36)];
    for (final a in channel) {
      pts.add(a.kind == RiverAnchorKind.delta
          ? Offset(a.rect.left + a.rect.width / 2, a.rect.top + 18)
          : Offset(a.rect.left + 26, a.rect.top + 12));
    }

    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      final a = pts[i - 1];
      final b = pts[i];
      final dy = b.dy - a.dy;
      final bulge = (i.isOdd ? 1 : -1) * math.min(170.0, dy.abs() * 0.55);
      path.cubicTo(
        a.dx + bulge, a.dy + dy * 0.45,
        b.dx + bulge * 0.5, b.dy - dy * 0.45,
        b.dx, b.dy,
      );
    }

    final branchPaths = <Path>[];
    for (final br in branches) {
      final tx = br.rect.left + 14;
      final ty = br.rect.top + 46;
      var sx = pts.first.dx;
      for (final p in pts) {
        if (p.dy <= ty) sx = p.dx;
      }
      final sy = ty - 170;
      branchPaths.add(Path()
        ..moveTo(sx, sy)
        ..cubicTo(sx + 60, sy + 90, tx - 160, ty, tx, ty));
    }

    return _RiverGeometry(
      size: Size(w, h),
      path: path,
      branches: branchPaths,
      nodes: pts.sublist(1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = ScTheme.paletteOf(context);
    final perf = ScPerf.profileOf(context);
    final wide = MediaQuery.sizeOf(context).width >= 1024;
    final showRiver = wide && _geo != null;
    final animate = showRiver && perf.idleAnim;
    _syncDash(animate);

    Widget? river;
    if (showRiver) {
      _RiverPainter painter(double dashPhase) => _RiverPainter(
            geo: _geo!,
            accent: palette.accent,
            accentHover: palette.accentHover,
            bloom: perf.bloom,
            idle: perf.idleAnim,
            dashPhase: dashPhase,
          );
      river = Positioned.fill(
        child: IgnorePointer(
          child: animate
              ? AnimatedBuilder(
                  animation: _clock,
                  builder: (context, _) => CustomPaint(
                    painter: painter(_clock.value),
                  ),
                )
              : CustomPaint(painter: painter(0)),
        ),
      );
    }

    return Stack(
      key: _wrapKey,
      children: [
        if (river != null) river,
        widget.child,
      ],
    );
  }
}

class _AnchorRect {
  final RiverAnchorKind kind;
  final Rect rect;
  const _AnchorRect({required this.kind, required this.rect});
}

class _RiverGeometry {
  final Size size;
  final Path path;
  final List<Path> branches;
  final List<Offset> nodes;

  const _RiverGeometry({
    required this.size,
    required this.path,
    required this.branches,
    required this.nodes,
  });

  @override
  int get hashCode => Object.hash(size, nodes.length, branches.length);

  @override
  bool operator ==(Object other) =>
      other is _RiverGeometry &&
      other.size == size &&
      other.nodes.length == nodes.length &&
      other.branches.length == branches.length;
}

/// Четыре слоя обводки реки (легаси): свечение 72px → среднее 14px → ядро 1.7px
/// → бегущий пунктир. Вертикальный градиент tint0→tint1→tint2 (здесь accent).
class _RiverPainter extends CustomPainter {
  final _RiverGeometry geo;
  final Color accent;
  final Color accentHover;
  final bool bloom;
  final bool idle;
  final double dashPhase;

  _RiverPainter({
    required this.geo,
    required this.accent,
    required this.accentHover,
    required this.bloom,
    required this.idle,
    required this.dashPhase,
  });

  /// Вертикальный градиент реки (accent 0.8→0.55→0.3) с общим множителем альфы —
  /// так слои-свечения = тот же градиент, но тусклее (легаси: `opacity` поверх
  /// `url(#riv-fg)`). Множитель печём в альфу, чтобы не плодить saveLayer.
  Shader _grad(double mul) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          accent.withValues(alpha: 0.8 * mul),
          accent.withValues(alpha: 0.55 * mul),
          accent.withValues(alpha: 0.3 * mul),
        ],
        stops: const [0, 0.5, 1],
      ).createShader(Offset.zero & geo.size);

  Paint _stroke(double width, double mul, {StrokeCap cap = StrokeCap.butt}) =>
      Paint()
        ..shader = _grad(mul)
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = cap;

  /// Размытая обводка-гало: широкий мягкий штрих (`MaskFilter.blur`) — даёт
  /// диффузное свечение «неоновой трубки», как в легаси (72/14px при blur 24/6).
  Paint _glow(double width, double mul, double sigma) => Paint()
    ..shader = _grad(mul)
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma);

  @override
  void paint(Canvas canvas, Size size) {
    // Свечение реки — мягкое размытое гало (как в легаси: широкие штрихи с blur),
    // НЕ жёсткая лента: широкий тусклый + средний поярче, поверх — тонкое ядро.
    if (bloom) {
      canvas.drawPath(geo.path, _glow(34, 0.14, 11));
      canvas.drawPath(geo.path, _glow(12, 0.20, 4));
    }

    // Ядро — тонкая чёткая линия поверх гало.
    canvas.drawPath(geo.path, _stroke(1.6, 0.72));

    // Бегущий пунктир течения (легаси: offset 0→-680 за 18с и 0→-640 за 9с —
    // ≈37.8 и ≈71 px/с; `dashPhase` теперь время в секундах).
    if (idle) {
      _drawDashes(canvas, geo.path,
          color: accent.withValues(alpha: 0.5),
          width: 2.2,
          dash: 3,
          gap: 15,
          phase: dashPhase * 37.8);
      _drawDashes(canvas, geo.path,
          color: accentHover.withValues(alpha: 0.75),
          width: 1.3,
          dash: 2,
          gap: 30,
          phase: dashPhase * 71.1);
    }

    // Притоки.
    for (final b in geo.branches) {
      canvas.drawPath(b, _stroke(1.2, 0.35));
    }

    // Узлы русла.
    for (final p in geo.nodes) {
      canvas.drawCircle(p, 9, Paint()..color = accent.withValues(alpha: 0.1));
      canvas.drawCircle(p, 2.8, Paint()..color = accent.withValues(alpha: 0.6));
    }
  }

  void _drawDashes(
    Canvas canvas,
    Path src, {
    required Color color,
    required double width,
    required double dash,
    required double gap,
    required double phase,
  }) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    final span = dash + gap;
    for (final metric in src.computeMetrics()) {
      // Фаза растёт → d растёт → пунктир едет к БОЛЬШЕЙ длине дуги (исток→дельта,
      // вниз по течению). Старт на span назад, чтобы не было пустого края.
      var d = (phase % span) - span;
      while (d < metric.length) {
        final start = math.max(0.0, d);
        final end = math.min(metric.length, d + dash);
        if (end > start) {
          canvas.drawPath(metric.extractPath(start, end), paint);
        }
        d += span;
      }
    }
  }

  @override
  bool shouldRepaint(_RiverPainter old) =>
      old.dashPhase != dashPhase ||
      old.geo != geo ||
      old.accent != accent ||
      old.bloom != bloom ||
      old.idle != idle;
}
