import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Backdrop-blur для сливера (легаси-стекло панели каталога §3.3): размывает то,
/// что нарисовано ПОЗАДИ сливера, в пределах его видимого прямоугольника. Аналог
/// `BackdropFilter` для box-мира — у Flutter нет встроенного sliver-варианта.
///
/// [borderRadius] скругляет стеклянный край (блюр клипуется в rrect), повторяя
/// `ClipRRect`-обёртку artist/user панелей.
class SliverBackdropFilter extends SingleChildRenderObjectWidget {
  final ui.ImageFilter filter;
  final BorderRadius borderRadius;

  const SliverBackdropFilter({
    super.key,
    required this.filter,
    this.borderRadius = BorderRadius.zero,
    required Widget sliver,
  }) : super(child: sliver);

  @override
  RenderSliverBackdropFilter createRenderObject(BuildContext context) =>
      RenderSliverBackdropFilter(filter: filter, borderRadius: borderRadius);

  @override
  void updateRenderObject(
      BuildContext context, RenderSliverBackdropFilter renderObject) {
    renderObject
      ..filter = filter
      ..borderRadius = borderRadius;
  }
}

class RenderSliverBackdropFilter extends RenderProxySliver {
  RenderSliverBackdropFilter({
    required ui.ImageFilter filter,
    required BorderRadius borderRadius,
  })  : _filter = filter,
        _borderRadius = borderRadius;

  ui.ImageFilter _filter;
  ui.ImageFilter get filter => _filter;
  set filter(ui.ImageFilter value) {
    if (_filter == value) return;
    _filter = value;
    markNeedsPaint();
  }

  BorderRadius _borderRadius;
  BorderRadius get borderRadius => _borderRadius;
  set borderRadius(BorderRadius value) {
    if (_borderRadius == value) return;
    _borderRadius = value;
    markNeedsPaint();
  }

  final LayerHandle<BackdropFilterLayer> _filterLayer =
      LayerHandle<BackdropFilterLayer>();
  final LayerHandle<ClipRRectLayer> _clipLayer = LayerHandle<ClipRRectLayer>();

  @override
  bool get alwaysNeedsCompositing => child != null;

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) {
      _filterLayer.layer = null;
      _clipLayer.layer = null;
      return;
    }
    final rrect = _visibleRRect(offset);
    void paintFiltered(PaintingContext ctx, Offset o) {
      _filterLayer.layer ??= BackdropFilterLayer();
      _filterLayer.layer!.filter = _filter;
      ctx.pushLayer(_filterLayer.layer!, super.paint, o);
    }

    if (rrect == null) {
      _clipLayer.layer = null;
      paintFiltered(context, offset);
      return;
    }
    _clipLayer.layer = context.pushClipRRect(
      needsCompositing,
      offset,
      rrect.outerRect,
      rrect,
      paintFiltered,
      oldLayer: _clipLayer.layer,
    );
  }

  /// Видимый прямоугольник сливера в локальных координатах (учитывает скролл),
  /// скруглённый [borderRadius]. null — если радиус нулевой (клип не нужен).
  RRect? _visibleRRect(Offset offset) {
    if (_borderRadius == BorderRadius.zero) return null;
    final g = geometry;
    if (g == null) return null;
    final Rect rect = switch (constraints.axis) {
      Axis.vertical => Rect.fromLTWH(
          offset.dx, offset.dy, constraints.crossAxisExtent, g.paintExtent),
      Axis.horizontal => Rect.fromLTWH(
          offset.dx, offset.dy, g.paintExtent, constraints.crossAxisExtent),
    };
    return _borderRadius.toRRect(rect);
  }

  @override
  void dispose() {
    _filterLayer.layer = null;
    _clipLayer.layer = null;
    super.dispose();
  }
}
