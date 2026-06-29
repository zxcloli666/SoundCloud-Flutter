import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/widgets.dart';

import 'grid_metrics.dart';

/// Виртуализированная сетка с точной раскладкой колонок из легаси (§4.4).
/// Колонки считаем сами через [GridMetrics] (формула отличается от
/// `maxCrossAxisExtent`), затем строим `SliverGrid` с фиксированным числом колонок.
///
/// Каноничная форма — [VirtualGrid.sliver] внутри страничного `CustomScrollView`.
/// Самоскроллящийся вариант — для изолированных сеток.
class VirtualGrid<T> extends StatelessWidget {
  final List<T> items;

  /// Высота ячейки (без gap). Шаг строки = itemHeight + gap.
  final double itemHeight;

  /// Целевая минимальная ширина колонки; колонок столько, сколько влезает.
  final double minColumnWidth;

  final double gap;

  /// Запас строк за viewport (легаси overscan=4) — cacheExtent в строках для
  /// самоскроллящегося варианта.
  final int overscan;

  final Key? Function(T item, int index)? getItemKey;

  /// false → отдаёт обычную сетку без виртуализации (легаси `disabled`).
  final bool disabled;

  final Widget Function(BuildContext context, T item, int index) renderItem;

  final EdgeInsets padding;

  const VirtualGrid({
    super.key,
    required this.items,
    required this.itemHeight,
    required this.minColumnWidth,
    required this.renderItem,
    this.gap = 16,
    this.overscan = 4,
    this.getItemKey,
    this.disabled = false,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = GridMetrics.resolve(
          width: constraints.maxWidth - padding.horizontal,
          minColumnWidth: minColumnWidth,
          itemHeight: itemHeight,
          gap: gap,
        );
        return GridView.builder(
          padding: padding,
          physics: disabled ? const NeverScrollableScrollPhysics() : null,
          shrinkWrap: disabled,
          scrollCacheExtent:
              ScrollCacheExtent.pixels((itemHeight + gap) * overscan),
          gridDelegate: _delegate(metrics),
          itemCount: items.length,
          itemBuilder: (context, i) => _cell(context, i),
        );
      },
    );
  }

  /// Каноничная форма: измеряет ширину через [SliverLayoutBuilder] и отдаёт
  /// `SliverGrid` с числом колонок по [GridMetrics].
  Widget sliver() {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final metrics = GridMetrics.resolve(
          width: constraints.crossAxisExtent - padding.horizontal,
          minColumnWidth: minColumnWidth,
          itemHeight: itemHeight,
          gap: gap,
        );
        return SliverPadding(
          padding: padding,
          sliver: SliverGrid(
            gridDelegate: _delegate(metrics),
            delegate: SliverChildBuilderDelegate(
              (context, i) => _cell(context, i),
              childCount: items.length,
              findChildIndexCallback: getItemKey == null ? null : _findIndex,
            ),
          ),
        );
      },
    );
  }

  SliverGridDelegate _delegate(GridMetrics metrics) =>
      SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: metrics.columns,
        mainAxisSpacing: gap,
        crossAxisSpacing: gap,
        mainAxisExtent: itemHeight,
      );

  Widget _cell(BuildContext context, int i) => KeyedSubtree(
        key: getItemKey?.call(items[i], i),
        child: renderItem(context, items[i], i),
      );

  int? _findIndex(Key key) {
    for (var i = 0; i < items.length; i++) {
      if (getItemKey!.call(items[i], i) == key) return i;
    }
    return null;
  }
}
