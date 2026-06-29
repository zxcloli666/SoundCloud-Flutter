/// Рантайм SoundCloud: фичемодули, DI и встраиваемый виджет поверх моста в ядро.
library sc_engine;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/config.dart';
import 'src/providers.dart';
import 'src/ui/root_shell.dart';

export 'src/config.dart';
export 'src/tray/mini_player_app.dart' show runMiniPlayer;
export 'src/tray/mini_player_ipc.dart' show miniPlayerSocketPath;
export 'package:sc_visual/sc_visual.dart' show scDarkTheme, ScPalette, PerfMode;

/// Встраиваемый виджет SoundCloud. Хост передаёт [ScEngineConfig] (свои данные)
/// и монтирует это поддерево внутри своего `MaterialApp` — без пересборки фронта.
class SoundCloudApp extends StatelessWidget {
  final ScEngineConfig config;

  const SoundCloudApp({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [scConfigProvider.overrideWithValue(config)],
      child: const ScRootShell(),
    );
  }
}
