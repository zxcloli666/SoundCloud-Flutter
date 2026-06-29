import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import '../providers.dart';
import '../rust/api.dart';
import 'now_playing_bar/transport_state.dart';

/// Мост состояния плеера → стеклянная пилюля [NowBar]. Снимок (трек, play/pause,
/// транспорт, громкость) приходит из провайдеров; живая позиция тикает в
/// собственный [ValueNotifier], чтобы перерисовывалась только дорожка прогресса,
/// а не вся пилюля на каждый `audio:tick`.
class NowBarHost extends ConsumerStatefulWidget {
  const NowBarHost({super.key});

  @override
  ConsumerState<NowBarHost> createState() => _NowBarHostState();
}

class _NowBarHostState extends ConsumerState<NowBarHost> {
  final ValueNotifier<double> _position = ValueNotifier(0);

  /// Оптимистичная реакция поверх серверного [TrackDto.userFavorite]: флипаем
  /// глиф сразу, мутацию шлём в фон, на ошибке откатываем (как TrackPage).
  /// Сбрасываются при смене трека. Дизлайка в DTO нет — стартует с false.
  bool? _likedOverride;
  bool _disliked = false;
  String? _reactedUrn;

  /// Защита AB-петли от повторного срабатывания: пока курсор не уйдёт обратно за
  /// точку A, новый seek не дёргаем (тик ~10Hz, позиция дрожит у границы B).
  bool _abLoopArmed = true;

  @override
  void dispose() {
    _position.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Позиция — в ValueNotifier, без rebuild пилюли (только лента её слушает).
    // Здесь же энфорсим AB-петлю: перейдя B, прыгаем обратно к A.
    ref.listen(positionStreamProvider, (_, next) {
      final value = next.value;
      if (value == null) return;
      _position.value = value;
      _enforceAbLoop(value);
    });

    final track = ref.watch(playerProvider);
    if (track == null) return const SizedBox.shrink();

    // Реакция привязана к текущему треку — сбрасываем оверрайды при смене.
    if (_reactedUrn != track.urn) {
      _reactedUrn = track.urn;
      _likedOverride = null;
      _disliked = false;
    }

    final playing = ref.watch(isPlayingProvider);
    final transport = ref.watch(nowBarTransportProvider);
    final volume = ref.watch(volumeProvider);
    final loading = ref.watch(playerLoadingProvider);

    final player = ref.read(playerProvider.notifier);
    final transportN = ref.read(nowBarTransportProvider.notifier);
    final liked = _likedOverride ?? (track.userFavorite ?? false);

    return NowBar(
      data: NowBarData(
        title: track.title,
        artist: track.artistName,
        artworkUrl: track.artworkUrl,
        playing: playing,
        positionListenable: _position,
        durationSecs: track.durationMs.toInt() / 1000.0,
        shuffle: transport.shuffle,
        repeat: transport.repeat,
        abLoopA: transport.abLoopA,
        abLoopB: transport.abLoopB,
        abLoopAwaitingB: transport.abLoopAwaitingB,
        liked: liked,
        disliked: _disliked,
        quality: _quality(track),
        source: _source(track),
        downloadProgress:
            loading.loading ? (loading.percent ?? 0.0) : null,
        volume: volume,
        muted: transport.muted,
      ),
      callbacks: NowBarCallbacks(
        onPlayPause: player.togglePause,
        onPrev: _prev,
        onNext: _next,
        onSeek: (secs) => seek(positionSecs: secs),
        onShuffle: transportN.toggleShuffle,
        onRepeat: transportN.cycleRepeat,
        onAbLoop: () {
          transportN.cycleAbLoop(_position.value);
          _abLoopArmed = true;
        },
        onLike: () => _toggleLike(track),
        onDislike: () => _toggleDislike(track),
        onEqualizer: () =>
            ref.read(nowBarPanelProvider.notifier).toggle(NowBarPanel.equalizer),
        onQueue: () =>
            ref.read(nowBarPanelProvider.notifier).toggle(NowBarPanel.queue),
        onLyrics: () =>
            ref.read(nowBarPanelProvider.notifier).toggle(NowBarPanel.lyrics),
        onArtworkTap: () => ref.read(routerProvider.notifier).push(TrackRoute(track.urn)),
        onTitleTap: () => ref.read(routerProvider.notifier).push(TrackRoute(track.urn)),
        onMuteToggle: () {
          final target = transportN.toggleMute(volume);
          ref.read(volumeProvider.notifier).set(target);
        },
        onVolume: (v) {
          if (transport.muted) transportN.toggleMute(volume);
          ref.read(volumeProvider.notifier).set(v);
        },
      ),
    );
  }

  /// Перейдя точку B активной AB-петли — прыгаем обратно к A. `_abLoopArmed`
  /// гасит дребезг у границы: повторный прыжок взводится, лишь когда курсор
  /// снова окажется до B.
  void _enforceAbLoop(double position) {
    final t = ref.read(nowBarTransportProvider);
    final a = t.abLoopA;
    final b = t.abLoopB;
    if (a == null || b == null) {
      _abLoopArmed = true;
      return;
    }
    if (position < b) {
      _abLoopArmed = true;
    } else if (_abLoopArmed) {
      _abLoopArmed = false;
      seek(positionSecs: a);
    }
  }

  /// Следующий трек. Активный список доигрывается по очереди; когда исчерпан —
  /// падаем в волну через её же конвейер ([playbackQueueProvider.onEnded]).
  /// Ручной next игнорирует repeat-one (это явный пропуск, не авто-конец).
  Future<void> _next() => ref.read(playbackQueueProvider.notifier).next();

  Future<void> _prev() => ref.read(playbackQueueProvider.notifier).previous();

  Future<void> _toggleLike(TrackDto track) async {
    final social = ref.read(socialControllerProvider);
    final next = !(_likedOverride ?? (track.userFavorite ?? false));
    setState(() => _likedOverride = next);
    try {
      if (next) {
        await social.likeTrack(track.urn);
      } else {
        await social.unlikeTrack(track.urn);
      }
    } catch (_) {
      if (mounted) setState(() => _likedOverride = !next);
    }
  }

  Future<void> _toggleDislike(TrackDto track) async {
    final social = ref.read(socialControllerProvider);
    final next = !_disliked;
    setState(() => _disliked = next);
    final scTrackId = track.urn.split(':').last;
    try {
      if (next) {
        await social.dislikeTrack(scTrackId);
      } else {
        await social.undislikeTrack(scTrackId);
      }
    } catch (_) {
      if (mounted) setState(() => _disliked = !next);
    }
  }
}

/// Бейдж качества из стораджа: явно высокое → HQ, иначе SQ; неизвестно → нет бейджа.
NowBarQuality? _quality(TrackDto track) {
  final q = track.storageQuality?.toLowerCase();
  if (q == null) return null;
  if (q.contains('hq') || q.contains('high')) return NowBarQuality.hq;
  return NowBarQuality.sq;
}

/// Источник: отдаём из нашего стораджа → CDN-пилюля, иначе скрыт.
NowBarSource? _source(TrackDto track) {
  final s = track.storageState?.toLowerCase();
  if (s == 'stored' || s == 'storage' || s == 'ready') return NowBarSource.storage;
  return null;
}
