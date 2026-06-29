import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../perf.dart';
import '../../theme.dart';
import '../../tokens.dart';

/// Эквалайзер-полоски (легаси `EqualizerBars`/`SoundprintBars`): N столбиков,
/// при [playing] и beauty/medium idle-анимируются (`riv-eq`/`sp-breathe`); в
/// покое/light — статичные. Каждый бар можно затемнить (dim) — для выбранного
/// жанра в soundprint остальные гаснут.
class ClusterBars extends StatefulWidget {
  /// Базовые высоты столбиков 0..1 (доли жанров/спектра). Длина = число баров.
  final List<double> levels;
  final bool playing;
  final double height;
  final double barWidth;
  final double gap;

  /// Индекс выделенного бара: остальные тускнеют (soundprint). null → все ярко.
  final int? selected;

  const ClusterBars({
    super.key,
    required this.levels,
    this.playing = false,
    this.height = 40,
    this.barWidth = 4,
    this.gap = 3,
    this.selected,
  });

  @override
  State<ClusterBars> createState() => _ClusterBarsState();
}

class _ClusterBarsState extends State<ClusterBars> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync(ScPerf.of(context));
  }

  @override
  void didUpdateWidget(ClusterBars old) {
    super.didUpdateWidget(old);
    _sync(ScPerf.of(context));
  }

  void _sync(PerfMode mode) {
    final animate = widget.playing && mode != PerfMode.light;
    if (animate && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!animate && _c.isAnimating) {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = ScTheme.paletteOf(context).accent;
    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < widget.levels.length; i++) ...[
                if (i > 0) SizedBox(width: widget.gap),
                _bar(i, accent),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _bar(int i, Color accent) {
    final base = widget.levels[i].clamp(0.0, 1.0);
    // Псевдо-эквалайзер: сдвиг фазы на бар, держим минимальный пол.
    final wobble = widget.playing
        ? 0.5 + 0.5 * math.sin((_c.value * 2 * math.pi) + i * 1.3)
        : 1.0;
    final level = (0.18 + base * 0.82 * wobble).clamp(0.06, 1.0);
    final dimmed = widget.selected != null && widget.selected != i;

    return AnimatedContainer(
      duration: ScTokens.dFast,
      curve: ScTokens.easeApple,
      width: widget.barWidth,
      height: widget.height * level,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.barWidth / 2),
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            accent.withValues(alpha: dimmed ? 0.18 : 0.9),
            accent.withValues(alpha: dimmed ? 0.08 : 0.4),
          ],
        ),
      ),
    );
  }
}
