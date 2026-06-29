import 'dart:math' as math;

/// Раскладка колонок сетки из легаси `VirtualGrid` (§4.4) — load-bearing.
///
/// Формула 1:1 с React-исходником (НЕ Flutter `maxCrossAxisExtent`, у него
/// другая дискретизация):
/// ```
/// safeWidth = max(width, minColumnWidth)
/// columns   = max(1, floor((safeWidth + gap) / (minColumnWidth + gap)))
/// itemWidth = (safeWidth - gap*(columns-1)) / columns
/// ```
/// Высота строки = `itemHeight`; шаг строки = `itemHeight + gap` (gap в шаге).
class GridMetrics {
  final int columns;
  final double itemWidth;
  final double itemHeight;
  final double gap;

  const GridMetrics({
    required this.columns,
    required this.itemWidth,
    required this.itemHeight,
    required this.gap,
  });

  factory GridMetrics.resolve({
    required double width,
    required double minColumnWidth,
    required double itemHeight,
    required double gap,
  }) {
    final safeWidth = math.max(width, minColumnWidth);
    final columns = math.max(
      1,
      ((safeWidth + gap) / (minColumnWidth + gap)).floor(),
    );
    final itemWidth = (safeWidth - gap * (columns - 1)) / columns;
    return GridMetrics(
      columns: columns,
      itemWidth: itemWidth,
      itemHeight: itemHeight,
      gap: gap,
    );
  }

  int rowCount(int itemCount) => (itemCount / columns).ceil();
}
