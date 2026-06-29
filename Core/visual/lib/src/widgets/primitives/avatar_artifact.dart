import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../image_proxy.dart';
import '../../perf.dart';
import 'star_badge.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Аватар-артефакт героев (User/Artist): квадратная плитка `rounded-[2rem]`
/// с обложкой `t500x500`. При [hasStar] оборачивается крутящимся
/// conic-кольцом из [auraOrbs] (легаси `ring-rotate` 12s) с glow по ауре.
///
/// [auraOrbs] — 3 hex-цвета ауры (orbs[0..2]); используются для кольца и glow.
/// Размер квадрата [size] (легаси 148 mobile / 180 desktop).
class AvatarArtifact extends StatefulWidget {
  final String username;
  final String? avatarUrl;
  final bool hasStar;
  final List<Color> auraOrbs;
  final double size;

  const AvatarArtifact({
    super.key,
    required this.username,
    required this.avatarUrl,
    required this.hasStar,
    required this.auraOrbs,
    this.size = 180,
  });

  @override
  State<AvatarArtifact> createState() => _AvatarArtifactState();
}

class _AvatarArtifactState extends State<AvatarArtifact>
    with SingleTickerProviderStateMixin {
  bool _hover = false;
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  );

  @override
  Widget build(BuildContext context) {
    final perf = ScPerf.of(context);
    final idle = perf != PerfMode.light;
    _syncSpin(idle && widget.hasStar);

    final orb0 = widget.auraOrbs.isNotEmpty ? widget.auraOrbs.first : const Color(0xFF7C3AED);

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (widget.hasStar) _ring(perf, orb0),
            _tile(orb0),
            if (widget.hasStar)
              const Positioned(bottom: 8, right: 8, child: StarBadge(size: StarBadgeSize.lg)),
          ],
        ),
      ),
    );
  }

  /// Кольцо: 3px рамка из вращающегося conic-градиента ауры, glow только в beauty.
  Widget _ring(PerfMode perf, Color orb0) {
    return Positioned(
      left: -5,
      top: -5,
      right: -5,
      bottom: -5,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: perf == PerfMode.beauty
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(35.2), // rounded-[2.2rem]
                  boxShadow: [BoxShadow(color: orb0.withValues(alpha: 0.67), blurRadius: 14)],
                )
              : const BoxDecoration(),
          child: AnimatedBuilder(
            animation: _spin,
            builder: (_, __) => CustomPaint(
              painter: _RingPainter(
                orbs: _orbs(),
                turns: _spin.value,
                radius: 35.2,
                stroke: 3,
              ),
              size: Size.infinite,
            ),
          ),
        ),
      ),
    );
  }

  Widget _tile(Color orb0) {
    final radius = BorderRadius.circular(32); // rounded-[2rem]
    final hasImage = widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x08FFFFFF), // white/3
        borderRadius: radius,
        border: Border.all(color: const Color(0x1AFFFFFF), width: 0.5),
        boxShadow: widget.hasStar
            ? [BoxShadow(color: orb0.withValues(alpha: 0.25), blurRadius: 60, offset: const Offset(0, 30))]
            : const [BoxShadow(color: Color(0x66000000), blurRadius: 40, offset: Offset(0, 20))],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: hasImage
            ? AnimatedScale(
                scale: _hover ? 1.06 : 1.0,
                duration: const Duration(milliseconds: 1000),
                child: Image(
                  image: ScImageProxy.provider(_upscaled(widget.avatarUrl!)),
                  fit: BoxFit.cover,
                  width: widget.size,
                  height: widget.size,
                  errorBuilder: (_, __, ___) => _placeholder(),
                ),
              )
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() => const Center(
        child: Icon(LucideIcons.users, size: 56, color: Color(0x26FFFFFF)),
      );

  List<Color> _orbs() {
    final o = widget.auraOrbs;
    if (o.length >= 3) return [o[0], o[1], o[2], o[0]];
    final base = o.isNotEmpty ? o.first : const Color(0xFF7C3AED);
    return [base, base, base, base];
  }

  void _syncSpin(bool run) {
    if (run && !_spin.isAnimating) {
      _spin.repeat();
    } else if (!run && _spin.isAnimating) {
      _spin.stop();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }
}

/// Рисует кольцо ширины [stroke] заливкой вращающимся sweep-градиентом ауры.
/// Поворачивается через цвет (а не геометрию квадрата) — как mask-трюк в легаси.
class _RingPainter extends CustomPainter {
  final List<Color> orbs;
  final double turns;
  final double radius;
  final double stroke;

  _RingPainter({
    required this.orbs,
    required this.turns,
    required this.radius,
    required this.stroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(stroke / 2),
      Radius.circular(radius),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..shader = SweepGradient(
        transform: GradientRotation(turns * 2 * math.pi),
        colors: orbs,
      ).createShader(rect);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.turns != turns || old.orbs != orbs || old.stroke != stroke;
}

String _upscaled(String url) => url.replaceFirst('-large', '-t500x500');
