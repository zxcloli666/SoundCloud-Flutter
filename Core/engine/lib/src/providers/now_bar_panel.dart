import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Какая инструмент-панель NowBar открыта поверх контента. Один писатель —
/// тулы пилюли (EQ/очередь/лирика); рендер — [NowBarPanelHost] в шелле.
enum NowBarPanel { none, equalizer, queue, lyrics }

final nowBarPanelProvider =
    NotifierProvider<NowBarPanelNotifier, NowBarPanel>(NowBarPanelNotifier.new);

class NowBarPanelNotifier extends Notifier<NowBarPanel> {
  @override
  NowBarPanel build() => NowBarPanel.none;

  /// Тоггл: повторный тык по той же кнопке закрывает панель (как в легаси).
  void toggle(NowBarPanel panel) =>
      state = state == panel ? NowBarPanel.none : panel;

  void close() => state = NowBarPanel.none;
}
