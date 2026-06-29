import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../providers.dart';
import '../../rust/api.dart';
import 'artist_aura.dart';
import 'artist_track_mapping.dart';

/// Строка трека вкладок артиста (легаси `ThemedTrackRow`): параметрический
/// [TrackRow] с подсветкой по ауре, привязанный к плееру (тап = играть в
/// контексте [queue]). Подсветка активного ряда — праймери ауры.
class ThemedTrackRow extends ConsumerWidget {
  final TrackDto track;
  final int index; // 1-based
  final List<TrackDto> queue;
  final ArtistAura aura;

  const ThemedTrackRow({
    super.key,
    required this.track,
    required this.index,
    required this.queue,
    required this.aura,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(playerProvider);
    final isCurrent = current?.urn == track.urn;

    return TrackRow(
      data: artistTrackRow(track),
      index: index,
      highlight: aura.primary,
      lightHighlight: _isLight(aura.primary),
      current: isCurrent,
      playing: isCurrent,
      onPlay: () => _play(context, ref),
    );
  }

  Future<void> _play(BuildContext context, WidgetRef ref) async {
    final messenger = ToastScope.of(context);
    try {
      // Queue-aware: список вкладки становится контекстом очереди.
      await ref.read(playerProvider.notifier).play(track, queue: queue);
    } catch (error) {
      messenger.show('Не удалось воспроизвести: $error', kind: ToastKind.error);
    }
  }
}

/// `isLight(aura)` (§5.6): светлая аура → чёрная иконка play/pause.
bool _isLight(Color c) => (0.299 * c.r + 0.587 * c.g + 0.114 * c.b) > 0.78;
