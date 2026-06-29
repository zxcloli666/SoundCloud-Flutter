import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../providers.dart';
import '../../rust/api.dart';

/// Пол комнаты: живая [LiveWaveform], перекрашенная в [accent] трека, с линейкой
/// времени под ней. Прогресс/seek активны только когда [isCurrent] (этот трек
/// играет) — позиция приходит из стрима ядра, не дёргая лишних rebuild'ов всей
/// страницы (изолировано в этом виджете через `ref.watch(positionStream)`).
class TrackWaveform extends ConsumerWidget {
  final TrackDto track;
  final bool isCurrent;
  final Color accent;

  const TrackWaveform({
    super.key,
    required this.track,
    required this.isCurrent,
    required this.accent,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final durationMs = track.durationMs.toInt();
    final position = isCurrent ? (ref.watch(positionStreamProvider).value ?? 0.0) : 0.0;
    final durationSecs = durationMs / 1000.0;
    final progress = durationSecs > 0 ? (position / durationSecs).clamp(0.0, 1.0) : 0.0;
    // Реальная огибающая по waveform_url трека; пока мост не отдал — стабильная
    // синтетическая форма (та же между перерисовками, сид из urn).
    final real = ref.watch(waveformProvider(track.waveformUrl ?? '')).value;
    final samples = (real != null && real.isNotEmpty)
        ? real
        : _syntheticSamples(track.urn);

    return ScTheme(
      // Локально подменяем акцент палитры на цвет жанра — waveform читает
      // `paletteOf(context).accent`, так бар прокрашивается в хью комнаты.
      palette: ScPalette(accent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LiveWaveform(
            samples: samples,
            progress: progress,
            seekable: isCurrent,
            onSeek: isCurrent && durationSecs > 0
                ? (frac) => ref.read(playerProvider.notifier).seekTo(frac * durationSecs)
                : null,
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  formatDurationLong((position * 1000).round()),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0x59FFFFFF), // white/35
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  formatDurationLong(durationMs),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0x59FFFFFF),
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Фолбэк-огибающая по urn, когда реальных сэмплов нет (нет `waveformUrl` или
/// ядро ещё не отдало): детерминированная и стабильная между перерисовками.
/// Сид из urn → плавная псевдослучайная амплитуда 0..1.
List<double> _syntheticSamples(String urn) {
  final rng = math.Random(urn.hashCode);
  const count = 200;
  final out = List<double>.filled(count, 0);
  var level = 0.5;
  for (var i = 0; i < count; i++) {
    level += (rng.nextDouble() - 0.5) * 0.4;
    level = level.clamp(0.12, 1.0);
    // Лёгкое затухание к краям — натуральнее, чем ровная стена.
    final edge = math.sin(math.pi * i / (count - 1));
    out[i] = level * (0.55 + 0.45 * edge);
  }
  return out;
}
