import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../../providers.dart';
import '../../../rust/api.dart';

/// Очередь NowBar: [QueuePanel] поверх активного [queueContextProvider]. Тап по
/// строке играет этот трек тем же списком (контекст не теряется); пустой
/// контекст рисует пустое состояние самой панели.
class QueueHost extends ConsumerWidget {
  final VoidCallback onClose;

  const QueueHost({super.key, required this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctx = ref.watch(queueContextProvider);
    final playing = ref.watch(isPlayingProvider);
    final tracks = ctx?.tracks ?? const <TrackDto>[];

    return QueuePanel(
      title: 'Очередь',
      clearLabel: 'Очистить',
      nowPlayingLabel: 'СЕЙЧАС ИГРАЕТ',
      upNextLabel: 'ДАЛЕЕ',
      emptyTitle: 'Очередь пуста',
      emptyHint: 'Треки, которые вы запустите, появятся здесь.',
      currentIndex: ctx?.index ?? -1,
      isPlaying: playing,
      queue: [
        for (final t in tracks)
          QueueEntry(
            urn: t.urn,
            title: t.title,
            artistLine: t.artistName,
            artworkUrl: t.artworkUrl,
            durationMs: t.durationMs.toInt(),
          ),
      ],
      onClose: onClose,
      onTapEntry: (index) {
        if (ctx == null || index < 0 || index >= tracks.length) return;
        if (index == ctx.index) {
          ref.read(playerProvider.notifier).togglePause();
          return;
        }
        ref.read(playerProvider.notifier).play(tracks[index], queue: tracks);
      },
    );
  }
}
