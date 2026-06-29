import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../palette.dart';
import '../perf.dart';
import '../theme.dart';
import '../tokens.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Маленькая круглая кнопка NowBar (`w-[30px] h-[30px]` round). Иконка тускнеет
/// в покое и светлеет на hover; `active` подсвечивает акцентом + лёгким фоном.
class NowBarIconButton extends StatefulWidget {
  final IconData icon;
  final double size;
  final double iconSize;
  final bool active;
  final Color? activeColor;
  final VoidCallback? onTap;
  final String? tooltip;

  /// Бейдж-точка в правом-верхнем углу (AB awaiting-B пульсирует).
  final bool showDot;
  final bool dotPulse;

  const NowBarIconButton({
    super.key,
    required this.icon,
    this.size = 30,
    this.iconSize = 16,
    this.active = false,
    this.activeColor,
    this.onTap,
    this.tooltip,
    this.showDot = false,
    this.dotPulse = false,
  });

  @override
  State<NowBarIconButton> createState() => _NowBarIconButtonState();
}

class _NowBarIconButtonState extends State<NowBarIconButton>
    with SingleTickerProviderStateMixin {
  bool _hover = false;
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  void _syncPulse() {
    final idle = ScPerf.of(context) != PerfMode.light;
    if (widget.showDot && widget.dotPulse && idle) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncPulse();
    });
    final palette = ScTheme.paletteOf(context);
    final accent = widget.activeColor ?? palette.accent;
    final disabled = widget.onTap == null;
    final color = widget.active
        ? accent
        : disabled
            ? const Color(0x40FFFFFF)
            : (_hover ? const Color(0xE6FFFFFF) : const Color(0x4DFFFFFF));

    Widget core = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.active
            ? accent.withValues(alpha: 0.15)
            : (_hover && !disabled ? const Color(0x14FFFFFF) : null),
      ),
      child: Icon(widget.icon, size: widget.iconSize, color: color),
    );

    if (widget.showDot) {
      core = Stack(
        clipBehavior: Clip.none,
        children: [
          core,
          Positioned(
            top: 2,
            right: 2,
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, child) => Opacity(
                opacity: widget.dotPulse ? 0.4 + 0.6 * _pulse.value : 1,
                child: child,
              ),
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(shape: BoxShape.circle, color: accent),
              ),
            ),
          ),
        ],
      );
    }

    final button = MouseRegion(
      cursor: disabled ? MouseCursor.defer : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(onTap: widget.onTap, child: core),
    );
    return widget.tooltip == null ? button : _Hint(message: widget.tooltip!, child: button);
  }
}

class _Hint extends StatelessWidget {
  final String message;
  final Widget child;

  const _Hint({required this.message, required this.child});

  @override
  Widget build(BuildContext context) =>
      Tooltip(message: message, waitDuration: const Duration(milliseconds: 500), child: child);
}

/// Hero play-orb 48×48 (`.npb-play`): радиальный акцент-градиент, двойное свечение,
/// inset-ring, hover-lift и пульсирующее кольцо `::after` при воспроизведении.
class NowBarPlayOrb extends StatefulWidget {
  final bool playing;
  final VoidCallback? onTap;

  const NowBarPlayOrb({super.key, required this.playing, this.onTap});

  @override
  State<NowBarPlayOrb> createState() => _NowBarPlayOrbState();
}

class _NowBarPlayOrbState extends State<NowBarPlayOrb>
    with SingleTickerProviderStateMixin {
  bool _hover = false;
  bool _down = false;
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  );

  void _syncPulse() {
    final idle = ScPerf.of(context) != PerfMode.light;
    if (widget.playing && idle) {
      if (!_pulse.isAnimating) _pulse.repeat();
    } else {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncPulse();
    });
    final palette = ScTheme.paletteOf(context);
    final scale = _down ? 0.95 : (_hover ? 1.06 : 1.0);
    final dy = _hover && !_down ? -1.0 : 0.0;
    final showPulse = widget.playing && ScPerf.of(context) != PerfMode.light;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _down = true),
          onTapUp: (_) => setState(() => _down = false),
          onTapCancel: () => setState(() => _down = false),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: ScTokens.easeApple,
            transform: Matrix4.translationValues(0, dy, 0)
              ..scaleByDouble(scale, scale, scale, 1.0),
            transformAlignment: Alignment.center,
            width: 48,
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (showPulse)
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (context, _) => _pulseRing(palette),
                  ),
                _orb(palette),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pulseRing(ScPalette palette) {
    final p = _pulse.value;
    final eased = 0.5 - 0.5 * math.cos(p * 2 * math.pi);
    return IgnorePointer(
      child: Container(
        width: 48 + 10 * eased,
        height: 48 + 10 * eased,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: palette.accent.withValues(alpha: 0.6 * (1 - eased)), width: 1.5),
        ),
      ),
    );
  }

  Widget _orb(ScPalette palette) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: palette.playGradient,
        border: Border.all(color: const Color(0x42FFFFFF)), // inset ring white .26
        boxShadow: [
          BoxShadow(color: palette.accentGlow, blurRadius: 20, spreadRadius: -5, offset: const Offset(0, 8)),
          BoxShadow(color: palette.accentGlow, blurRadius: 30, spreadRadius: -6),
        ],
      ),
      child: Icon(
        widget.playing ? LucideIcons.pause : LucideIcons.play,
        color: const Color(0xFF000000),
        size: 22,
      ),
    );
  }
}
