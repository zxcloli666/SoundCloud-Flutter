import '../../rust/api.dart';

/// Коллекция манифеста: лайки (могут быть без файла) или кэш (файлы на диске).
enum OfflineSection { likes, cached }

/// Режимы сортировки манифеста. `custom` — канонический порядок (лайки —
/// в порядке лайканья, кэш — пользовательский drag-порядок).
enum SortMode { custom, recent, title, artist, duration, size }

/// Готовность ffmpeg-горна.
enum FfmpegState { ready, preparing, unavailable }

/// Стадия файла на диске: сырьё (А) или чистый m4a (Б).
enum CacheStage { raw, clean }

/// Факты о файле трека на диске (зеркало Rust `CacheInventoryEntry`).
///
/// В Core ещё нет моста к `sc-cache`, поэтому источник — пустой/инжектируемый.
class CacheInventoryEntry {
  final String urn;
  final int bytes;
  final CacheStage stage;
  final bool liked;
  final int? durationMs;
  final int? expectedDurationMs;
  final int modifiedAt;

  const CacheInventoryEntry({
    required this.urn,
    required this.bytes,
    required this.stage,
    this.liked = false,
    this.durationMs,
    this.expectedDurationMs,
    this.modifiedAt = 0,
  });
}

/// Live-снимок кузницы А→Б (зеркало Rust `track_transcode_status`).
class ForgeStatus {
  final FfmpegState ffmpeg;
  final int incoming;
  final int transcoding;
  final int clean;
  final List<String> transcodingUrns;

  const ForgeStatus({
    this.ffmpeg = FfmpegState.preparing,
    this.incoming = 0,
    this.transcoding = 0,
    this.clean = 0,
    this.transcodingUrns = const [],
  });
}

/// Строка офлайн-библиотеки: метаданные трека + факты о файле.
/// `inv == null` — лайк без файла; `stub` — файл без записи в индексе.
///
/// `lazy == true` — `track` это плейсхолдер по urn (кэш отдаёт только
/// urn/scId/байты), реальные тайтл/арт строка догружает через `trackProvider`.
class OfflineEntry {
  final String urn;
  final TrackDto track;
  final CacheInventoryEntry? inv;
  final bool stub;
  final bool lazy;

  const OfflineEntry({
    required this.urn,
    required this.track,
    this.inv,
    this.stub = false,
    this.lazy = false,
  });

  bool get cached => inv != null;
}

/// Плейсхолдер-трек для строки кэша до резолва метаданных по urn.
/// Тайтл — голый id-хвост; строка покажет его моноширинно, как `stub`.
TrackDto placeholderTrack(String urn) => TrackDto(
      urn: urn,
      title: urn.split(':').last,
      artistName: '',
      artistId: '',
      durationMs: BigInt.zero,
      uploaderVerified: false,
      isCover: false,
      tags: const [],
      participants: const [],
    );

const _durationToleranceMs = 4000;
const _durationToleranceFrac = 0.04;

/// Файл короче заявленного API → обрезок (одностороннее зеркало Rust-проверки).
bool isTruncated(CacheInventoryEntry? inv) {
  final actual = inv?.durationMs;
  final expected = inv?.expectedDurationMs;
  if (actual == null || expected == null || actual == 0 || expected == 0) {
    return false;
  }
  final tol =
      (expected * _durationToleranceFrac).clamp(_durationToleranceMs.toDouble(), double.infinity);
  return actual + tol < expected;
}

/// Реальная длительность файла, если измерена; иначе заявленная API.
int effectiveDurationMs(OfflineEntry e) =>
    e.inv?.durationMs ?? e.track.durationMs.toInt();

List<OfflineEntry> filterEntries(List<OfflineEntry> entries, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return entries;
  return entries
      .where((e) =>
          e.track.title.toLowerCase().contains(q) ||
          e.track.artistName.toLowerCase().contains(q))
      .toList();
}

int _recentKey(OfflineEntry e) => e.inv?.modifiedAt ?? 0;

/// `customOrder == null` в режиме custom — входной порядок уже канонический.
/// Неизвестные custom-порядку треки уходят в конец, свежие выше.
List<OfflineEntry> sortEntries(
  List<OfflineEntry> entries,
  SortMode mode,
  List<String>? customOrder,
) {
  if (mode == SortMode.custom) {
    if (customOrder == null) return entries;
    final idx = {for (var i = 0; i < customOrder.length; i++) customOrder[i]: i};
    final out = [...entries];
    out.sort((a, b) {
      final ai = idx[a.urn];
      final bi = idx[b.urn];
      if (ai != null && bi != null) return ai - bi;
      if (ai != null) return -1;
      if (bi != null) return 1;
      return _recentKey(b) - _recentKey(a);
    });
    return out;
  }

  final out = [...entries];
  switch (mode) {
    case SortMode.recent:
      out.sort((a, b) => _recentKey(b) - _recentKey(a));
    case SortMode.title:
      out.sort((a, b) => a.track.title.compareTo(b.track.title));
    case SortMode.artist:
      out.sort((a, b) {
        final c = a.track.artistName.compareTo(b.track.artistName);
        return c != 0 ? c : a.track.title.compareTo(b.track.title);
      });
    case SortMode.duration:
      out.sort((a, b) => effectiveDurationMs(b) - effectiveDurationMs(a));
    case SortMode.size:
      out.sort((a, b) => (b.inv?.bytes ?? 0) - (a.inv?.bytes ?? 0));
    case SortMode.custom:
      break;
  }
  return out;
}

/// `formatBytes` (легаси §5.7): ≤0→`0 B`; <1KB→`B`; <1MB→`KB`; <1GB→`MB`; else `GB`.
String formatBytes(int b) {
  if (b <= 0) return '0 B';
  if (b < 1024) return '$b B';
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
  if (b < 1024 * 1024 * 1024) {
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(b / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}
