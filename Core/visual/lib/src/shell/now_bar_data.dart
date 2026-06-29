import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';

/// Режим повтора плеера (off → all → one), как в legacy player-store.
enum NowBarRepeat { off, all, one }

/// Качество отдачи потока для бейджа (HQ/SQ).
enum NowBarQuality { hq, sq }

/// Источник воспроизведения; `storage` рисует доп. CDN-пилюлю.
enum NowBarSource { storage, anon, direct, api }

/// Снимок состояния плеера для [NowBar]. Чистые данные — без логики и IO.
///
/// Поля 1:1 c legacy player-store (§2.4): трек, транспорт, AB-петля, прогресс
/// загрузки, качество/источник, громкость. Позиция/длительность тикают снаружи
/// (через `ValueNotifier`/тикер), здесь — текущий снимок для отрисовки.
@immutable
class NowBarData {
  final String title;
  final String artist;
  final String? artworkUrl;
  final bool playing;
  final double positionSecs;
  final double durationSecs;

  /// Живая позиция (секунды) для дорожки прогресса. Когда задана, только лента
  /// перерисовывается на тик (`audio:tick` ~10Hz) — пилюля строится один раз.
  /// `null` — статичный снимок из [positionSecs] (для встраиваний без тикера).
  final ValueListenable<double>? positionListenable;

  // Транспорт
  final bool shuffle;
  final NowBarRepeat repeat;

  // AB-петля: a задан, b — конец (или null пока ждём вторую точку).
  final double? abLoopA;
  final double? abLoopB;
  final bool abLoopAwaitingB;

  // Реакция
  final bool liked;
  final bool disliked;

  // Качество / источник
  final NowBarQuality? quality;
  final NowBarSource? source;

  // Загрузка трека: 0..1, либо null когда не грузится.
  final double? downloadProgress;

  // Громкость 0..1 и состояние мьюта.
  final double volume;
  final bool muted;

  const NowBarData({
    required this.title,
    required this.artist,
    this.artworkUrl,
    this.playing = false,
    this.positionSecs = 0,
    this.durationSecs = 0,
    this.positionListenable,
    this.shuffle = false,
    this.repeat = NowBarRepeat.off,
    this.abLoopA,
    this.abLoopB,
    this.abLoopAwaitingB = false,
    this.liked = false,
    this.disliked = false,
    this.quality,
    this.source,
    this.downloadProgress,
    this.volume = 1,
    this.muted = false,
  });

  bool get isLoading => downloadProgress != null;

  /// Процент загрузки 1..100 для кольца/вуали (legacy clamp).
  int get loadPercent {
    final p = (downloadProgress ?? 0).clamp(0.0, 1.0);
    return (p * 100).round().clamp(1, 100);
  }

  bool get abLoopActive => abLoopA != null;
}

/// Колбэки управления плеером. Любой может быть null (кнопка станет неактивной).
@immutable
class NowBarCallbacks {
  final VoidCallback? onPlayPause;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final ValueChanged<double>? onSeek;
  final VoidCallback? onShuffle;
  final VoidCallback? onRepeat;
  final VoidCallback? onAbLoop;
  final VoidCallback? onLike;
  final VoidCallback? onDislike;
  final VoidCallback? onTuning;
  final VoidCallback? onEqualizer;
  final VoidCallback? onLyrics;
  final VoidCallback? onQueue;
  final VoidCallback? onMuteToggle;
  final ValueChanged<double>? onVolume;
  final VoidCallback? onArtworkTap;
  final VoidCallback? onTitleTap;

  const NowBarCallbacks({
    this.onPlayPause,
    this.onPrev,
    this.onNext,
    this.onSeek,
    this.onShuffle,
    this.onRepeat,
    this.onAbLoop,
    this.onLike,
    this.onDislike,
    this.onTuning,
    this.onEqualizer,
    this.onLyrics,
    this.onQueue,
    this.onMuteToggle,
    this.onVolume,
    this.onArtworkTap,
    this.onTitleTap,
  });
}
