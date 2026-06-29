import 'dart:convert';

/// IPC мини-плеера трея: главный процесс (сервер) ↔ окно `--miniplayer` (клиент)
/// поверх unix-сокета, NDJSON (один JSON-объект на строку). Главный — единственный
/// источник истины состояния плеера; окно лишь рисует снимок и шлёт команды.
///
/// Кадры: `np` (снимок), `pos` (позиция, сек), `cmd` (команда от окна), `hello`
/// (окно при коннекте просит свежий снимок). Чистый dart — без Flutter, общий код.

/// Путь unix-сокета в data-dir приложения (общий у обоих процессов).
String miniPlayerSocketPath(String dataDir) => '$dataDir/miniplayer.sock';

/// Команды окна → главному (минимальный набор кнопок дока).
class MiniCmd {
  static const playPause = 'play_pause';
  static const next = 'next';
  static const prev = 'prev';
  static const seek = 'seek';
  static const volume = 'volume';
  static const shuffle = 'shuffle';
  static const repeat = 'repeat';
  static const like = 'like';
  static const dislike = 'dislike';
  static const show = 'show';
}

/// Снимок now-playing для мини-плеера (сериализуемый). `repeat` — `off|all|one`.
class MiniPlayerSnapshot {
  final bool hasTrack;
  final String title;
  final String artist;
  final String? artworkUrl;
  final bool playing;
  final double durationSecs;
  final bool shuffle;
  final String repeat;
  final bool liked;
  final bool disliked;
  final double volume; // 0..1
  final bool muted;

  /// Тема, чтобы окно совпадало с настройками юзера: акцент (ARGB, `null` —
  /// дефолт) и режим перфа (`beauty|medium|light`).
  final int? accent;
  final String perfMode;

  const MiniPlayerSnapshot({
    this.hasTrack = false,
    this.title = '',
    this.artist = '',
    this.artworkUrl,
    this.playing = false,
    this.durationSecs = 0,
    this.shuffle = false,
    this.repeat = 'off',
    this.liked = false,
    this.disliked = false,
    this.volume = 1,
    this.muted = false,
    this.accent,
    this.perfMode = 'beauty',
  });

  Map<String, dynamic> toJson() => {
        'hasTrack': hasTrack,
        'title': title,
        'artist': artist,
        'artworkUrl': artworkUrl,
        'playing': playing,
        'durationSecs': durationSecs,
        'shuffle': shuffle,
        'repeat': repeat,
        'liked': liked,
        'disliked': disliked,
        'volume': volume,
        'muted': muted,
        'accent': accent,
        'perfMode': perfMode,
      };

  factory MiniPlayerSnapshot.fromJson(Map<String, dynamic> j) => MiniPlayerSnapshot(
        hasTrack: j['hasTrack'] as bool? ?? false,
        title: j['title'] as String? ?? '',
        artist: j['artist'] as String? ?? '',
        artworkUrl: j['artworkUrl'] as String?,
        playing: j['playing'] as bool? ?? false,
        durationSecs: (j['durationSecs'] as num?)?.toDouble() ?? 0,
        shuffle: j['shuffle'] as bool? ?? false,
        repeat: j['repeat'] as String? ?? 'off',
        liked: j['liked'] as bool? ?? false,
        disliked: j['disliked'] as bool? ?? false,
        volume: (j['volume'] as num?)?.toDouble() ?? 1,
        muted: j['muted'] as bool? ?? false,
        accent: (j['accent'] as num?)?.toInt(),
        perfMode: j['perfMode'] as String? ?? 'beauty',
      );
}

/// Кодирование кадров (с завершающим `\n`).
String encodeNp(MiniPlayerSnapshot s) =>
    '${jsonEncode({'t': 'np', 's': s.toJson()})}\n';

String encodePos(double secs) => '${jsonEncode({'t': 'pos', 'v': secs})}\n';

String encodeCmd(String action, [double? value]) =>
    '${jsonEncode({'t': 'cmd', 'a': action, 'v': value})}\n';

String encodeHello() => '${jsonEncode({'t': 'hello'})}\n';

/// Один разобранный кадр (или `null` на мусоре).
class MiniFrame {
  final String type;
  final MiniPlayerSnapshot? snapshot;
  final double? value;
  final String? action;

  const MiniFrame(this.type, {this.snapshot, this.value, this.action});

  static MiniFrame? tryParse(String line) {
    if (line.trim().isEmpty) return null;
    try {
      final j = jsonDecode(line) as Map<String, dynamic>;
      final t = j['t'] as String?;
      if (t == null) return null;
      return MiniFrame(
        t,
        snapshot: j['s'] is Map
            ? MiniPlayerSnapshot.fromJson(Map<String, dynamic>.from(j['s'] as Map))
            : null,
        value: (j['v'] as num?)?.toDouble(),
        action: j['a'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Превращает поток байтов сокета в поток строк-кадров (NDJSON). `Socket` —
/// `Stream<Uint8List>`; приводим к `List<int>`, иначе `utf8.decoder` не биндится.
Stream<MiniFrame> decodeFrames(Stream<List<int>> socket) => socket
    .cast<List<int>>()
    .transform(utf8.decoder)
    .transform(const LineSplitter())
    .map(MiniFrame.tryParse)
    .where((f) => f != null)
    .cast<MiniFrame>();
