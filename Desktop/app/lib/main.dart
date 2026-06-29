import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sc_engine/sc_engine.dart';
import 'package:window_manager/window_manager.dart';

import 'call_ffi.dart';
import 'discord_ffi.dart';
import 'media_ffi.dart';
import 'titlebar.dart';
import 'tray_ffi.dart';

/// Десктоп-оболочка: тонкий хост поверх движка. Дизайн пока дефолтный — слизываем
/// с легаси отдельной фазой; здесь — рабочий вертикальный срез.
///
/// Нативные либы (без cargokit) грузим напрямую из target; пути переопределяются
/// `SC_RUST_LIB` / `SC_MEDIA_LIB`. В проде уйдут в бандл.
///
/// `--miniplayer <sock> <cacheDir>` — отдельный процесс окна-мини-плеера трея:
/// тонкое окно, рисует [runMiniPlayer], состояние тянет по сокету у главного.
Future<void> main(List<String> args) async {
  if (args.isNotEmpty && args.first == '--miniplayer') {
    await _runMiniPlayerWindow(args);
    return;
  }

  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  const windowOptions = WindowOptions(
    size: Size(1200, 800),
    minimumSize: Size(900, 600),
    center: true,
    backgroundColor: Color(0xFF08080A),
    titleBarStyle: TitleBarStyle.hidden,
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  final dataDir = await getApplicationSupportDirectory();
  final cacheDir = await getApplicationCacheDirectory();
  // `null` → FRB грузит бандл `libsc_bridge.so` по rpath ($ORIGIN/lib, cargokit
  // в CMake). Для запуска из исходников без бандла — переопределить `SC_RUST_LIB`.
  final rustLib = Platform.environment['SC_RUST_LIB'];

  // Окно мини-плеера — отдельный процесс нашего же бинаря; тоггл из меню трея.
  final mini = _MiniLauncher(
    exe: Platform.resolvedExecutable,
    socketPath: miniPlayerSocketPath(dataDir.path),
    cacheDir: cacheDir.path,
  );

  // Обратный канал управления (трей/MPRIS → движок).
  final remote = ScRemoteControls();

  // Системный трей — нативный SNI через desktop-bridge (ksni, без GTK). Левый
  // клик иконки / пункт «Мини-плеер» → окно-поповер; транспорт → движок.
  DesktopTray.open(_desktopLib).start(
    iconPath: _trayIconPath(),
    onShow: _showMainWindow,
    onMini: mini.toggle,
    onPlayPause: remote.playPause,
    onPrev: remote.previous,
    onNext: remote.next,
    onQuit: () => exit(0),
  );

  // Relay call-агент: автостарт по флагу (нода relay-сети, бэкенд ходит через неё);
  // тот же экземпляр кормит карточку настроек (статус/тумблер). `null` — FFI не
  // поднялся (карточка скрыта).
  final call = _openCall(dataDir.path);

  runApp(
    MaterialApp(
      title: 'SoundCloud',
      debugShowCheckedModeBanner: false,
      theme: scDarkTheme(),
      // Шапка (лого/нав/поиск) живёт в движке (`ScHeaderBar`) — ей нужен роутер;
      // десктоп отдаёт лишь кнопки окна + перетаскивание через конфиг.
      home: SoundCloudApp(
        config: ScEngineConfig(
          dataDir: dataDir.path,
          cacheDir: cacheDir.path,
          rustLibPath: rustLib,
          media: _desktopMedia(remote),
          remote: remote,
          windowControls: const WindowControls(),
          onWindowDragStart: () => windowManager.startDragging(),
          onWindowDoubleTap: () => toggleMaximize(),
          onShowWindow: _showMainWindow,
          call: call == null
              ? null
              : ScCallControls(
                  isEnabled: call.isEnabled,
                  status: call.status,
                  setEnabled: call.setEnabled,
                ),
        ),
      ),
    ),
  );
}

/// Показать и сфокусировать главное окно (из трея / мини-плеера).
void _showMainWindow() {
  windowManager.show();
  windowManager.focus();
}

/// Путь к иконке трея в бандле (рядом с исполняемым: `data/flutter_assets/...`).
String _trayIconPath() {
  final dir = File(Platform.resolvedExecutable).parent.path;
  return '$dir/data/flutter_assets/assets/tray_icon.png';
}

/// Окно мини-плеера: тонкое frameless/прозрачное/always-on-top. На Wayland клиент
/// не задаёт абсолютную позицию (центрируем; точное место — windowrule по title).
Future<void> _runMiniPlayerWindow(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  final socketPath = args.length > 1 ? args[1] : '';
  final cacheDir = args.length > 2 ? args[2] : null;
  const opts = WindowOptions(
    size: Size(384, 248),
    center: true,
    backgroundColor: Color(0x00000000),
    skipTaskbar: true,
    alwaysOnTop: true,
    titleBarStyle: TitleBarStyle.hidden,
    title: 'SoundCloud Mini',
  );
  await windowManager.waitUntilReadyToShow(opts, () async {
    await windowManager.setAsFrameless();
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setSkipTaskbar(true);
    await windowManager.setTitle('SoundCloud Mini');
    await windowManager.show();
    await windowManager.focus();
  });
  // Wayland: клиент не управляет float/size/позицией окна — это решает
  // композитор. Окно ловится по заголовку «SoundCloud Mini». Standard-Hyprland
  // (hyprland.conf):
  //   windowrulev2 = float,  title:^(SoundCloud Mini)$
  //   windowrulev2 = size 384 248, title:^(SoundCloud Mini)$
  //   windowrulev2 = center, title:^(SoundCloud Mini)$
  //   windowrulev2 = pin,   title:^(SoundCloud Mini)$
  runMiniPlayer(socketPath, cacheDir: cacheDir);
}

/// Спавнер окна-мини-плеера: запускает/закрывает отдельный процесс бинаря с
/// `--miniplayer`. Тоггл из меню трея; самозакрытие окна (✕) чистит ссылку.
class _MiniLauncher {
  final String exe;
  final String socketPath;
  final String cacheDir;
  Process? _proc;

  _MiniLauncher({
    required this.exe,
    required this.socketPath,
    required this.cacheDir,
  });

  Future<void> toggle() async {
    final running = _proc;
    if (running != null) {
      running.kill();
      _proc = null;
      return;
    }
    try {
      final proc = await Process.start(
        exe,
        ['--miniplayer', socketPath, cacheDir],
      );
      _proc = proc;
      unawaited(proc.exitCode.then((_) => _proc = null));
    } catch (_) {}
  }
}

/// Медиа-хуки движка: системные контролы (MPRIS) + Discord Rich Presence. Трей
/// статичный (как в Tauri) — надписи трека не обновляет.
ScMediaHandlers _desktopMedia(ScRemoteControls remote) {
  final media = _openMpris(remote);
  final discord = _openDiscord();
  return ScMediaHandlers(
    onNowPlaying: (t) {
      final durMs = (t.durationSecs * 1000).round();
      media?.nowPlaying(t.title, t.artist, t.artworkUrl ?? '', durMs);
      discord?.nowPlaying(t.title, t.artist, t.artworkUrl ?? '', t.trackUrl ?? '',
          t.durationSecs.round());
    },
    onPlaying: (playing) {
      media?.setPlaying(playing);
      discord?.setPlaying(playing);
    },
    onProgress: (pos) {
      media?.setPosition((pos * 1000).round());
      discord?.setPosition(pos.round());
    },
    onClear: () {
      media?.clear();
      discord?.clear();
    },
  );
}

/// Единый десктоп-FFI: грузим бандл `libdesktop_bridge.so` по имени (rpath
/// $ORIGIN/lib, cargokit в CMake). Для запуска из исходников — `SC_MEDIA_LIB`.
String get _desktopLib =>
    Platform.environment['SC_MEDIA_LIB'] ?? 'libdesktop_bridge.so';

/// Открыть медиа-контролы из десктоп-FFI + подключить медиа-клавиши ОС к движку
/// (inbound). Недоступны — `null`.
DesktopMedia? _openMpris(ScRemoteControls remote) {
  try {
    final media = DesktopMedia.open(_desktopLib);
    if (!media.init()) return null;
    media.bindRemote(remote);
    return media;
  } catch (_) {
    return null;
  }
}

/// Открыть relay call-агент + автостарт по флагу. Best-effort — `null`, если FFI
/// не поднялся (карточка настроек тогда скрыта).
DesktopCall? _openCall(String dataDir) {
  try {
    final c = DesktopCall.open(_desktopLib);
    c.start(dataDir);
    return c;
  } catch (_) {
    return null;
  }
}

/// Открыть Discord Rich Presence из десктоп-FFI. Discord не запущен — `null`.
DesktopDiscord? _openDiscord() {
  try {
    final discord = DesktopDiscord.open(_desktopLib);
    return discord.init() ? discord : null;
  } catch (_) {
    return null;
  }
}
