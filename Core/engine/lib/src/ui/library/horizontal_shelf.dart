import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Горизонтальная лента карточек хаба (легаси `HorizontalScroll`): drag-to-scroll
/// мышью, скрытый скроллбар, зазор 16. Виртуализируется через `ListView.builder`
/// — рендерится только видимое плюс overscan.
class HorizontalShelf extends StatelessWidget {
  final List<Widget> children;
  final double height;

  const HorizontalShelf({super.key, required this.children, this.height = 200});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ScrollConfiguration(
        behavior: const _DragScrollBehavior(),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 8),
          itemCount: children.length,
          separatorBuilder: (_, __) => const SizedBox(width: 16),
          itemBuilder: (context, i) => children[i],
        ),
      ),
    );
  }
}

/// Тащить мышью (десктоп) + без видимого скроллбара.
class _DragScrollBehavior extends ScrollBehavior {
  const _DragScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) => child;

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) =>
      child;
}
