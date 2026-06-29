import 'package:flutter/widgets.dart';

import '../../perf.dart';

/// Радиус скруглений скелетона (легаси `Skeleton.rounded`).
enum SkeletonRound { sm, md, lg, full }

/// Плейсхолдер-заглушка под загружаемый контент.
///
/// Легаси `.skeleton-shimmer` — это НЕ бегущий градиент, а пульс прозрачности
/// `skeleton-pulse` (1 ↔ 0.45, 1.6s ease-in-out). В light-перфе и при
/// reduced-motion анимация отключается (плоский tint).
class Skeleton extends StatefulWidget {
  final double? width;
  final double? height;
  final SkeletonRound rounded;

  const Skeleton({
    super.key,
    this.width,
    this.height,
    this.rounded = SkeletonRound.md,
  });

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  static const _base = Color(0x0DFFFFFF); // rgba(255,255,255,0.05)

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  late final Animation<double> _opacity = Tween(begin: 1.0, end: 0.45).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
  );

  @override
  Widget build(BuildContext context) {
    final animate = ScPerf.of(context) != PerfMode.light &&
        !MediaQuery.disableAnimationsOf(context);
    _sync(animate);

    final box = SizedBox(
      width: widget.width,
      height: widget.height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _base,
          borderRadius: _radius(widget.rounded),
        ),
      ),
    );
    if (!animate) return box;
    return FadeTransition(opacity: _opacity, child: box);
  }

  void _sync(bool animate) {
    if (animate && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!animate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

BorderRadius _radius(SkeletonRound r) => switch (r) {
      SkeletonRound.sm => BorderRadius.circular(4),
      SkeletonRound.md => BorderRadius.circular(8),
      SkeletonRound.lg => BorderRadius.circular(16),
      SkeletonRound.full => BorderRadius.circular(9999),
    };
