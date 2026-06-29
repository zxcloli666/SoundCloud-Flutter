import 'package:flutter/widgets.dart';

/// Плавная прокрутка колесом мыши. Дефолт Flutter (`ScrollPosition.pointerScroll`)
/// прыгает на дельту рывком — «ступеньки». Здесь подменяем позицию на анимирующую
/// к цели с накоплением: быстрые щелчки колеса складываются в один гладкий разгон.
///
/// Перехват — на уровне самой позиции (тот же метод, что зовёт `Scrollable`),
/// поэтому всегда выигрывает у дефолтного рывка; драг/тач/трекпад не трогаем —
/// там работает обычная инерционная физика.
class SmoothScrollController extends ScrollController {
  /// Множитель дельты колеса (крупнее — длиннее шаг прокрутки).
  final double speed;

  /// Длительность догона до цели.
  final Duration duration;

  SmoothScrollController({
    this.speed = 1.0,
    this.duration = const Duration(milliseconds: 320),
    super.initialScrollOffset,
    super.keepScrollOffset,
    super.debugLabel,
  });

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return _SmoothScrollPosition(
      owner: this,
      physics: physics,
      context: context,
      oldPosition: oldPosition,
    );
  }
}

class _SmoothScrollPosition extends ScrollPositionWithSingleContext {
  final SmoothScrollController owner;

  /// Накопитель цели: пока анимируем — следующий щелчок добавляется к ней,
  /// а не к фактической (ещё едущей) позиции.
  double? _target;

  _SmoothScrollPosition({
    required this.owner,
    required super.physics,
    required super.context,
    super.oldPosition,
  });

  @override
  void pointerScroll(double delta) {
    if (delta == 0) {
      goBallistic(0);
      return;
    }
    final base = _target ?? pixels;
    final double next = (base + delta * owner.speed)
        .clamp(minScrollExtent, maxScrollExtent)
        .toDouble();
    if (next == pixels) {
      _target = null;
      goBallistic(0);
      return;
    }
    _target = next;
    animateTo(next, duration: owner.duration, curve: Curves.easeOutCubic)
        .whenComplete(() {
      if (_target == next) _target = null;
    });
  }
}
