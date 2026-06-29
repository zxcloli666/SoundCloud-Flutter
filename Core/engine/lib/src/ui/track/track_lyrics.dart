import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../providers.dart';
import '../../rust/dto.dart';

/// Панель лирики трека (`lyricsProvider`). Разворачивается по кнопке «Текст» в
/// рельсе действий. scTrackId — голый id из urn (`soundcloud:tracks:NNN` → `NNN`).
class TrackLyrics extends ConsumerWidget {
  final String urn;

  const TrackLyrics({super.key, required this.urn});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scId = _bareId(urn);
    final lyrics = ref.watch(lyricsProvider(scId));

    return GlassPanel(
      radius: ScTokens.rHero,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(
        height: 420,
        child: lyrics.when(
          loading: () => const LyricsPanel(
            status: LyricsStatus.loading,
            loadingLabel: 'Загружаем текст…',
          ),
          error: (_, __) => const LyricsPanel(
            status: LyricsStatus.notFound,
            notFoundTitle: 'Текст не найден',
            notFoundHint: 'Не удалось сопоставить этот трек.',
          ),
          data: (dto) => _panel(dto, ref),
        ),
      ),
    );
  }

  Widget _panel(LyricsDto? dto, WidgetRef ref) {
    if (dto == null || dto.lines.isEmpty) {
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
      return LyricsPanel(
        status: LyricsStatus.synced,
        sourceLabel: source,
        syncedLines: lines,
        onSeekLine: (secs) => ref.read(playerProvider.notifier).seekTo(secs),
      );
    }
    return LyricsPanel(
      status: LyricsStatus.plain,
      sourceLabel: source,
      plainText: dto.lines.map((l) => l.text).join('\n'),
    );
  }
}

String _bareId(String urn) {
  final i = urn.lastIndexOf(':');
  return i >= 0 ? urn.substring(i + 1) : urn;
}
