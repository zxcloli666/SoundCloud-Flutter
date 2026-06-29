/// Хелперы обложек для карточек коллекций. Артворк-апскейл и детерминированный
/// fallback-градиент 1:1 с легаси (`lib/formatters.art`, `discover/visuals`).
library;

import 'package:flutter/widgets.dart';

/// Легаси `art(url, size)`: меняет ПЕРВОЕ вхождение литерала `-large` на
/// `-{size}`. Никаких других вариантов (см. §5.2 — именно single-substring).
String? upscaleArtwork(String? url, {String size = 't300x300'}) {
  if (url == null || url.isEmpty) return null;
  final i = url.indexOf('-large');
  if (i < 0) return url;
  return url.replaceFirst('-large', '-$size');
}

/// Палитра fallback-градиентов (discover/visuals `PALETTES`, 10 троек).
const _palettes = <List<Color>>[
  [Color(0xFF7C3AED), Color(0xFF06B6D4), Color(0xFFEC4899)],
  [Color(0xFFFF5500), Color(0xFFFF0080), Color(0xFFFF8A00)],
  [Color(0xFF06B6D4), Color(0xFF3B82F6), Color(0xFF10B981)],
  [Color(0xFF3F3F46), Color(0xFF52525B), Color(0xFF71717A)],
  [Color(0xFFF97316), Color(0xFFFB7185), Color(0xFFA855F7)],
  [Color(0xFF10B981), Color(0xFF84CC16), Color(0xFF065F46)],
  [Color(0xFF0EA5E9), Color(0xFF06B6D4), Color(0xFF1E3A8A)],
  [Color(0xFFA855F7), Color(0xFFD946EF), Color(0xFFF472B6)],
  [Color(0xFFFACC15), Color(0xFFF97316), Color(0xFFDC2626)],
  [Color(0xFF22D3EE), Color(0xFFA78BFA), Color(0xFFF0ABFC)],
];

/// FNV-1a 32-bit (unsigned) — тот же хеш, что в `discover/visuals.hashString`.
int fnv1a(String s) {
  var h = 2166136261;
  for (final code in s.codeUnits) {
    h ^= code;
    h = (h * 16777619) & 0xFFFFFFFF;
  }
  return h;
}

/// `gradientForId(id, offset)` = PALETTES[(hash(id)+offset) % 10].
List<Color> gradientForId(String id, [int offset = 0]) =>
    _palettes[(fnv1a(id) + offset) % _palettes.length];

/// Монограмма (первые буквы ≤2 слов), легаси `monogramOf`.
String monogramOf(String s) {
  final trimmed = s.trim();
  if (trimmed.isEmpty) return '?';
  final parts = trimmed.split(RegExp(r'\s+')).take(2);
  return parts.map((p) => p.isEmpty ? '' : p[0].toUpperCase()).join();
}
