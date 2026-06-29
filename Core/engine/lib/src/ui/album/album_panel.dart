import 'package:flutter/material.dart';
import 'package:sc_visual/sc_visual.dart';

/// Стеклянная панель альбома `rounded-[2rem]` (легаси Cast/TrackList) поверх
/// каноничного [GlassContentPanel]. Отличие от остальных — чуть более тёплый
/// плотный фон под `light`-режимом.
class AlbumPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const AlbumPanel({super.key, required this.child, required this.padding});

  @override
  Widget build(BuildContext context) {
    return GlassContentPanel(
      recipe: const GlassContentRecipe(lightFallback: Color(0xD912121C)),
      padding: padding,
      child: child,
    );
  }
}
