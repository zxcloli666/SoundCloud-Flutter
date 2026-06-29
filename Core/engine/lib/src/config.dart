import 'package:flutter/widgets.dart';

/// Конфигурация встраивания: хост-приложение задаёт пути (а позже — тему и
/// реализации портов). Через неё «приложение в приложении» получает свои данные.
class ScEngineConfig {
  /// Каталог данных (сессия и пр.).
  final String dataDir;

  /// Каталог кэша треков.
  final String cacheDir;

  /// Путь к нативной библиотеке моста (dev/тест). В проде — `null`: либа
  /// бандлится и грузится по умолчанию (cargokit).
  final String? rustLibPath;

  /// Платформенные медиа-хуки (Dart-порт). Десктоп подключает к своему FFI
  /// (MPRIS/SMTC), мобайл — к audio_service. `null` — без системных контролов.
  final ScMediaHandlers? media;

  /// Обратный канал управления: трей/MPRIS/SMTC шлют сюда play-pause/next/prev,
  /// движок исполняет их на своих провайдерах. `null` — внешнего управления нет.
  final ScRemoteControls? remote;

  /// Высота кастомного титлбара хоста (десктоп). Оболочка резервирует её сверху
  /// под контент, но атмосферу рисует на всё окно — фон виден сквозь титлбар.
  final double topInset;

  /// Кнопки управления окном (свернуть/развернуть/закрыть/фуллскрин) — десктоп
  /// отдаёт свой виджет (на `window_manager`). `null` — шапка без них (мобайл).
  final Widget? windowControls;

  /// Начать перетаскивание окна за шапку (десктоп → `windowManager.startDragging`).
  final VoidCallback? onWindowDragStart;

  /// Дабл-клик по шапке — развернуть/свернуть окно (десктоп).
  final VoidCallback? onWindowDoubleTap;

  /// Показать/сфокусировать главное окно (десктоп → `windowManager.show+focus`).
  /// Зовётся, когда мини-плеер трея просит «развернуть приложение». `null` —
  /// нет управления окном (мобайл).
  final VoidCallback? onShowWindow;

  /// Управление relay call-агентом (статус ноды + тумблер). Реализацию даёт
  /// оболочка (десктоп → desktop-bridge FFI). `null` — call недоступен (мобайл).
  final ScCallControls? call;

  const ScEngineConfig({
    required this.dataDir,
    required this.cacheDir,
    this.rustLibPath,
    this.media,
    this.remote,
    this.topInset = 0,
    this.windowControls,
    this.onWindowDragStart,
    this.onWindowDoubleTap,
    this.onShowWindow,
    this.call,
  });
}

/// Порт к relay call-агенту (оболочка → desktop-bridge FFI). UI настроек читает
/// статус/флаг и переключает ноду; до реализации хоста — `null` в конфиге.
class ScCallControls {
  /// Включён ли агент (флаг автозапуска).
  final bool Function() isEnabled;

  /// Код статуса: 0 выкл · 1 подключение · 2 регистрация · 3 активен · 4 ошибка.
  final int Function() status;

  /// Включить/выключить ноду (перезапуск/останов).
  final void Function(bool enabled) setEnabled;

  const ScCallControls({
    required this.isEnabled,
    required this.status,
    required this.setEnabled,
  });
}

/// Внешнее управление воспроизведением (хост → движок). Хост держит экземпляр и
/// зовёт [playPause]/[next]/[previous]/[stop]; движок на маунте регистрирует
/// реальные обработчики через [bind]. До [bind] вызовы — no-op (трей появился
/// раньше готового движка).
class ScRemoteControls {
  Future<void> Function()? _play;
  Future<void> Function()? _pause;
  Future<void> Function()? _playPause;
  Future<void> Function()? _next;
  Future<void> Function()? _previous;
  Future<void> Function()? _stop;

  /// Движок регистрирует обработчики (идемпотентно — перепривязка ок). [play]/
  /// [pause] — явные (MPRIS Play/Pause); [playPause] — тоггл (медиа-клавиша/трей).
  void bind({
    required Future<void> Function() play,
    required Future<void> Function() pause,
    required Future<void> Function() playPause,
    required Future<void> Function() next,
    required Future<void> Function() previous,
    required Future<void> Function() stop,
  }) {
    _play = play;
    _pause = pause;
    _playPause = playPause;
    _next = next;
    _previous = previous;
    _stop = stop;
  }

  Future<void> play() async => _play == null ? null : _play!();
  Future<void> pause() async => _pause == null ? null : _pause!();
  Future<void> playPause() async => _playPause == null ? null : _playPause!();
  Future<void> next() async => _next == null ? null : _next!();
  Future<void> previous() async => _previous == null ? null : _previous!();
  Future<void> stop() async => _stop == null ? null : _stop!();
}

/// Трек для системных контролов (MPRIS/Discord/трей): то, что им нужно показать.
class ScMediaTrack {
  final String title;
  final String artist;

  /// URL обложки (для MPRIS art / Discord large image).
  final String? artworkUrl;

  /// Публичная ссылка трека (кнопка в Discord-presence).
  final String? trackUrl;

  /// Длительность, сек (MPRIS length / Discord end-timestamp).
  final double durationSecs;

  const ScMediaTrack({
    required this.title,
    required this.artist,
    this.artworkUrl,
    this.trackUrl,
    this.durationSecs = 0,
  });
}

/// Платформенные обработчики состояния плеера. Движок зовёт их при смене трека,
/// play/pause и тике позиции; реализацию даёт хост (десктоп/мобайл).
class ScMediaHandlers {
  final void Function(ScMediaTrack track)? onNowPlaying;
  final void Function(bool playing)? onPlaying;

  /// Тик позиции (сек), дросселированный до ~1 Гц — для скраббера MPRIS и
  /// таймстемпов Discord.
  final void Function(double positionSecs)? onProgress;
  final void Function()? onClear;

  const ScMediaHandlers({
    this.onNowPlaying,
    this.onPlaying,
    this.onProgress,
    this.onClear,
  });
}
