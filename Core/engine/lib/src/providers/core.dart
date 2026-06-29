import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:sc_visual/sc_visual.dart';

import '../config.dart';
import '../rust/api.dart';
import '../rust/frb_generated.dart';
import 'settings.dart';

/// Прокси картинок: внешние CDN идут через наш RKN-safe домен (см. [ScImageProxy]).
const _imageProxyBase = 'https://images.scdinternal.site';

/// Конфиг встраивания. Переопределяется в [ProviderScope] хостом.
final scConfigProvider = Provider<ScEngineConfig>(
  (ref) => throw UnimplementedError('scConfigProvider must be overridden'),
);

/// Однократный запуск ядра: загрузка нативной библиотеки + инициализация рантайма
/// + прокидывание сохранённых аудио-настроек (флаги ядра глобальны, их нужно
/// восстановить из снимка настроек до первого воспроизведения).
final bootstrapProvider = FutureProvider<void>((ref) async {
  final config = ref.watch(scConfigProvider);
  final libPath = config.rustLibPath;
  await RustLib.init(
    externalLibrary: libPath == null ? null : ExternalLibrary.open(libPath),
  );
  await initRuntime(
    dataDir: config.dataDir,
    cacheDir: config.cacheDir,
    dpiBypass: ref.read(settingsProvider).dpiBypass,
  );

  // Внешние картинки (sndcdn и пр.) — через наш RKN-safe прокси-домен + диск-кэш.
  ScImageProxy.configure(base: _imageProxyBase, cacheDir: config.cacheDir);

  final settings = ref.read(settingsProvider);
  await setEq(enabled: settings.eqEnabled, gains: settings.eqGains);
  // Выбранный аудиовыход (если не системный по умолчанию).
  if (settings.audioDevice != null) {
    await setAudioOutput(name: settings.audioDevice);
  }
});

/// Текущий токен сессии (владелец — Rust). Запись прокидывает токен в ядро;
/// `null` — анонимный режим. Зависимые чтения (me/library/wave) инвалидируются
/// хостом после смены сессии через [ref.invalidate].
final sessionProvider = NotifierProvider<SessionNotifier, String?>(
  SessionNotifier.new,
);

class SessionNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  /// Передать токен в ядро и запомнить локально. `null` — разлогин.
  Future<void> set(String? token) async {
    await setSession(token: token);
    state = token;
  }
}
