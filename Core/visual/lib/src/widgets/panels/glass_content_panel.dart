import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

import '../../perf.dart';

/// Каноничный рецепт «контент-панели» легаси (§3.x `rounded-[2rem]`): мягкая
/// стеклянная плита под активной вкладкой/каталогом. Под `beauty/medium` —
/// backdrop-blur 28 + светлый градиент-tint; под `light` — плотный непрозрачный
/// фон без блюра. Тень и рамка одинаковы во всех режимах.
///
/// Раньше копировался 1:1 в artist/user/discover/album. Box-вариант —
/// [GlassContentPanel], sliver-вариант — [GlassContentSliver].
class GlassContentRecipe {
  /// Логический blur-радиус (CSS px) до перф-деградации.
  final double blurPx;

  /// Плотный фон для `light`-режима (когда блюр выключен).
  final Color lightFallback;

  const GlassContentRecipe({
    this.blurPx = 28,
    this.lightFallback = const Color(0xD9121216), // rgba(18,18,22,0.85)
  });

  static const _gradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x09FFFFFF), Color(0x04FFFFFF)],
  );

  static const _border = Color(0x0FFFFFFF); // white 0.06
  static const _shadow = [
    BoxShadow(color: Color(0x4D000000), blurRadius: 80, offset: Offset(0, 30)),
  ];

  static const _radius = 32.0; // 2rem

  /// Сигма для `ImageFilter.blur`; 0 ⇒ блюр не нужен (рисуем плотный tint).
  double sigmaOf(BuildContext context) =>
      PerfProfile.of(context).sigma(blurPx);

  /// Декорация плиты: при `blurred` — прозрачный градиент поверх блюра, иначе
  /// плотный фон.
  BoxDecoration decoration({required bool blurred, required BorderRadius radius}) {
    return BoxDecoration(
      gradient: blurred ? _gradient : null,
      color: blurred ? null : lightFallback,
      borderRadius: radius,
      border: Border.all(color: _border),
      boxShadow: _shadow,
    );
  }
}

/// Box-вариант контент-панели. Паддинг по умолчанию следует легаси `p-3/5`
/// (узкий 12 / широкий 20); каталоги передают свой.
class GlassContentPanel extends StatelessWidget {
  final Widget child;
  final GlassContentRecipe recipe;
  final EdgeInsetsGeometry? padding;

  const GlassContentPanel({
    super.key,
    required this.child,
    this.recipe = const GlassContentRecipe(),
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final sigma = recipe.sigmaOf(context);
    final blurred = sigma > 0;
    final radius = BorderRadius.circular(GlassContentRecipe._radius);
    final pad = padding ??
        EdgeInsets.all(MediaQuery.sizeOf(context).width >= 768 ? 20 : 12);

    Widget panel = DecoratedBox(
      decoration: recipe.decoration(blurred: blurred, radius: radius),
      child: Padding(padding: pad, child: child),
    );

    if (!blurred) return panel;
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: panel,
      ),
    );
  }
}

/// Sliver-вариант: рисует стекло за всю высоту прокручиваемого каталога
/// ([DecoratedSliver]). Блюр здесь не применяется (sliver не оборачивается в
/// BackdropFilter) — решение градиент/плотный фон делает порог перф-режима.
class GlassContentSliver extends StatelessWidget {
  final Widget sliver;
  final GlassContentRecipe recipe;
  final EdgeInsetsGeometry padding;

  const GlassContentSliver({
    super.key,
    required this.sliver,
    required this.padding,
    this.recipe = const GlassContentRecipe(),
  });

  @override
  Widget build(BuildContext context) {
    final blurred = PerfProfile.of(context).blur(recipe.blurPx) > 0;
    final radius = BorderRadius.circular(GlassContentRecipe._radius);
    return DecoratedSliver(
      decoration: recipe.decoration(blurred: blurred, radius: radius),
      sliver: SliverPadding(padding: padding, sliver: sliver),
    );
  }
}
