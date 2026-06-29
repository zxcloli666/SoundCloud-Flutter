import 'package:flutter/widgets.dart';

/// Чип жанровой ленты: ключ-запрос, лейбл, акцентный цвет точки.
class GenreChip {
  final String key;
  final String label;
  final Color color;

  const GenreChip({required this.key, required this.label, required this.color});
}

/// Курируемый набор жанров (легаси `search/utils.GENRES`, 12 ручных оттенков) —
/// fallback для ленты, когда на стене мало тегированных треков.
const genres = <GenreChip>[
  GenreChip(key: 'lofi', label: 'Lo-fi', color: Color(0xFF8B9DC3)),
  GenreChip(key: 'house', label: 'House', color: Color(0xFFFF7A59)),
  GenreChip(key: 'phonk', label: 'Phonk', color: Color(0xFFC026D3)),
  GenreChip(key: 'ambient', label: 'Ambient', color: Color(0xFF5EEAD4)),
  GenreChip(key: 'rnb', label: 'R&B', color: Color(0xFFF0ABFC)),
  GenreChip(key: 'trap', label: 'Trap', color: Color(0xFFFB7185)),
  GenreChip(key: 'jazz', label: 'Jazz', color: Color(0xFFFBBF24)),
  GenreChip(key: 'techno', label: 'Techno', color: Color(0xFF60A5FA)),
  GenreChip(key: 'indie', label: 'Indie', color: Color(0xFFA3E635)),
  GenreChip(key: 'soul', label: 'Soul', color: Color(0xFFFCA5A5)),
  GenreChip(key: 'dnb', label: 'DnB', color: Color(0xFF34D399)),
  GenreChip(key: 'hyperpop', label: 'Hyperpop', color: Color(0xFFE879F9)),
];

/// Детерминированный цвет по имени жанра (легаси `genreColor`): известные —
/// фиксированный оттенок, прочие — стабильный HSL hue из хеша имени.
Color genreColor(String? name, Color accent) {
  final lower = name?.toLowerCase();
  for (final g in genres) {
    if (g.key == lower) return g.color;
  }
  if (name == null || name.isEmpty) return accent;
  var hash = 0;
  for (final code in name.codeUnits) {
    hash = (hash * 31 + code) & 0xFFFFFFFF;
  }
  final hue = (hash.abs() % 360).toDouble();
  return HSLColor.fromAHSL(1, hue, 0.70, 0.62).toColor();
}

const _hot = [
  'phonk', 'trap', 'festival', 'house', 'techno', 'dnb', 'drum', 'hardstyle',
  'hyperpop', 'rave', 'edm', 'dubstep', 'bass', 'hardcore',
];
const _cold = [
  'ambient', 'lofi', 'lo-fi', 'chill', 'sad', 'piano', 'acoustic', 'soul',
  'jazz', 'classical', 'sleep', 'study', 'downtempo', 'r&b', 'rnb', 'slow',
];

/// Энергия жанра 0 (спокойно/холодно) .. 1 (горячо/быстро) — гонит дрейф орбов.
double genreEnergy(String? name) {
  final n = name?.toLowerCase() ?? '';
  if (_hot.any(n.contains)) return 0.85;
  if (_cold.any(n.contains)) return 0.2;
  return 0.5;
}

/// Средняя энергия по доминирующим жанрам набора (топ-4).
double vibeEnergy(List<String> topGenres) {
  if (topGenres.isEmpty) return 0.5;
  final take = topGenres.take(4);
  final sum = take.fold<double>(0, (acc, g) => acc + genreEnergy(g));
  return sum / take.length;
}

/// Топ-жанры набора треков по частоте (для ленты и тинта атмосферы).
List<String> topGenres(Iterable<String?> trackGenres, int n) {
  final counts = <String, int>{};
  for (final raw in trackGenres) {
    final g = raw?.trim();
    if (g == null || g.isEmpty) continue;
    counts[g] = (counts[g] ?? 0) + 1;
  }
  final sorted = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return [for (final e in sorted.take(n)) e.key];
}

/// Доля жанра в коллекции (легаси `GenreShare`): жанр + его доля среди
/// тегированных треков (0..1). Сырьё спектра вкуса (soundprint).
class GenreShare {
  final String genre;
  final double share;

  const GenreShare({required this.genre, required this.share});
}

/// Доминирующие жанры с долей (легаси `topGenres` → `GenreShare[]`): доля =
/// частота жанра среди треков, у которых жанр задан. По убыванию, первые [n].
List<GenreShare> genreShares(Iterable<String?> trackGenres, int n) {
  final counts = <String, int>{};
  var withGenre = 0;
  for (final raw in trackGenres) {
    final g = raw?.trim();
    if (g == null || g.isEmpty) continue;
    counts[g] = (counts[g] ?? 0) + 1;
    withGenre++;
  }
  if (withGenre == 0) return const [];
  final sorted = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return [
    for (final e in sorted.take(n))
      GenreShare(genre: e.key, share: e.value / withGenre),
  ];
}
