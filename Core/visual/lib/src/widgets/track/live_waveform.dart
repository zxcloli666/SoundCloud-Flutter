import 'package:flutter/widgets.dart';

import '../../perf.dart';
import '../../theme.dart';

/// Кол-во баров по перф-режиму (§4.7): light 64 / medium 120 / beauty 160.
int waveformBarCount(PerfMode mode) => switch (mode) {
      PerfMode.beauty => 160,
      PerfMode.medium => 120,
      PerfMode.light => 64,
    };

/// Живая waveform трека (легаси `soundwave/waveform`). [samples] — нормированные
/// 0..1 значения из SC waveform JSON; ресэмплятся под перф. Прогресс [progress]
/// 0..1 открывает акцентный слой слева направо. Клик → [onSeek] (доля 0..1),
/// активен только если [seekable] (текущий трек).
class LiveWaveform extends StatelessWidget {
  final List<double> samples;
  final double progress;
  final bool seekable;
  final ValueChanged<double>? onSeek;
  final double height;

  /// Рисовать вертикальную полоску проигрывания на позиции [progress] (легаси
  /// `--sw-progress` хинт): акцентная линия со свечением.
  final bool playhead;

  const LiveWaveform({
    super.key,
    required this.samples,
    this.progress = 0,
    this.seekable = false,
    this.onSeek,
    this.height = 96,
    this.playhead = false,
  });

  @override
  Widget build(BuildContext context) {
    final mode = ScPerf.of(context);
    final accent = ScTheme.paletteOf(context).accent;
    final bars = _resample(samples, waveformBarCount(mode));

    Widget painter = CustomPaint(
      size: Size.infinite,
      painter: _WaveformPainter(
        bars: bars,
        progress: progress.clamp(0.0, 1.0),
        accent: accent,
        glow: mode == PerfMode.beauty,
        playhead: playhead,
      ),
    );

    if (seekable && onSeek != null) {
      painter = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) {
          final box = context.findRenderObject() as RenderBox?;
          if (box == null) return;
          final local = box.globalToLocal(d.globalPosition);
          onSeek!.call((local.dx / box.size.width).clamp(0.0, 1.0));
        },
        child: painter,
      );
    }

    return SizedBox(height: height, child: painter);
  }
}

/// Нормировка значения бара (легаси `0.18 + min(0.82, avg*0.95)`).
double _barValue(double avg) => 0.18 + (avg * 0.95).clamp(0.0, 0.82);

List<double> _resample(List<double> src, int count) {
  if (src.isEmpty) return List.filled(count, _barValue(0));
  final out = List<double>.filled(count, 0);
  final ratio = src.length / count;
  for (var i = 0; i < count; i++) {
    final start = (i * ratio).floor();
    final end = ((i + 1) * ratio).ceil().clamp(start + 1, src.length);
    var sum = 0.0;
    for (var j = start; j < end; j++) {
      sum += src[j];
    }
    out[i] = _barValue(sum / (end - start));
  }
  return out;
}

class _WaveformPainter extends CustomPainter {
  final List<double> bars;
  final double progress;
  final Color accent;
  final bool glow;
  final bool playhead;

  _WaveformPainter({
    required this.bars,
    required this.progress,
    required this.accent,
    required this.glow,
    required this.playhead,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;
    final slot = size.width / bars.length;
    final barW = slot * 0.62;
    final cy = size.height / 2;
    final revealX = size.width * progress.clamp(0.0, 1.0);

    final muted = Paint()..color = const Color(0x38FFFFFF); // white/0.22
    final played = Paint()..color = accent;
    final playedGlow = glow
        ? (Paint()
          ..color = accent.withValues(alpha: 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4))
        : null;

    // Все бары — приглушённо; затем сыгранный слой клипуем по revealX. Граница
    // режется по пикселю, бар на стыке заливается частично → плавный прогресс
    // (а не «резкое» переключение целых баров).
    final rects = <RRect>[];
    for (var i = 0; i < bars.length; i++) {
      final x = i * slot + (slot - barW) / 2;
      final h = bars[i] * size.height;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, cy - h / 2, barW, h),
        const Radius.circular(1.5),
      );
      rects.add(rect);
      canvas.drawRRect(rect, muted);
    }

    if (revealX > 0) {
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, 0, revealX, size.height));
      for (final rect in rects) {
        if (rect.left > revealX) break; // правее границы — пропускаем
        if (playedGlow != null) canvas.drawRRect(rect, playedGlow);
        canvas.drawRRect(rect, played);
      }
      canvas.restore();
    }

    // Полоска проигрывания (легаси `--sw-progress` хинт): акцентная линия 2px на
    // позиции, со свечением в beauty.
    if (playhead) {
      if (glow) {
        canvas.drawRect(
          Rect.fromLTWH(revealX - 4, 0, 8, size.height),
          Paint()
            ..color = accent.withValues(alpha: 0.45)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(revealX - 1, 0, 2, size.height),
          const Radius.circular(2),
        ),
        Paint()..color = accent,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.progress != progress ||
      old.accent != accent ||
      old.bars != bars ||
      old.playhead != playhead;
}
