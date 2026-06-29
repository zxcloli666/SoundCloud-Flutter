import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';

import '../palette.dart';
import '../theme.dart';

/// Прогресс-полоса NowBar (`.npb-lane`): времена (current/duration, tabular) +
/// дорожка с акцентным заполнением, hover-утолщением, бегунком и AB-полосой.
///
/// Позиция приходит либо живым [positionListenable] (тикает ~10Hz — перерисовка
/// только заполнения/бегунка/времени, а не всей пилюли), либо статичным снимком
/// [positionSecs] для встраиваний без тикера.
class NowBarLane extends StatefulWidget {
  final double positionSecs;
  final ValueListenable<double>? positionListenable;
  final double durationSecs;
  final double? abLoopA;
  final double? abLoopB;
  final ValueChanged<double>? onSeek;

  const NowBarLane({
    super.key,
    required this.positionSecs,
    this.positionListenable,
    required this.durationSecs,
    this.abLoopA,
    this.abLoopB,
    this.onSeek,
  });

  @override
  State<NowBarLane> createState() => _NowBarLaneState();
}

class _NowBarLaneState extends State<NowBarLane> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final palette = ScTheme.paletteOf(context);
    final dur = widget.durationSecs;

    // crossAxis stretch — дорожка/времена тянутся на ширину дока (её диктует
    // верхний ряд через IntrinsicWidth), без LayoutBuilder (он ломает IntrinsicWidth).
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _seekAt(context, d.localPosition.dx),
            onHorizontalDragUpdate: (d) => _seekAt(context, d.localPosition.dx),
            child: SizedBox(
              height: 8,
              child: _live((pos) => _track(palette, _progress(pos, dur), pos)),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _live((pos) => Text(_fmt(pos), style: _timeStyle(const Color(0xE6FFFFFF), FontWeight.w700))),
              Text(_fmt(dur), style: _timeStyle(const Color(0x6BFFFFFF), FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  /// Перерисовывает только позиционно-зависимый кусок на каждый тик; без
  /// тикера — один статичный снимок [positionSecs].
  Widget _live(Widget Function(double pos) build) {
    final listenable = widget.positionListenable;
    if (listenable == null) return build(widget.positionSecs);
    return ValueListenableBuilder<double>(
      valueListenable: listenable,
      builder: (_, pos, __) => build(pos),
    );
  }

  double _progress(double pos, double dur) => dur > 0 ? (pos / dur).clamp(0.0, 1.0) : 0.0;

  /// Дорожка во всю ширину (8px-полоса, бар высотой h по центру). Заполнение/AB/
  /// бегунок — по долям (FractionallySizedBox/Align), без абсолютной ширины, чтобы
  /// дорожка не диктовала ширину дока (её задаёт верхний ряд через IntrinsicWidth).
  Widget _track(ScPalette palette, double progress, double positionSecs) {
    final h = _hover ? 5.0 : 3.0;
    final top = (8 - h) / 2;
    final dur = widget.durationSecs;
    final a = widget.abLoopA;
    final fill = progress.clamp(0.0, 1.0);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: top,
          height: h,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _hover ? const Color(0x14FFFFFF) : const Color(0x0FFFFFFF),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
        if (a != null && dur > 0)
          _abBand(palette, top, h, a / dur, (widget.abLoopB ?? positionSecs).clamp(0, dur) / dur),
        Positioned(
          left: 0,
          right: 0,
          top: top,
          height: h,
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: fill,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: palette.accent,
                borderRadius: BorderRadius.circular(3),
                boxShadow: [BoxShadow(color: palette.accentGlow, blurRadius: 6)],
              ),
            ),
          ),
        ),
        if (_hover)
          Positioned.fill(
            child: Align(
              alignment: Alignment(fill * 2 - 1, 0),
              child: _thumb(palette),
            ),
          ),
      ],
    );
  }

  /// AB-полоса [lo,hi] по долям: внешний бокс ширины hi, внутри — правый кусок
  /// (hi-lo)/hi → итог диапазон [lo,hi]. Без абсолютной ширины.
  Widget _abBand(ScPalette palette, double top, double h, double from, double to) {
    final lo = from.clamp(0.0, 1.0);
    final hi = to.clamp(0.0, 1.0);
    if (hi <= lo) return const SizedBox.shrink();
    return Positioned(
      left: 0,
      right: 0,
      top: top,
      height: h,
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: hi,
        child: Align(
          alignment: Alignment.centerRight,
          child: FractionallySizedBox(
            widthFactor: (hi - lo) / hi,
            child: ColoredBox(color: palette.accent.withValues(alpha: 0.25)),
          ),
        ),
      ),
    );
  }

  Widget _thumb(ScPalette palette) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: palette.accent,
        boxShadow: [BoxShadow(color: palette.accentGlow, blurRadius: 8)],
      ),
    );
  }

  void _seekAt(BuildContext context, double dx) {
    final dur = widget.durationSecs;
    final width = context.size?.width ?? 0;
    if (widget.onSeek == null || dur <= 0 || width <= 0) return;
    widget.onSeek!((dx / width).clamp(0.0, 1.0) * dur);
  }
}

TextStyle _timeStyle(Color color, FontWeight weight) => TextStyle(
      color: color,
      fontSize: 9.5,
      fontWeight: weight,
      letterSpacing: 0.19,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

String _fmt(double secs) {
  final s = secs.isFinite && secs > 0 ? secs.floor() : 0;
  final m = s ~/ 60;
  final rest = (s % 60).toString().padLeft(2, '0');
  return '$m:$rest';
}
