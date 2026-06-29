import 'package:flutter/foundation.dart';

/// Состояние строки относительно активной (легаси `[data-state]`).
enum LyricLineState { active, pastNear, past, nextNear, next }

/// Позиция воспроизведения для караоке: активная строка + её прогресс 0..1
/// (сглаженный ~30fps снаружи). Гоним через [ValueListenable], чтобы строки
/// перерисовывались без rebuild всего списка (легаси rAF + DOM-ref дизайн).
@immutable
class LyricsPlayhead {
  /// Индекс активной строки в переданном списку, или -1 если до первой.
  final int activeIndex;

  /// Прогресс внутри активной строки, 0..1.
  final double lineProgress;

  const LyricsPlayhead({this.activeIndex = -1, this.lineProgress = 0});

  LyricLineState stateFor(int index) {
    if (index == activeIndex) return LyricLineState.active;
    if (index == activeIndex - 1) return LyricLineState.pastNear;
    if (index == activeIndex + 1) return LyricLineState.nextNear;
    if (activeIndex >= 0 && index < activeIndex) return LyricLineState.past;
    return LyricLineState.next;
  }

  @override
  bool operator ==(Object other) =>
      other is LyricsPlayhead &&
      other.activeIndex == activeIndex &&
      other.lineProgress == lineProgress;

  @override
  int get hashCode => Object.hash(activeIndex, lineProgress);
}
