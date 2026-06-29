import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sc_visual/sc_visual.dart';

import 'mini_player_ipc.dart';

/// Точка входа окна-поповера (процесс `--miniplayer`). Подключается к unix-сокету
/// главного процесса, рисует [ScMiniPlayer] из приходящих снимков и шлёт команды.
/// Своего плеер-состояния / Rust-рантайма НЕ поднимает — тонкий вид.
void runMiniPlayer(String socketPath, {String? cacheDir}) {
  WidgetsFlutterBinding.ensureInitialized();
  // Картинки — через тот же прокси+диск-кэш, что и главный апп.
  ScImageProxy.configure(base: 'https://images.scdinternal.site', cacheDir: cacheDir);
  runApp(MiniPlayerApp(socketPath: socketPath));
}

class MiniPlayerApp extends StatefulWidget {
  final String socketPath;
  const MiniPlayerApp({super.key, required this.socketPath});

  @override
  State<MiniPlayerApp> createState() => _MiniPlayerAppState();
}

class _MiniPlayerAppState extends State<MiniPlayerApp> {
  Socket? _sock;
  MiniPlayerSnapshot _np = const MiniPlayerSnapshot();
  final ValueNotifier<double> _position = ValueNotifier(0);
  bool _connecting = true;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    // Хост — в уже живом главном процессе; на гонку старта пробуем несколько раз.
    for (var attempt = 0; attempt < 40; attempt++) {
      try {
        final sock = await Socket.connect(
          InternetAddress(widget.socketPath, type: InternetAddressType.unix),
          0,
        );
        _sock = sock;
        if (mounted) setState(() => _connecting = false);
        decodeFrames(sock).listen(
          _onFrame,
          onDone: _onDisconnect,
          onError: (_) => _onDisconnect(),
          cancelOnError: true,
        );
        _send(encodeHello());
        return;
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
    }
    if (mounted) setState(() => _connecting = false);
  }

  void _onFrame(MiniFrame frame) {
    switch (frame.type) {
      case 'np':
        if (frame.snapshot != null) setState(() => _np = frame.snapshot!);
      case 'pos':
        if (frame.value != null) _position.value = frame.value!;
    }
  }

  void _onDisconnect() {
    _sock = null;
    // Главный процесс закрылся/упал — окну делать нечего, гасим себя.
    exit(0);
  }

  void _send(String msg) {
    try {
      _sock?.write(msg);
    } catch (_) {}
  }

  void _cmd(String action, [double? value]) => _send(encodeCmd(action, value));

  /// «Раскрыть приложение»: показать главное окно и закрыть мини-плеер.
  Future<void> _openApp() async {
    _cmd(MiniCmd.show);
    await _closeWindow();
  }

  /// Закрыть окно мини-плеера (отдельный процесс — выходим целиком). Перед выходом
  /// дожидаемся, пока команда уйдёт в сокет.
  Future<void> _closeWindow() async {
    try {
      await _sock?.flush();
    } catch (_) {}
    await Future<void>.delayed(const Duration(milliseconds: 30));
    exit(0);
  }

  @override
  Widget build(BuildContext context) {
    final accent = _np.accent;
    final palette = accent == null ? const ScPalette() : ScPalette(Color(accent));
    final perf = PerfMode.values.firstWhere(
      (m) => m.name == _np.perfMode,
      orElse: () => PerfMode.beauty,
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: scDarkTheme(palette),
      home: ScPerf(
        mode: perf,
        child: ScTheme(
          palette: palette,
          child: Material(
            type: MaterialType.transparency,
            child: _connecting ? const SizedBox.shrink() : _player(),
          ),
        ),
      ),
    );
  }

  Widget _player() {
    return ScMiniPlayer(
      data: ScMiniPlayerData(
        hasTrack: _np.hasTrack,
        title: _np.title,
        artist: _np.artist,
        artworkUrl: _np.artworkUrl,
        playing: _np.playing,
        position: _position,
        durationSecs: _np.durationSecs,
        shuffle: _np.shuffle,
        repeat: NowBarRepeat.values.firstWhere(
          (r) => r.name == _np.repeat,
          orElse: () => NowBarRepeat.off,
        ),
        liked: _np.liked,
        disliked: _np.disliked,
        volume: _np.volume,
        muted: _np.muted,
      ),
      callbacks: ScMiniPlayerCallbacks(
        onPlayPause: () => _cmd(MiniCmd.playPause),
        onPrev: () => _cmd(MiniCmd.prev),
        onNext: () => _cmd(MiniCmd.next),
        onShuffle: () => _cmd(MiniCmd.shuffle),
        onRepeat: () => _cmd(MiniCmd.repeat),
        onLike: () => _cmd(MiniCmd.like),
        onDislike: () => _cmd(MiniCmd.dislike),
        onSeek: (s) => _cmd(MiniCmd.seek, s),
        onVolume: (v) => _cmd(MiniCmd.volume, v),
        onOpenApp: _openApp,
        onClose: _closeWindow,
      ),
    );
  }

  @override
  void dispose() {
    _position.dispose();
    _sock?.destroy();
    super.dispose();
  }
}
