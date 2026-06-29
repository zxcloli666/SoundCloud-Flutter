import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';

/// Глобальный скролл-бихейвор приложения: плавная инерция с лёгким баунсом
/// (премиум-фил вместо «ступенчатого» дефолта), прокрутка мышью/тачем/трекпадом/
/// стилусом, без дефолтного оверскролл-свечения. Скроллбар оставляем дефолтным
/// (его стилизуют сами скролл-вью при необходимости).
class ScScrollBehavior extends MaterialScrollBehavior {
  const ScScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      child;
}
