import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Полноэкранная волна-визуализатор лирики (порт легаси `LyricsVisualizer`):
/// 64 лог-полосы реального FFT из ядра рисуются плавной волной у нижней кромки.
/// Полоса 0 — низы слева, полоса 63 — верха справа.
///
/// Кадры приходят событиями (~30 Гц), между ними тикер сглаживает цель→показ
/// (быстрая атака ~55 мс, медленный спад ~200 мс) и сам паркуется, когда энергии
/// на экране не осталось — на паузе CPU простаивает.
class LyricsWaveVisualizer extends StatefulWidget {
  /// Последний кадр полос (длина [binCount], значения ~0..1). Источник —
  /// спектр-стрим ядра; здесь только сглаживание и отрисовка.
  final ValueListenable<Float32List> bins;
  final Color accent;

  const LyricsWaveVisualizer({
    super.key,
    required this.bins,
    required this.accent,
  });

  static const int binCount = 64;

  @override
  State<LyricsWaveVisualizer> createState() => _LyricsWaveVisualizerState();
}

class _LyricsWaveVisualizerState extends State<LyricsWaveVisualizer>
    with SingleTickerProviderStateMixin {
  static const int _bins = LyricsWaveVisualizer.binCount;

  final Float32List _display = Float32List(_bins);
  late final _WaveListenable _repaint = _WaveListenable();
  late final Ticker _ticker = createTicker(_onTick);
  Duration _lastTick = Duration.zero;

  @override
  void initState() {
    super.initState();
    widget.bins.addListener(_onBins);
  }

  @override
  void dispose() {
    widget.bins.removeListener(_onBins);
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  /// Пришёл новый кадр — будим тикер (он сам уснёт, когда волна осядет).
  void _onBins() {
    if (!_ticker.isActive) {
      _lastTick = Duration.zero;
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    final dt = _lastTick == Duration.zero
        ? 0.016
        : ((elapsed - _lastTick).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _lastTick = elapsed;

    // Атака быстрее спада: всплеск ловим резко, гаснем мягко (как в легаси).
    final attack = 1 - math.exp(-dt * 18);
    final release = 1 - math.exp(-dt * 5);
    final target = widget.bins.value;

    var energy = false;
    for (var i = 0; i < _bins; i++) {
      final t = i < target.length ? target[i] : 0.0;
      final d = _display[i];
      _display[i] = d + (t - d) * (t > d ? attack : release);
      if (_display[i] > 1e-3 || t > 1e-3) energy = true;
    }

    _repaint.tick();
    if (!energy) _ticker.stop();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ShaderMask(
        // Жёсткий пол снизу + мягкий апвард-фейд — волна «вросла» в нижнюю кромку.
        shaderCallback: (rect) => const LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black, Colors.black, Colors.transparent],
          stops: [0.0, 0.6, 1.0],
        ).createShader(rect),
        blendMode: BlendMode.dstIn,
        child: CustomPaint(
          painter: _WavePainter(_display, widget.accent, _repaint),
          size: Size.infinite,
        ),
      ),
    );
  }
}

/// Волна перерисовывается на каждый тик сглаживания, не на setState — список
/// лирики поверх не дёргается.
class _WaveListenable extends ChangeNotifier {
  void tick() => notifyListeners();
}

class _WavePainter extends CustomPainter {
  final Float32List display;
  final Color accent;

  _WavePainter(this.display, this.accent, Listenable repaint) : super(repaint: repaint);

  static const int _bins = LyricsWaveVisualizer.binCount;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    // 1-2-1 сглаживание по горизонтали — убирает «лесенку» между соседними
    // полосами, волна выходит круглой.
    final smooth = Float32List(_bins);
    smooth[0] = (display[0] * 3 + display[1]) * 0.25;
    smooth[_bins - 1] = (display[_bins - 1] * 3 + display[_bins - 2]) * 0.25;
    for (var i = 1; i < _bins - 1; i++) {
      smooth[i] = display[i - 1] * 0.25 + display[i] * 0.5 + display[i + 1] * 0.25;
    }

    final baseY = h - 6;
    final maxAmp = h * 0.78;
    final dx = w / (_bins - 1);

    var peak = 0.0;
    for (final v in display) {
      if (v > peak) peak = v;
    }
    final peakClamped = (peak * 1.3).clamp(0.0, 1.0);

    Path trace(double ampScale) {
      final path = Path()
        ..moveTo(0, baseY - smooth[0] * maxAmp * ampScale);
      for (var i = 0; i < _bins - 1; i++) {
        final xA = i * dx;
        final yA = baseY - smooth[i] * maxAmp * ampScale;
        final yB = baseY - smooth[i + 1] * maxAmp * ampScale;
        final xMid = (xA + (i + 1) * dx) * 0.5;
        final yMid = (yA + yB) * 0.5;
        path.quadraticBezierTo(xA, yA, xMid, yMid);
      }
      path.lineTo(w, baseY - smooth[_bins - 1] * maxAmp * ampScale);
      return path;
    }

    // Заливка тела вертикальным акцент-градиентом.
    final body = trace(1.0)
      ..lineTo(w, baseY)
      ..lineTo(0, baseY)
      ..close();
    final fill = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, 0),
        Offset(0, h),
        [
          accent.withValues(alpha: 0),
          accent.withValues(alpha: 0.18 * peakClamped),
          accent.withValues(alpha: 0.32 * peakClamped),
        ],
        [0.0, 0.5, 1.0],
      );
    canvas.drawPath(body, fill);

    _stroke(canvas, trace(1.0), accent, 1.0, peak, 2.4);
    _stroke(canvas, trace(0.78), Colors.white, 0.5, peak, 1.2);
  }

  /// Обводка с мягким свечением (порт `shadowBlur`): сначала размытый проход,
  /// затем чёткий поверх.
  void _stroke(Canvas canvas, Path path, Color color, double alphaMul,
      double peak, double width) {
    final alpha = ((0.45 + 0.4 * peak.clamp(0.0, 1.0)) * alphaMul).clamp(0.0, 1.0);
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = width
      ..color = color.withValues(alpha: alpha * 0.6)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 * alphaMul);
    canvas.drawPath(path, glow);

    final crisp = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = width
      ..color = color.withValues(alpha: alpha);
    canvas.drawPath(path, crisp);
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.accent != accent || !identical(old.display, display);
}
