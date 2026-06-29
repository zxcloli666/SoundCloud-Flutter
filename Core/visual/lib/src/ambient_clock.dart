import 'dart:async';

import 'package:flutter/foundation.dart';

/// Единые «амбиент-часы» для фоновых idle-анимаций (дыхание обложек, мерцание
/// звёзд, дрейфы). КОРЕНЬ ПЕРФА: каждый `AnimationController.repeat()` тикает на
/// КАЖДЫЙ vsync (на 165Гц-мониторе → рендер 165 кадров/сек, даже если виджет
/// скипает репейнт). Десятки таких тикеров держат сцену в непрерывном рендере и
/// пегают CPU. Здесь — ОДИН таймер на ~20fps на всё приложение: фоновые кадры
/// капаются на 20/сек вместо 165. Анимации читают [tick] (repaint-listenable) и
/// [seconds] (фаза). Таймер живёт только пока есть подписчики (idle → выключен).
class AmbientClock {
  AmbientClock._();
  static final AmbientClock instance = AmbientClock._();

  /// ~10fps достаточно для медленных фоновых эффектов (дыхание/дрейф); кадры
  /// фоновой анимации капаются здесь, а не на 165Гц-vsync.
  static const _period = Duration(milliseconds: 100);

  final ValueNotifier<double> tick = ValueNotifier<double>(0);
  Timer? _timer;
  int _subscribers = 0;
  double _seconds = 0;

  /// Текущая фаза в секундах (монотонно растёт), для расчёта анимации.
  double get seconds => _seconds;

  void subscribe() {
    _subscribers++;
    _timer ??= Timer.periodic(_period, (_) {
      _seconds += _period.inMilliseconds / 1000.0;
      tick.value = _seconds;
    });
  }

  void unsubscribe() {
    if (_subscribers > 0) _subscribers--;
    if (_subscribers == 0) {
      _timer?.cancel();
      _timer = null;
    }
  }
}
