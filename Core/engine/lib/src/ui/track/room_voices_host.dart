import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../providers.dart';
import '../../rust/dto.dart';

/// Хост секции «голоса слушателей»: грузит комментарии трека, мапит в
/// [VoiceCardData], даёт i18n-подписи и живой момент воспроизведения (если этот
/// трек играет), прокидывает seek/постинг/переход к автору.
class RoomVoicesHost extends ConsumerStatefulWidget {
  final String urn;

  const RoomVoicesHost({super.key, required this.urn});

  @override
  ConsumerState<RoomVoicesHost> createState() => _RoomVoicesHostState();
}

class _RoomVoicesHostState extends ConsumerState<RoomVoicesHost> {
  final ValueNotifier<double> _position = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(trackCommentsProvider.notifier).load(widget.urn);
    });
  }

  @override
  void dispose() {
    _position.dispose();
    super.dispose();
  }

  bool get _isCurrent {
    final urn = ref.read(playerProvider)?.urn;
    return urn != null && urn.split(':').last == widget.urn.split(':').last;
  }

  @override
  Widget build(BuildContext context) {
    // Живой момент для композера — только если этот трек сейчас играет.
    ref.listen(positionStreamProvider, (_, next) {
      final secs = next.value;
      if (secs != null && _isCurrent) _position.value = secs;
    });

    final state = ref.watch(trackCommentsProvider);
    final data = state.value;
    final notifier = ref.read(trackCommentsProvider.notifier);
    final isCurrent = ref.watch(playerProvider.select((t) => t?.urn)) != null &&
        _isCurrent;

    return RoomVoices(
      comments: [for (final c in data?.comments ?? const <CommentDto>[]) _card(c)],
      loading: state.isLoading && (data == null || data.comments.isEmpty),
      loadingMore: data?.loadingMore ?? false,
      accent: ScTheme.paletteOf(context).accent,
      position: isCurrent ? _position : null,
      labels: RoomVoicesLabels(
        title: ref.tr('track.listenersVoices'),
        empty: ref.tr('track.noComments'),
        addCommentHint: ref.tr('track.addComment'),
        commentAt: ref.tr('track.commentAt'),
      ),
      onSeek: (secs) => ref.read(playerProvider.notifier).seekTo(secs),
      onUserTap: (urn) => ref.read(routerProvider.notifier).push(UserRoute(urn)),
      onPost: (body, ms) => notifier.post(body, timestampMs: ms),
      onLoadMore: (data?.hasMore ?? false) ? notifier.more : null,
    );
  }

  VoiceCardData _card(CommentDto c) => VoiceCardData(
        username: c.username,
        userUrn: c.userUrn,
        body: c.body,
        avatarUrl: c.avatarUrl,
        createdAt: c.createdAt ?? '',
        timestampMs: c.timestampMs?.toInt(),
      );
}
