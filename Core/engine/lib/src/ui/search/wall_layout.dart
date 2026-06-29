import 'package:flutter/rendering.dart';

/// Раскладка «Стены» для [SliverGrid] — лениво строит только видимые тайлы.
///
/// Повторяет CSS `grid-auto-flow: dense` из легаси: квадратные ячейки `cellPx`,
/// геро занимает `span 2 / span 2` (4 ячейки), плотная упаковка «втискивает»
/// мелкие тайлы в дыры перед геро. Геометрия каждого индекса считается заранее
/// (геро-флаги известны до layout), поэтому [SliverGrid] может класть и строить
/// детей по одному — выпавшие из viewport не инстанцируются.
class WallSliverGridDelegate extends SliverGridDelegate {
  final int columns;
  final double cellPx;
  final double gap;

  /// `hero[i] == true` → тайл i занимает 2×2.
  final List<bool> hero;

  const WallSliverGridDelegate({
    required this.columns,
    required this.cellPx,
    required this.gap,
    required this.hero,
  });

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    return _WallGridLayout(
      columns: columns,
      stride: cellPx + gap,
      gap: gap,
      hero: hero,
    );
  }

  @override
  bool shouldRelayout(WallSliverGridDelegate old) =>
      old.columns != columns ||
      old.cellPx != cellPx ||
      old.gap != gap ||
      !identical(old.hero, hero);

  /// Полная высота плотной раскладки (для встроенной стены без своего скролла:
  /// shrink-wrap кастомного делегата не меряется в чужом сливере — задаём явно).
  static double heightFor({
    required int columns,
    required double cellPx,
    required double gap,
    required List<bool> hero,
  }) {
    final cells = _WallGridLayout._pack(columns, hero);
    return _WallGridLayout._height(cells, cellPx + gap, gap);
  }
}

/// Предрасчитанная плотная раскладка: для каждого индекса — позиция (строка,
/// колонка) и размер. `grid-auto-flow: dense`: ищем самую раннюю строку и колонку,
/// куда влезает тайл (1×1 или 2×2), не пересекая занятые ячейки.
class _WallGridLayout extends SliverGridLayout {
  final int columns;
  final double stride; // cellPx + gap
  final double gap;
  final List<_Cell> _cells;
  final double _maxOffset;

  factory _WallGridLayout({
    required int columns,
    required double stride,
    required double gap,
    required List<bool> hero,
  }) {
    final cells = _pack(columns, hero);
    return _WallGridLayout._(
      columns: columns,
      stride: stride,
      gap: gap,
      cells: cells,
      maxOffset: _height(cells, stride, gap),
    );
  }

  _WallGridLayout._({
    required this.columns,
    required this.stride,
    required this.gap,
    required List<_Cell> cells,
    required double maxOffset,
  })  : _cells = cells,
        _maxOffset = maxOffset;

  static List<_Cell> _pack(int columns, List<bool> hero) {
    final cells = <_Cell>[];
    // occupied[row] — битовая занятость колонок строки (через Set для роста).
    final occupied = <int, Set<int>>{};
    bool free(int row, int col, int span) {
      for (var r = row; r < row + span; r++) {
        final used = occupied[r];
        if (used == null) continue;
        for (var c = col; c < col + span; c++) {
          if (used.contains(c)) return false;
        }
      }
      return true;
    }

    void mark(int row, int col, int span) {
      for (var r = row; r < row + span; r++) {
        final used = occupied.putIfAbsent(r, () => <int>{});
        for (var c = col; c < col + span; c++) {
          used.add(c);
        }
      }
    }

    for (var i = 0; i < hero.length; i++) {
      final span = hero[i] ? 2 : 1;
      var placed = false;
      for (var row = 0; !placed; row++) {
        for (var col = 0; col + span <= columns; col++) {
          if (free(row, col, span)) {
            mark(row, col, span);
            cells.add(_Cell(row: row, col: col, span: span));
            placed = true;
            break;
          }
        }
      }
    }
    return cells;
  }

  static double _height(List<_Cell> cells, double stride, double gap) {
    var rows = 0;
    for (final c in cells) {
      final bottom = c.row + c.span;
      if (bottom > rows) rows = bottom;
    }
    return rows == 0 ? 0 : rows * stride - gap;
  }

  double _extent(int span) => span * stride - gap;

  @override
  SliverGridGeometry getGeometryForChildIndex(int index) {
    final c = _cells[index];
    return SliverGridGeometry(
      scrollOffset: c.row * stride,
      crossAxisOffset: c.col * stride,
      mainAxisExtent: _extent(c.span),
      crossAxisExtent: _extent(c.span),
    );
  }

  @override
  double computeMaxScrollOffset(int childCount) => _maxOffset;

  // Плотная упаковка не монотонна по строкам, поэтому окно индексов считаем
  // линейным сканом по предрасчитанным ячейкам (cap=150 → дёшево).
  @override
  int getMinChildIndexForScrollOffset(double scrollOffset) {
    final targetRow = (scrollOffset / stride).floor();
    for (var i = 0; i < _cells.length; i++) {
      if (_cells[i].row + _cells[i].span > targetRow) return i;
    }
    return _cells.isEmpty ? 0 : _cells.length - 1;
  }

  @override
  int getMaxChildIndexForScrollOffset(double scrollOffset) {
    final targetRow = (scrollOffset / stride).floor();
    var last = 0;
    for (var i = 0; i < _cells.length; i++) {
      if (_cells[i].row <= targetRow) last = i;
    }
    return last;
  }
}

class _Cell {
  final int row;
  final int col;
  final int span;
  const _Cell({required this.row, required this.col, required this.span});
}
