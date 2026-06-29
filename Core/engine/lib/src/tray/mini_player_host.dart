import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../rust/api.dart';
import '../ui/now_playing_bar/transport_state.dart';
import 'mini_player_ipc.dart';

/// Серверная сторона мини-плеера трея: держит unix-сокет, на который коннектится
/// окно `--miniplayer`. Главный процесс — единственный источник истины: на смену
/// плеер-состояния шлёт снимок, на тик — позицию; команды окна исполняет на своих
/// провайдерах (как [NowBarHost], но без своего UI). Виджет невидимый — монтируется
/// в шелл ради доступа к `ref`.
class MiniPlayerHost extends ConsumerStatefulWidget {
  const MiniPlayerHost({super.key});

  @override
  ConsumerState<MiniPlayerHost> createState() => _MiniPlayerHostState();
}

class _MiniPlayerHostState extends ConsumerState<MiniPlayerHost> {
  ServerSocket? _server;
  final List<Socket> _clients = [];
  String? _lastNp;

  // Оптимистичная реакция текущего трека (как в NowBarHost): мгновенный флип
  // глифа, мутация в фоне, на ошибке откат. Сброс при смене трека.
  bool? _likedOverride;
  bool _disliked = false;
  String? _reactedUrn;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final dir = ref.read(scConfigProvider).dataDir;
    if (dir.isEmpty) return;
    final path = miniPlayerSocketPath(dir);
    try {
      // Снять протухший сокет-файл от прошлого запуска (иначе bind: address in use).
      final stale = File(path);
      if (stale.existsSync()) stale.deleteSync();
      _server = await ServerSocket.bind(
        InternetAddress(path, type: InternetAddressType.unix),
        0,
      );
      _server!.listen(_onClient, onError: (_) {});
    } catch (_) {
      // Нет сокета — мини-плеер просто не сможет подключиться; апп работает.
    }
  }

  void _onClient(Socket sock) {
    _clients.add(sock);
    decodeFrames(sock).listen(
      (frame) => _onFrame(frame, sock),
      onDone: () => _clients.remove(sock),
      onError: (_) => _clients.remove(sock),
      cancelOnError: true,
    );
    _sendTo(sock, encodeNp(_buildSnapshot()));
  }

  void _onFrame(MiniFrame frame, Socket sock) {
    switch (frame.type) {
      case 'hello':
        _sendTo(sock, encodeNp(_buildSnapshot()));
      case 'cmd':
        if (frame.action != null) _dispatch(frame.action!, frame.value);
    }
  }

  // --- снимок + рассылка ---

  MiniPlayerSnapshot _buildSnapshot() {
    final settings = ref.read(settingsProvider);
    final track = ref.read(playerProvider);
    if (track == null) {
      return MiniPlayerSnapshot(
        accent: settings.accent,
        perfMode: settings.perfMode.name,
      );
    }
    final transport = ref.read(nowBarTransportProvider);
    final volume = ref.read(volumeProvider);
    final liked = track.urn == _reactedUrn
        ? (_likedOverride ?? (track.userFavorite ?? false))
        : (track.userFavorite ?? false);
    final disliked = track.urn == _reactedUrn && _disliked;
    return MiniPlayerSnapshot(
      hasTrack: true,
      title: track.title,
      artist: track.artistName,
      artworkUrl: track.artworkUrl,
      playing: ref.read(isPlayingProvider),
      durationSecs: track.durationMs.toInt() / 1000.0,
      shuffle: transport.shuffle,
      repeat: transport.repeat.name,
      liked: liked,
      disliked: disliked,
      volume: volume.clamp(0.0, 1.0),
      muted: transport.muted,
      accent: settings.accent,
      perfMode: settings.perfMode.name,
    );
  }

  void _pushSnapshot() {
    if (_clients.isEmpty) return;
    final msg = encodeNp(_buildSnapshot());
    if (msg == _lastNp) return;
    _lastNp = msg;
    for (final c in List.of(_clients)) {
      _sendTo(c, msg);
    }
  }

  void _pushPos(double secs) {
    if (_clients.isEmpty) return;
    final msg = encodePos(secs);
    for (final c in List.of(_clients)) {
      _sendTo(c, msg);
    }
  }

  void _sendTo(Socket sock, String msg) {
    try {
      sock.write(msg);
    } catch (_) {
      _clients.remove(sock);
    }
  }

  // --- исполнение команд (как NowBarHost) ---

  void _dispatch(String action, double? value) {
    switch (action) {
      case MiniCmd.playPause:
        ref.read(playerProvider.notifier).togglePause();
      case MiniCmd.next:
        ref.read(playbackQueueProvider.notifier).next();
      case MiniCmd.prev:
        ref.read(playbackQueueProvider.notifier).previous();
      case MiniCmd.seek:
        if (value != null) seek(positionSecs: value);
      case MiniCmd.volume:
        _setVolume(value ?? 0);
      case MiniCmd.shuffle:
        ref.read(nowBarTransportProvider.notifier).toggleShuffle();
        _pushSnapshot();
      case MiniCmd.repeat:
        ref.read(nowBarTransportProvider.notifier).cycleRepeat();
        _pushSnapshot();
      case MiniCmd.like:
        _toggleLike();
      case MiniCmd.dislike:
        _toggleDislike();
      case MiniCmd.show:
        ref.read(scConfigProvider).onShowWindow?.call();
    }
  }

  void _setVolume(double v) {
    final transport = ref.read(nowBarTransportProvider);
    final transportN = ref.read(nowBarTransportProvider.notifier);
    if (transport.muted) transportN.toggleMute(ref.read(volumeProvider));
    ref.read(volumeProvider.notifier).set(v);
  }

  Future<void> _toggleLike() async {
    final track = ref.read(playerProvider);
    if (track == null) return;
    final social = ref.read(socialControllerProvider);
    final current = track.urn == _reactedUrn
        ? (_likedOverride ?? (track.userFavorite ?? false))
        : (track.userFavorite ?? false);
    final next = !current;
    _reactedUrn = track.urn;
    _likedOverride = next;
    _pushSnapshot();
    try {
      next ? await social.likeTrack(track.urn) : await social.unlikeTrack(track.urn);
    } catch (_) {
      _likedOverride = !next;
      _pushSnapshot();
    }
  }

  Future<void> _toggleDislike() async {
    final track = ref.read(playerProvider);
    if (track == null) return;
    final social = ref.read(socialControllerProvider);
    final next = !(track.urn == _reactedUrn && _disliked);
    _reactedUrn = track.urn;
    _disliked = next;
    _pushSnapshot();
    final scId = track.urn.split(':').last;
    try {
      next ? await social.dislikeTrack(scId) : await social.undislikeTrack(scId);
    } catch (_) {
      _disliked = !next;
      _pushSnapshot();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Любая смена now-playing-состояния → пуш снимка; тик → пуш позиции. Реакции
    // привязаны к треку — сбрасываем оверрайды при смене.
    ref.listen(playerProvider, (prev, next) {
      if (prev?.urn != next?.urn) {
        _likedOverride = null;
        _disliked = false;
        _reactedUrn = next?.urn;
      }
      _pushSnapshot();
    });
    ref.listen(isPlayingProvider, (_, __) => _pushSnapshot());
    ref.listen(nowBarTransportProvider, (_, __) => _pushSnapshot());
    ref.listen(volumeProvider, (_, __) => _pushSnapshot());
    ref.listen(settingsProvider, (_, __) => _pushSnapshot());
    ref.listen(positionStreamProvider, (_, next) {
      final v = next.value;
      if (v != null) _pushPos(v);
    });
    return const SizedBox.shrink();
  }

  @override
  void dispose() {
    for (final c in _clients) {
      c.destroy();
    }
    _clients.clear();
    _server?.close();
    super.dispose();
  }
}
