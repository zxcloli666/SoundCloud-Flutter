import 'package:flutter/material.dart';

import 'palette.dart';
import 'tokens.dart';

/// Тёмная тема под легаси. Шрифты (Inter/Unbounded) пока не бандлим — fallback
/// на системный; добавим .ttf отдельно (TODO).
ThemeData scDarkTheme([ScPalette palette = const ScPalette()]) {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: ScTokens.bgRoot,
    splashFactory: InkSparkle.splashFactory,
    colorScheme: ColorScheme.dark(
      primary: palette.accent,
      onPrimary: palette.accentContrast,
      secondary: palette.accent,
      surface: ScTokens.bgPrimary,
      onSurface: ScTokens.textPrimary,
    ),
  );
}

/// Несёт по дереву то, что не ложится в [ThemeData]: палитру и токены.
class ScTheme extends InheritedWidget {
  final ScPalette palette;

  const ScTheme({super.key, required this.palette, required super.child});

  static ScPalette paletteOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ScTheme>()?.palette ??
      const ScPalette();

  @override
  bool updateShouldNotify(ScTheme oldWidget) => oldWidget.palette != palette;
}
