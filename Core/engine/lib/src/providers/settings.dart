import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import 'core.dart';

/// Закреплённый плейлист «Быстрого доступа» (легаси `pinnedPlaylists`-store):
/// сохраняем минимум для строки сайдбара. Только то, что юзер закрепил сам.
class PinnedPlaylist {
  final String urn;
  final String title;
  final String? artworkUrl;

  const PinnedPlaylist(
      {required this.urn, required this.title, this.artworkUrl});

  Map<String, dynamic> toJson() =>
      {'urn': urn, 'title': title, 'artworkUrl': artworkUrl};

  factory PinnedPlaylist.fromJson(Map<String, dynamic> j) => PinnedPlaylist(
        urn: j['urn'] as String? ?? '',
        title: j['title'] as String? ?? '',
        artworkUrl: j['artworkUrl'] as String?,
      );
}

/// Пользовательские настройки приложения (один снимок).
///
/// [perfMode] глобально масштабирует тяжесть эффектов (читается шеллом и
/// прокидывается в [ScPerf]). [accent] — кастомный акцент (ARGB); `null` —
/// дефолт темы. [startupTab] — индекс раздела при запуске.
/// [audioCacheLimitMB] — потолок оффлайн-кэша (датчик «Хранилища»).
class ScSettings {
  final PerfMode perfMode;
  final int? accent;
  final bool highQualityStreaming;
  final bool lyricsVisualizer;
  final int startupTab;
  final String language;
  final int audioCacheLimitMB;

  /// Имя выбранного аудиовыхода; `null` — системный по умолчанию.
  final String? audioDevice;

  /// Эквалайзер (легаси `settings`-store): включён ли, 10 значений усиления и
  /// id активного пресета (`custom` после ручной правки полосы).
  final bool eqEnabled;
  final List<double> eqGains;
  final String eqPreset;

  /// Фильтры волны деки «Течение» (легаси `soundwave*`-store): «Свежак»
  /// (скрыть слушанное), скрыть лайки, выбранные языки. Персистятся.
  final bool soundwaveHideListened;
  final bool soundwaveHideLiked;
  final List<String> soundwaveLanguages;

  /// Закреплённые плейлисты «Быстрого доступа» (только закреплённые юзером).
  final List<PinnedPlaylist> pinnedPlaylists;

  /// Недавние поисковые запросы (легаси `searchHistory`), свежие — первыми.
  final List<String> searchHistory;

  /// Свёрнут ли сайдбар (легаси `sidebarCollapsed`). Персистится; шапка прячет
  /// wordmark в такт.
  final bool sidebarCollapsed;

  /// Пробив DPI (TLS-фрагментация как fallback при блокировке). Применяется на
  /// старте ядра — смена требует перезапуска.
  final bool dpiBypass;

  /// Фоновая обоина (легаси `background*`-store). [backgroundImage] — абсолютный
  /// путь файла в хранилище обоев (пусто — нет фона); прозрачность/затемнение/
  /// блюр — доли, как в Tauri-настройках «Внешний вид». [wallhavenApiKey]
  /// разблокирует NSFW Wallhaven.
  final String backgroundImage;
  final double backgroundOpacity;
  final double backgroundDim;
  final double backgroundBlur;
  final String wallhavenApiKey;

  const ScSettings({
    this.perfMode = PerfMode.beauty,
    this.accent,
    this.highQualityStreaming = false,
    this.lyricsVisualizer = false,
    this.startupTab = 0,
    this.language = 'ru',
    this.audioCacheLimitMB = 1024,
    this.audioDevice,
    this.eqEnabled = false,
    this.eqGains = eqFlatGains,
    this.eqPreset = 'flat',
    this.soundwaveHideListened = false,
    this.soundwaveHideLiked = false,
    this.soundwaveLanguages = const [],
    this.pinnedPlaylists = const [],
    this.searchHistory = const [],
    this.sidebarCollapsed = false,
    this.dpiBypass = false,
    this.backgroundImage = '',
    this.backgroundOpacity = 0.15,
    this.backgroundDim = 0,
    this.backgroundBlur = 0,
    this.wallhavenApiKey = '',
  });

  ScSettings copyWith({
    PerfMode? perfMode,
    int? accent,
    bool clearAccent = false,
    bool? highQualityStreaming,
    bool? lyricsVisualizer,
    int? startupTab,
    String? language,
    int? audioCacheLimitMB,
    String? audioDevice,
    bool clearAudioDevice = false,
    bool? eqEnabled,
    List<double>? eqGains,
    String? eqPreset,
    bool? soundwaveHideListened,
    bool? soundwaveHideLiked,
    List<String>? soundwaveLanguages,
    List<PinnedPlaylist>? pinnedPlaylists,
    List<String>? searchHistory,
    bool? sidebarCollapsed,
    bool? dpiBypass,
    String? backgroundImage,
    double? backgroundOpacity,
    double? backgroundDim,
    double? backgroundBlur,
    String? wallhavenApiKey,
  }) {
    return ScSettings(
      perfMode: perfMode ?? this.perfMode,
      accent: clearAccent ? null : (accent ?? this.accent),
      highQualityStreaming: highQualityStreaming ?? this.highQualityStreaming,
      lyricsVisualizer: lyricsVisualizer ?? this.lyricsVisualizer,
      startupTab: startupTab ?? this.startupTab,
      language: language ?? this.language,
      audioCacheLimitMB: audioCacheLimitMB ?? this.audioCacheLimitMB,
      audioDevice: clearAudioDevice ? null : (audioDevice ?? this.audioDevice),
      eqEnabled: eqEnabled ?? this.eqEnabled,
      eqGains: eqGains ?? this.eqGains,
      eqPreset: eqPreset ?? this.eqPreset,
      soundwaveHideListened:
          soundwaveHideListened ?? this.soundwaveHideListened,
      soundwaveHideLiked: soundwaveHideLiked ?? this.soundwaveHideLiked,
      soundwaveLanguages: soundwaveLanguages ?? this.soundwaveLanguages,
      pinnedPlaylists: pinnedPlaylists ?? this.pinnedPlaylists,
      searchHistory: searchHistory ?? this.searchHistory,
      sidebarCollapsed: sidebarCollapsed ?? this.sidebarCollapsed,
      dpiBypass: dpiBypass ?? this.dpiBypass,
      backgroundImage: backgroundImage ?? this.backgroundImage,
      backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
      backgroundDim: backgroundDim ?? this.backgroundDim,
      backgroundBlur: backgroundBlur ?? this.backgroundBlur,
      wallhavenApiKey: wallhavenApiKey ?? this.wallhavenApiKey,
    );
  }

  Map<String, dynamic> toJson() => {
        'perfMode': perfMode.name,
        'accent': accent,
        'highQualityStreaming': highQualityStreaming,
        'lyricsVisualizer': lyricsVisualizer,
        'startupTab': startupTab,
        'language': language,
        'audioCacheLimitMB': audioCacheLimitMB,
        'audioDevice': audioDevice,
        'eqEnabled': eqEnabled,
        'eqGains': eqGains,
        'eqPreset': eqPreset,
        'soundwaveHideListened': soundwaveHideListened,
        'soundwaveHideLiked': soundwaveHideLiked,
        'soundwaveLanguages': soundwaveLanguages,
        'pinnedPlaylists': [for (final p in pinnedPlaylists) p.toJson()],
        'searchHistory': searchHistory,
        'sidebarCollapsed': sidebarCollapsed,
        'dpiBypass': dpiBypass,
        'backgroundImage': backgroundImage,
        'backgroundOpacity': backgroundOpacity,
        'backgroundDim': backgroundDim,
        'backgroundBlur': backgroundBlur,
        'wallhavenApiKey': wallhavenApiKey,
      };

  factory ScSettings.fromJson(Map<String, dynamic> json) => ScSettings(
        perfMode: PerfMode.values.firstWhere(
          (m) => m.name == json['perfMode'],
          orElse: () => PerfMode.beauty,
        ),
        accent: json['accent'] as int?,
        highQualityStreaming: json['highQualityStreaming'] as bool? ?? false,
        lyricsVisualizer: json['lyricsVisualizer'] as bool? ?? false,
        startupTab: json['startupTab'] as int? ?? 0,
        language: json['language'] as String? ?? 'ru',
        audioCacheLimitMB: json['audioCacheLimitMB'] as int? ?? 1024,
        audioDevice: json['audioDevice'] as String?,
        eqEnabled: json['eqEnabled'] as bool? ?? false,
        eqGains: _gainsFromJson(json['eqGains']),
        eqPreset: json['eqPreset'] as String? ?? 'flat',
        soundwaveHideListened: json['soundwaveHideListened'] as bool? ?? false,
        soundwaveHideLiked: json['soundwaveHideLiked'] as bool? ?? false,
        soundwaveLanguages: (json['soundwaveLanguages'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        pinnedPlaylists: (json['pinnedPlaylists'] as List?)
                ?.whereType<Map>()
                .map((e) =>
                    PinnedPlaylist.fromJson(Map<String, dynamic>.from(e)))
                .toList() ??
            const [],
        searchHistory: (json['searchHistory'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        sidebarCollapsed: json['sidebarCollapsed'] as bool? ?? false,
        dpiBypass: json['dpiBypass'] as bool? ?? false,
        backgroundImage: json['backgroundImage'] as String? ?? '',
        backgroundOpacity:
            (json['backgroundOpacity'] as num?)?.toDouble() ?? 0.15,
        backgroundDim: (json['backgroundDim'] as num?)?.toDouble() ?? 0,
        backgroundBlur: (json['backgroundBlur'] as num?)?.toDouble() ?? 0,
        wallhavenApiKey: json['wallhavenApiKey'] as String? ?? '',
      );

  static List<double> _gainsFromJson(Object? raw) {
    if (raw is! List || raw.length != eqBandCount) return eqFlatGains;
    return [for (final v in raw) (v as num).toDouble()];
  }
}

/// Источник истины для настроек. Пока in-memory (персист — с settings-портом
/// ядра); сеттеры точечно обновляют один снимок.
final settingsProvider = NotifierProvider<SettingsNotifier, ScSettings>(
  SettingsNotifier.new,
);

class SettingsNotifier extends Notifier<ScSettings> {
  @override
  ScSettings build() => _load();

  /// Файл настроек в data-dir встраивания (`null`, если каталог не задан).
  File? _file() {
    final dir = ref.read(scConfigProvider).dataDir;
    if (dir.isEmpty) return null;
    return File('$dir/settings.json');
  }

  ScSettings _load() {
    final file = _file();
    if (file == null || !file.existsSync()) return const ScSettings();
    try {
      return ScSettings.fromJson(
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
      );
    } catch (_) {
      return const ScSettings();
    }
  }

  /// Обновить снимок и сохранить на диск (записи редкие — без дебаунса).
  void _commit(ScSettings next) {
    state = next;
    final file = _file();
    if (file == null) return;
    try {
      file.writeAsStringSync(jsonEncode(next.toJson()));
    } catch (_) {}
  }

  void setPerfMode(PerfMode mode) => _commit(state.copyWith(perfMode: mode));

  /// `null` — сброс на акцент темы.
  void setAccent(int? accent) => _commit(
        accent == null
            ? state.copyWith(clearAccent: true)
            : state.copyWith(accent: accent),
      );

  void setHighQualityStreaming(bool value) =>
      _commit(state.copyWith(highQualityStreaming: value));

  void setLyricsVisualizer(bool value) =>
      _commit(state.copyWith(lyricsVisualizer: value));

  void setStartupTab(int index) => _commit(state.copyWith(startupTab: index));

  void setLanguage(String code) => _commit(state.copyWith(language: code));

  void setAudioCacheLimitMB(int mb) =>
      _commit(state.copyWith(audioCacheLimitMB: mb));

  /// `null` — системный аудиовыход по умолчанию.
  void setAudioDevice(String? name) => _commit(
        name == null
            ? state.copyWith(clearAudioDevice: true)
            : state.copyWith(audioDevice: name),
      );

  void setEqEnabled(bool value) => _commit(state.copyWith(eqEnabled: value));

  void setSoundwaveHideListened(bool v) =>
      _commit(state.copyWith(soundwaveHideListened: v));

  void setSoundwaveHideLiked(bool v) =>
      _commit(state.copyWith(soundwaveHideLiked: v));

  void setSoundwaveLanguages(List<String> v) =>
      _commit(state.copyWith(soundwaveLanguages: v));

  void toggleSoundwaveLanguage(String code) {
    final langs = [...state.soundwaveLanguages];
    langs.contains(code) ? langs.remove(code) : langs.add(code);
    _commit(state.copyWith(soundwaveLanguages: langs));
  }

  bool isPlaylistPinned(String urn) =>
      state.pinnedPlaylists.any((p) => p.urn == urn);

  void pinPlaylist(PinnedPlaylist p) {
    if (isPlaylistPinned(p.urn)) return;
    _commit(state.copyWith(pinnedPlaylists: [...state.pinnedPlaylists, p]));
  }

  void unpinPlaylist(String urn) => _commit(state.copyWith(
      pinnedPlaylists:
          state.pinnedPlaylists.where((p) => p.urn != urn).toList()));

  void togglePinnedPlaylist(PinnedPlaylist p) =>
      isPlaylistPinned(p.urn) ? unpinPlaylist(p.urn) : pinPlaylist(p);

  /// Записать запрос в историю (свежий — первым, дедуп, кап 20).
  void addSearchQuery(String q) {
    final t = q.trim();
    if (t.isEmpty) return;
    final next = [t, ...state.searchHistory.where((e) => e != t)];
    if (next.length > 20) next.removeRange(20, next.length);
    _commit(state.copyWith(searchHistory: next));
  }

  void removeSearchQuery(String q) => _commit(state.copyWith(
      searchHistory: state.searchHistory.where((e) => e != q).toList()));

  void clearSearchHistory() => _commit(state.copyWith(searchHistory: const []));

  void toggleSidebar() =>
      _commit(state.copyWith(sidebarCollapsed: !state.sidebarCollapsed));

  /// Применяется на старте ядра — после смены нужен перезапуск.
  void setDpiBypass(bool v) => _commit(state.copyWith(dpiBypass: v));

  /// Путь выбранной обоины (пусто — снять фон).
  void setBackgroundImage(String path) =>
      _commit(state.copyWith(backgroundImage: path));

  void setBackgroundOpacity(double v) =>
      _commit(state.copyWith(backgroundOpacity: v));

  void setBackgroundDim(double v) => _commit(state.copyWith(backgroundDim: v));

  void setBackgroundBlur(double v) => _commit(state.copyWith(backgroundBlur: v));

  void setWallhavenApiKey(String key) =>
      _commit(state.copyWith(wallhavenApiKey: key));

  /// Полностью заменить усиления (применение пресета/сброс).
  void setEqGains(List<double> gains) =>
      _commit(state.copyWith(eqGains: List.of(gains)));

  void setEqPreset(String id) => _commit(state.copyWith(eqPreset: id));

  /// Правка одной полосы — переводит пресет в `custom` (легаси-поведение).
  void setEqBand(int index, double gain) {
    if (index < 0 || index >= state.eqGains.length) return;
    final next = List.of(state.eqGains)..[index] = gain;
    _commit(state.copyWith(eqGains: next, eqPreset: 'custom'));
  }
}
