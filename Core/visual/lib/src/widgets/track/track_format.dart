/// Форматтеры легаси (`lib/formatters.ts`), нужные трек-компонентам.
/// Чистые функции, без локали (как в легаси).
library;

/// `floor(s/60):SS` — длительность из миллисекунд. 185000 → `3:05`.
String formatDuration(int ms) {
  final totalSeconds = ms ~/ 1000;
  final m = totalSeconds ~/ 60;
  final s = totalSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// `H:MM:SS` если есть часы, иначе `M:SS`. 3723000 → `1:02:03`.
String formatDurationLong(int ms) {
  final totalSeconds = ms ~/ 1000;
  final h = totalSeconds ~/ 3600;
  final m = (totalSeconds % 3600) ~/ 60;
  final s = totalSeconds % 60;
  final ss = s.toString().padLeft(2, '0');
  if (h <= 0) return '$m:$ss';
  return '$h:${m.toString().padLeft(2, '0')}:$ss';
}

/// Компактный счётчик: ≥1e6 → `1.2M`, ≥1e3 → `1.2K`, иначе число.
String formatCount(int n) {
  if (n <= 0) return '0';
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return '$n';
}
