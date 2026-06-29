import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

import 'perf.dart';
import 'theme.dart';
import 'tokens.dart';

enum GlassVariant { panel, featured, nowBar }

/// Рецепт стекла как данные. Конкретные значения зависят от [PerfMode]
/// (light → blur 0 + плотный tint вместо размытия).
class GlassSpec {
  final double blur;
  final Color tintColor;
  final Gradient? overlayGradient;
  final Color borderColor;
  final double borderWidth;
  final List<BoxShadow> shadows;

  const GlassSpec({
    required this.blur,
    required this.tintColor,
    required this.borderColor,
    this.overlayGradient,
    this.borderWidth = 1,
    this.shadows = const [],
  });

  factory GlassSpec.of(GlassVariant variant, PerfMode mode) {
    final light = mode == PerfMode.light;
    switch (variant) {
      case GlassVariant.panel:
        return GlassSpec(
          blur: _blur(mode, ScTokens.blurBeautyNormal, ScTokens.blurMediumNormal),
          tintColor: light ? ScTokens.lightGlass : ScTokens.glassTint,
          borderColor: const Color(0x0DFFFFFF), // .glass border = white 0.05
        );
      case GlassVariant.featured:
        return GlassSpec(
          blur: _blur(mode, ScTokens.blurBeautyStrong, ScTokens.blurMediumStrong),
          tintColor: light ? ScTokens.lightGlassFeatured : ScTokens.glassFeaturedTint,
          borderColor: ScTokens.glassFeaturedBorder,
          shadows: const [
            BoxShadow(color: Color(0x4D000000), blurRadius: 40, offset: Offset(0, 8)),
          ],
        );
      case GlassVariant.nowBar:
        return GlassSpec(
          blur: _blur(mode, ScTokens.blurBeautySoft, ScTokens.blurMediumSoft),
          tintColor: light ? ScTokens.lightNpb : ScTokens.npbGlassColor,
          overlayGradient: light
              ? null
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x17FFFFFF), Color(0x06FFFFFF), Color(0x03FFFFFF)],
                  stops: [0, 0.44, 1],
                ),
          borderColor: const Color(0x1CFFFFFF),
          shadows: const [
            BoxShadow(
              color: Color(0xC7000000),
              blurRadius: 70,
              spreadRadius: -22,
              offset: Offset(0, 30),
            ),
          ],
        );
    }
  }
}

double _blur(PerfMode mode, double beauty, double medium) => switch (mode) {
      PerfMode.beauty => beauty,
      PerfMode.medium => medium,
      PerfMode.light => 0,
    };

/// Общий рендер стекла: тень (вне clip) → clip → backdrop-blur → tint+border →
/// overlay-градиент → контент.
class _GlassSurface extends StatelessWidget {
  final GlassSpec spec;
  final double radius;
  final EdgeInsetsGeometry padding;
  final Color? tintOverride;
  final Widget child;

  const _GlassSurface({
    required this.spec,
    required this.radius,
    required this.padding,
    required this.child,
    this.tintOverride,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);

    Widget content = DecoratedBox(
      decoration: BoxDecoration(
        color: tintOverride ?? spec.tintColor,
        borderRadius: borderRadius,
        border: Border.all(color: spec.borderColor, width: spec.borderWidth),
      ),
      child: spec.overlayGradient == null
          ? Padding(padding: padding, child: child)
          : DecoratedBox(
              decoration: BoxDecoration(
                gradient: spec.overlayGradient,
                borderRadius: borderRadius,
              ),
              child: Padding(padding: padding, child: child),
            ),
    );

    if (spec.blur > 0) {
      content = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: spec.blur, sigmaY: spec.blur),
        child: content,
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: borderRadius, boxShadow: spec.shadows),
      child: ClipRRect(borderRadius: borderRadius, child: content),
    );
  }
}

/// Статичная стеклянная панель.
class GlassPanel extends StatelessWidget {
  final Widget child;
  final GlassVariant variant;
  final double radius;
  final EdgeInsetsGeometry padding;

  const GlassPanel({
    super.key,
    required this.child,
    this.variant = GlassVariant.panel,
    this.radius = ScTokens.rCard,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return _GlassSurface(
      spec: GlassSpec.of(variant, ScPerf.of(context)),
      radius: radius,
      padding: padding,
      child: child,
    );
  }
}

/// Кликабельная стеклянная карточка с hover-подсветкой.
class GlassCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double radius;
  final EdgeInsetsGeometry padding;

  const GlassCard({
    super.key,
    required this.child,
    this.onTap,
    this.radius = ScTokens.rCard,
    this.padding = const EdgeInsets.all(12),
  });

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final spec = GlassSpec.of(GlassVariant.panel, ScPerf.of(context));
    return MouseRegion(
      cursor: widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: ScTokens.dFast,
          curve: ScTokens.easeApple,
          child: _GlassSurface(
            spec: spec,
            radius: widget.radius,
            padding: widget.padding,
            tintOverride: _hover ? ScTokens.glassTintHover : null,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Стеклянная кнопка: ghost (по умолчанию) или primary (акцентный градиент).
class GlassButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool primary;
  final EdgeInsetsGeometry padding;

  const GlassButton({
    super.key,
    required this.child,
    this.onTap,
    this.primary = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(ScTokens.rButton);
    if (primary) {
      final palette = ScTheme.paletteOf(context);
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: palette.playGradient,
              boxShadow: [
                BoxShadow(color: palette.accentGlow, blurRadius: 24, offset: const Offset(0, 6)),
              ],
            ),
            child: Padding(
              padding: padding,
              child: DefaultTextStyle.merge(
                style: const TextStyle(color: Color(0xFFFFFFFF), fontWeight: FontWeight.w600),
                child: child,
              ),
            ),
          ),
        ),
      );
    }
    return GlassCard(
      onTap: onTap,
      radius: ScTokens.rButton,
      padding: padding,
      child: child,
    );
  }
}
