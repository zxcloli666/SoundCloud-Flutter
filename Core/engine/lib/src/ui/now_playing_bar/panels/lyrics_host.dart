import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../../providers.dart';
import '../../../rust/dto.dart';
import 'lyrics_visualizer_host.dart';

/// Лирика NowBar: [LyricsPanel] поверх `lyricsProvider`. Для synced строк
/// плейхед (активная строка + прогресс) гонится из [positionStreamProvider] в
/// собственный [ValueNotifier] — список не перестраивается на тик. Plain —
/// просто текст; нет лирики — пустое состояние.
class LyricsHost extends ConsumerStatefulWidget {
  final String urn;

  const LyricsHost({super.key, required this.urn});

  @override
  ConsumerState<LyricsHost> createState() => _LyricsHostState();
}

class _LyricsHostState extends ConsumerState<LyricsHost> {
  final ValueNotifier<LyricsPlayhead> _playhead =
      ValueNotifier(const LyricsPlayhead());

  /// Кэш таймкодов текущей synced-лирики для вычисления плейхеда по позиции.
  List<double> _lineTimes = const [];

  @override
  void dispose() {
    _playhead.dispose();
    super.dispose();
  }

  String get _scId => widget.urn.split(':').last;

  @override
  Widget build(BuildContext context) {
    ref.listen(positionStreamProvider, (_, next) {
      final pos = next.value;
      if (pos != null) _drivePlayhead(pos);
    });

    final lyrics = ref.watch(lyricsProvider(_scId));
    final perChar = ScPerf.of(context) != PerfMode.light;

    final panel = lyrics.when(
      loading: () => const LyricsPanel(
        status: LyricsStatus.loading,
        loadingLabel: 'Загружаем текст…',
      ),
      error: (_, __) => const LyricsPanel(
        status: LyricsStatus.notFound,
        notFoundTitle: 'Текст не найден',
        notFoundHint: 'Не удалось сопоставить этот трек.',
      ),
      data: (dto) => _panel(dto, perChar),
    );

    // Визуализатор спектра под текстом — отдельный тумблер настроек, beauty-эффект
    // (в light-режиме выключаем). Управляется аудио, не лирикой, поэтому кроет
    // любое состояние панели.
    final showVisualizer =
        ref.watch(settingsProvider.select((s) => s.lyricsVisualizer)) &&
            ScPerf.of(context) != PerfMode.light;
    if (!showVisualizer) return panel;
    return Stack(
      children: [
        const Positioned.fill(child: LyricsVisualizerHost()),
        panel,
      ],
    );
  }

  Widget _panel(LyricsDto? dto, bool perChar) {
    if (dto == null || dto.lines.isEmpty) {
      _lineTimes = const [];
      return const LyricsPanel(
        status: LyricsStatus.notFound,
        notFoundTitle: 'Текст не найден',
        notFoundHint: 'Не удалось сопоставить этот трек.',
      );
    }

    final source = dto.source ?? '';
    if (dto.synced) {
      final lines = [
        for (final l in dto.lines)
          LyricLineData(timeSecs: (l.atMs?.toDouble() ?? 0) / 1000.0, text: l.text),
      ];
      _lineTimes = [for (final l in lines) l.timeSecs];
      return LyricsPanel(
        status: LyricsStatus.synced,
        sourceLabel: source,
        syncedLines: lines,
        playhead: _playhead,
        perChar: perChar,
        onSeekLine: (secs) => ref.read(playerProvider.notifier).seekTo(secs),
      );
    }

    _lineTimes = const [];
    return LyricsPanel(
      status: LyricsStatus.plain,
      sourceLabel: source,
      plainText: dto.lines.map((l) => l.text).join('\n'),
    );
  }

  /// Активная строка = последняя, чьё время ≤ позиции; прогресс — линейная доля
  /// до следующей строки (последняя тянется секунду, как в легаси).
  void _drivePlayhead(double position) {
    final times = _lineTimes;
    if (times.isEmpty) return;

    var active = -1;
    for (var i = 0; i < times.length; i++) {
      if (times[i] <= position) {
        active = i;
      } else {
        break;
      }
    }

    var progress = 0.0;
    if (active >= 0) {
      final start = times[active];
      final end = active + 1 < times.length ? times[active + 1] : start + 1.0;
      final span = end - start;
      if (span > 0) progress = ((position - start) / span).clamp(0.0, 1.0);
    }

    final next = LyricsPlayhead(activeIndex: active, lineProgress: progress);
    if (next != _playhead.value) _playhead.value = next;
  }
}
