import 'package:flutter/widgets.dart';

import '../../rust/api.dart';
import '../track/track_aura.dart';

/// Доля жанра в плейлисте: имя, цвет (детерминированный хью), нормированный вес.
class GenreShare {
  final String genre;
  final Color color;
  final double share;

  const GenreShare({required this.genre, required this.color, required this.share});
}

/// Сводная «идентичность» плейлиста (легаси `usePlaylistAura`): доминантный
/// жанр задаёт акцент заголовка/действий, набор топ-жанров — флеки и ленту.
/// Разнородный плейлист светит несколькими хью, моно — одним. Без жанров —
/// акцент зрителя.
class PlaylistAura {
  /// Цвет, ведущий заголовок/play-пилюлю (доминантный жанр или акцент зрителя).
  final Color accent;

  /// Топ-жанры (≤3) с долей — для флек-легенды и ленты.
  final List<GenreShare> topGenres;

  /// Тинты для атмосферы (по топ-жанрам), пусто → одноцветная.
  final List<Color> tint;

  /// Энергия 0..1 (выше у горячих жанров) — гонит дрейф атмосферы.
  final double energy;

  const PlaylistAura({
    required this.accent,
    required this.topGenres,
    required this.tint,
    required this.energy,
  });

  Color get glow => accent.withValues(alpha: 0.32);

  bool get hasGenres => topGenres.isNotEmpty;

  static PlaylistAura resolve(
    List<TrackDto> tracks,
    Color viewerAccent, {
    String? fallbackGenre,
  }) {
    final counts = <String, int>{};
    for (final tr in tracks) {
      final g = tr.genre?.trim();
      if (g != null && g.isNotEmpty) {
        counts[g] = (counts[g] ?? 0) + 1;
      }
    }
    if (counts.isEmpty && fallbackGenre != null && fallbackGenre.trim().isNotEmpty) {
      counts[fallbackGenre.trim()] = 1;
    }

    if (counts.isEmpty) {
      return PlaylistAura(
        accent: viewerAccent,
        topGenres: const [],
        tint: const [],
        energy: 0.5,
      );
    }

    final total = counts.values.fold<int>(0, (a, b) => a + b);
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(3).map((e) {
      final color = TrackAura.resolve(e.key, viewerAccent).accent;
      return GenreShare(genre: e.key, color: color, share: e.value / total);
    }).toList();

    // Энергия = доминирование топ-жанра (фокусный плейлист «горячее»).
    final energy = (0.35 + top.first.share * 0.5).clamp(0.0, 1.0);

    return PlaylistAura(
      accent: top.first.color,
      topGenres: top,
      tint: top.map((g) => g.color).toList(),
      energy: energy,
    );
  }
}
