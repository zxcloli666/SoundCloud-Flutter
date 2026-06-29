import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/widgets.dart';

/// Виртуализированный список фиксированной высоты строки (легаси `VirtualList`,
/// §4.4). Легаси скроллит страничный `<main>`, а не себя — каноничная форма тут
/// [VirtualList.sliver], которую кладут внутрь страничного `CustomScrollView`.
///
/// Отдельный самоскроллящийся вариант — для изолированных списков, где нет общего
/// страничного скролла; он повторяет `itemExtent: rowHeight` +
/// `cacheExtent: rowHeight*overscan` из легаси.
class VirtualList<T> extends StatelessWidget {
  final List<T> items;
  final double rowHeight;
  final Widget Function(BuildContext context, T item, int index) renderItem;

  /// Запас строк за viewport (легаси overscan=6). Здесь это cacheExtent в строках.
  final int overscan;

  /// Стабильный ключ строки (для сохранения состояния при reorder/обновлении).
  final Key? Function(T item, int index)? getItemKey;

  /// Если true — отдаёт плоскую колонку без виртуализации (легаси `disabled`).
  final bool disabled;

  final EdgeInsets padding;

  const VirtualList({
    super.key,
    required this.items,
    required this.rowHeight,
    required this.renderItem,
    this.overscan = 6,
    this.getItemKey,
    this.disabled = false,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    if (disabled) {
      return Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < items.length; i++)
              SizedBox(
                height: rowHeight,
                child: KeyedSubtree(
                  key: getItemKey?.call(items[i], i),
                  child: renderItem(context, items[i], i),
                ),
              ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: padding,
      itemCount: items.length,
      itemExtent: rowHeight,
      scrollCacheExtent: ScrollCacheExtent.pixels(rowHeight * overscan),
      itemBuilder: (context, i) => KeyedSubtree(
        key: getItemKey?.call(items[i], i),
        child: renderItem(context, items[i], i),
      ),
    );
  }

  /// Каноничная форма: sliver для страничного `CustomScrollView` (страница =
  /// единственный скролл-контейнер). overscan здесь не применяется — cacheExtent
  /// задаёт сам страничный скролл.
  Widget sliver(BuildContext context) {
    return SliverFixedExtentList(
      itemExtent: rowHeight,
      delegate: SliverChildBuilderDelegate(
        (context, i) => KeyedSubtree(
          key: getItemKey?.call(items[i], i),
          child: renderItem(context, items[i], i),
        ),
        childCount: items.length,
        findChildIndexCallback: getItemKey == null
            ? null
            : (key) {
                for (var i = 0; i < items.length; i++) {
                  if (getItemKey!.call(items[i], i) == key) return i;
                }
                return null;
              },
      ),
    );
  }
}
