import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:sc_visual/sc_visual.dart';

import 'genre_palette.dart';

/// Тонкая бегущая лента жанровых чипов над стеной — шепчет «попробуй это».
/// Отражает реальные популярные жанры стены (fallback — [genres]). Базовый
/// список повторяется так, чтобы одна копия была шире вьюпорта, затем дублируется
/// для бесшовной петли (translateX -50%). На hover — пауза; light — без анимации.
class GenreTicker extends StatefulWidget {
  final List<GenreChip> chips;
  final ValueChanged<String> onSelect;

  const GenreTicker({super.key, required this.chips, required this.onSelect});

  @override
  State<GenreTicker> createState() => _GenreTickerState();
}

class _GenreTickerState extends State<GenreTicker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _marquee = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 60),
  );
  bool _hover = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  void _sync() {
    final idle = ScPerf.of(context) != PerfMode.light;
    final active = idle && !_hover;
    if (active && !_marquee.isAnimating) {
      _marquee.repeat();
    } else if (!active && _marquee.isAnimating) {
      _marquee.stop();
    }
  }

  @override
  void dispose() {
    _marquee.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.chips.length >= 4 ? widget.chips : genres;
    final reps = (28 / base.length).ceil().clamp(2, 60);
    final wide = [for (var r = 0; r < reps; r++) ...base];
    final loop = [...wide, ...wide];

    return MouseRegion(
      onEnter: (_) {
        _hover = true;
        _sync();
      },
      onExit: (_) {
        _hover = false;
        _sync();
      },
      child: SizedBox(
        height: 28,
        child: ClipRect(
          child: ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              colors: [
                Color(0x00000000),
                Color(0xFF000000),
                Color(0xFF000000),
                Color(0x00000000),
              ],
              stops: [0, 0.05, 0.95, 1],
            ).createShader(rect),
            blendMode: BlendMode.dstIn,
            child: AnimatedBuilder(
              animation: _marquee,
              builder: (context, _) => _row(loop, _marquee.value),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(List<GenreChip> loop, double t) {
    return _MeasuredShift(
      shiftFraction: t,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < loop.length; i++) ...[
            if (i > 0) const SizedBox(width: 20),
            _chip(loop[i]),
          ],
        ],
      ),
    );
  }

  Widget _chip(GenreChip g) {
    return _GenreChipButton(chip: g, onTap: () => widget.onSelect(g.key));
  }
}

/// Сдвигает дочерний ряд влево на [shiftFraction]·(половина ширины) — петля без
/// разрыва, т.к. ряд = два одинаковых блока (translateX -50% эквивалент).
class _MeasuredShift extends SingleChildRenderObjectWidget {
  final double shiftFraction;
  const _MeasuredShift({required this.shiftFraction, required super.child});

  @override
  _RenderMeasuredShift createRenderObject(BuildContext context) =>
      _RenderMeasuredShift(shiftFraction);

  @override
  void updateRenderObject(BuildContext context, _RenderMeasuredShift obj) {
    obj.shiftFraction = shiftFraction;
  }
}

class _RenderMeasuredShift extends RenderShiftedBox {
  _RenderMeasuredShift(this._shiftFraction) : super(null);

  double _shiftFraction;
  set shiftFraction(double value) {
    if (_shiftFraction == value) return;
    _shiftFraction = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(const BoxConstraints(), parentUsesSize: true);
    size = constraints.constrain(Size(constraints.maxWidth, child.size.height));
    final dx = -(child.size.width / 2) * _shiftFraction;
    (child.parentData as BoxParentData).offset = Offset(dx, 0);
  }
}

class _GenreChipButton extends StatefulWidget {
  final GenreChip chip;
  final VoidCallback onTap;

  const _GenreChipButton({required this.chip, required this.onTap});

  @override
  State<_GenreChipButton> createState() => _GenreChipButtonState();
}

class _GenreChipButtonState extends State<_GenreChipButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: _hover ? 1.5 : 1.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: widget.chip.color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: widget.chip.color, blurRadius: 8),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              widget.chip.label,
              style: TextStyle(
                fontSize: 12,
                color: _hover ? const Color(0xE6FFFFFF) : const Color(0x73FFFFFF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
