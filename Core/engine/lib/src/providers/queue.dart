import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../rust/api.dart';

/// Активный контекст очереди: список, из которого пользователь запустил
/// воспроизведение (лайки/альбом/плейлист/поиск), и позиция текущего трека в нём.
///
/// Это НЕ бесконечная волна — это конечный пользовательский список. Когда он
/// доигран до конца, очередь падает в волну (инвариант queue-continuation:
/// сначала доигрываем лайки/альбом, ПОТОМ продолжаем волной).
class QueueContext {
  final List<TrackDto> tracks;
  final int index;

  const QueueContext({required this.tracks, required this.index});

  /// Трек на текущей позиции, либо `null` если контекст пуст/вышел за границы.
  TrackDto? get current =>
      (index >= 0 && index < tracks.length) ? tracks[index] : null;

  /// Есть ли следующий трек в пределах списка.
  bool get hasNext => index >= 0 && index + 1 < tracks.length;

  /// Есть ли предыдущий трек в пределах списка.
  bool get hasPrev => index > 0 && index <= tracks.length;

  QueueContext copyWith({List<TrackDto>? tracks, int? index}) {
    return QueueContext(
      tracks: tracks ?? this.tracks,
      index: index ?? this.index,
    );
  }
}

/// Контекст очереди (`null` — активного списка нет, продолжаем волной).
/// Пишет сюда [PlayerNotifier.play] через [set]; читает [PlaybackQueueNotifier]
/// при выборе следующего трека.
final queueContextProvider =
    NotifierProvider<QueueContextNotifier, QueueContext?>(
  QueueContextNotifier.new,
);

class QueueContextNotifier extends Notifier<QueueContext?> {
  @override
  QueueContext? build() => null;

  /// Установить активный список и позицию в нём.
  void set(List<TrackDto> tracks, int index) {
    if (tracks.isEmpty) {
      state = null;
      return;
    }
    final clamped = index.clamp(0, tracks.length - 1);
    state = QueueContext(tracks: tracks, index: clamped);
  }

  /// Сбросить контекст — следующий трек берётся из волны.
  void clear() => state = null;

  /// Перевести указатель на [index] (например, после ручного next/prev по списку).
  void moveTo(int index) {
    final current = state;
    if (current == null) return;
    state = current.copyWith(index: index.clamp(0, current.tracks.length - 1));
  }
}
