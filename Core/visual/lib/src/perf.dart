import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Режим производительности: масштабирует тяжесть эффектов (блюр, атмосфера,
/// частицы). beauty = как задумано; light = плоско и быстро.
enum PerfMode { beauty, medium, light }

/// Резолвер профиля из легаси `usePerfMode()` (§1.7): каждый эффект выражается
/// ЧЕРЕЗ способность, чтобы beauty воспроизводил оригинал, а light/medium
/// детерминированно деградировали. Эффекты НЕ скрываются жёстко — параметризуются.
class PerfProfile {
  final PerfMode mode;

  const PerfProfile(this.mode);

  factory PerfProfile.of(BuildContext context) => PerfProfile(ScPerf.of(context));

  /// CSS `blur(px)` по режиму: beauty→px, medium→round(px·0.5), light→0.
  /// Это «логический px» как в легаси-переменных --glass-blur (не сигма).
  double blur(double px) => switch (mode) {
        PerfMode.beauty => px,
        PerfMode.medium => (px * 0.5).roundToDouble(),
        PerfMode.light => 0,
      };

  /// Сигма для `ImageFilter.blur` из CSS-радиуса: WebKit Gaussian ≈ px/2.
  /// 0 ⇒ BackdropFilter не нужен (вызывающий рисует плотный tint).
  double sigma(double px) {
    final resolved = blur(px);
    return resolved <= 0 ? 0 : resolved / 2;
  }

  /// Кол-во частиц: beauty→n, medium→ceil(n·0.45), light→0.
  int particles(int n) => switch (mode) {
        PerfMode.beauty => n,
        PerfMode.medium => (n * 0.45).ceil(),
        PerfMode.light => 0,
      };

  /// Idle-анимации (дрейф/мерцание/спин/маркиза): выкл только в light.
  bool get idleAnim => mode != PerfMode.light;

  /// Атмосфера (орбы/звёздные поля): выкл только в light.
  bool get atmosphere => mode != PerfMode.light;

  /// Per-element glow (drop/box-shadow свечение): только beauty.
  bool get glow => mode == PerfMode.beauty;

  /// Тяжёлые фоновые блумы / per-card гало: выкл только в light.
  bool get bloom => mode != PerfMode.light;

  /// Доля масштаба для линейной деградации (1 / 0.5 / 0).
  double get scale => switch (mode) {
        PerfMode.beauty => 1,
        PerfMode.medium => 0.5,
        PerfMode.light => 0,
      };

  /// Линейный интерполятор величины эффекта между light и beauty.
  double lerp(double min, double max) => min + (max - min) * scale;

  /// Округлённый счётчик по режиму (например бары waveform 64/120/160).
  int count({required int beauty, required int medium, required int light}) =>
      switch (mode) {
        PerfMode.beauty => beauty,
        PerfMode.medium => medium,
        PerfMode.light => light,
      };

  /// Длительность idle-анимации: в light схлопывается в ноль (статика).
  Duration idleDuration(Duration value) =>
      idleAnim ? value : Duration.zero;

  /// Удобный clamp для долей частиц/орбов под произвольный потолок.
  int clampCount(int n, {int max = 1 << 30}) => math.max(0, math.min(n, max));
}

/// Предоставляет [PerfMode] поддереву. Виджеты стекла/атмосферы читают его.
class ScPerf extends InheritedWidget {
  final PerfMode mode;

  const ScPerf({super.key, required this.mode, required super.child});

  static PerfMode of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ScPerf>()?.mode ??
      PerfMode.beauty;

  /// Резолвер профиля из ближайшего [ScPerf] (или beauty по умолчанию).
  static PerfProfile profileOf(BuildContext context) =>
      PerfProfile(of(context));

  @override
  bool updateShouldNotify(ScPerf oldWidget) => oldWidget.mode != mode;
}
