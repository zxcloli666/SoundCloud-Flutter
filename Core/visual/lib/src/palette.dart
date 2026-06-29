import 'package:flutter/widgets.dart';

/// Акцент и производные. Акцент задаёт юзер; hover/glow/selection считаем из него
/// (как `ThemeProvider` в легаси), а не хардкодим. Дефолт — SoundCloud #ff5500.
class ScPalette {
  final Color accent;

  const ScPalette([this.accent = const Color(0xFFFF5500)]);

  /// +26 на канал (clamp) = #ff6a1a для дефолта.
  Color get accentHover => _shift(accent, 26 / 255);
  Color get accentGlow => accent.withValues(alpha: 0.20);
  Color get accentSelection => accent.withValues(alpha: 0.30);
  Color get accentContrast => const Color(0xFFFFFFFF);

  /// Градиент play-кнопки: radial(125% at 32% 24%, hover → accent 68%).
  RadialGradient get playGradient => RadialGradient(
        center: const Alignment(-0.36, -0.52),
        radius: 1.25,
        colors: [accentHover, accent],
        stops: const [0.0, 0.68],
      );
}

Color _shift(Color color, double delta) {
  double up(double channel) => (channel + delta).clamp(0.0, 1.0);
  return Color.from(
    alpha: color.a,
    red: up(color.r),
    green: up(color.g),
    blue: up(color.b),
  );
}
