import 'package:flutter/widgets.dart';
import 'package:sc_visual/sc_visual.dart';

/// Цвет «комнаты» трека, выведенный из жанра. Легаси берёт хью из таблицы
/// `genreColor`; здесь — детерминированный хью из имени жанра (стабильно между
/// заходами), переведённый в насыщённый тёмно-яркий тон. Без жанра → акцент юзера.
class TrackAura {
  final Color accent;
  final bool hasGenre;

  const TrackAura(this.accent, this.hasGenre);

  Color get glow => accent.withValues(alpha: 0.32);
  Color get soft => accent.withValues(alpha: 0.16);

  static TrackAura resolve(String? genre, Color viewerAccent) {
    final g = genre?.trim();
    if (g == null || g.isEmpty) return TrackAura(viewerAccent, false);
    final hue = (fnv1a(g.toLowerCase()) % 360).toDouble();
    final color = HSLColor.fromAHSL(1, hue, 0.62, 0.56).toColor();
    return TrackAura(color, true);
  }
}
