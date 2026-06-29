import 'package:flutter/material.dart';
import 'package:sc_visual/sc_visual.dart';

/// Лёгкая idle-пульсация opacity (`off-pulse`): затухание 1→0.35→1.
/// Гейтится на `perf.idleAnim` (в light режиме — статичная точка).
class OfflinePulse extends StatefulWidget {
  final bool active;
  final Duration period;
  final double minOpacity;
  final Widget child;

  const OfflinePulse({
    super.key,
    required this.active,
    required this.child,
    this.period = const Duration(milliseconds: 2200),
    this.minOpacity = 0.35,
  });

  @override
  State<OfflinePulse> createState() => _OfflinePulseState();
}

class _OfflinePulseState extends State<OfflinePulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.period);

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant OfflinePulse old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) _sync();
  }

  void _sync() {
    if (widget.active) {
      _c.repeat(reverse: true);
    } else {
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
    if (!widget.active || !PerfProfile.of(context).idleAnim) return widget.child;
    return FadeTransition(
      opacity: Tween(begin: 1.0, end: widget.minOpacity).animate(
        CurvedAnimation(parent: _c, curve: Curves.easeInOut),
      ),
      child: widget.child,
    );
  }
}
