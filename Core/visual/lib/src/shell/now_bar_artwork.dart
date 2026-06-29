import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../image_proxy.dart';
import '../palette.dart';
import '../perf.dart';
import '../theme.dart';
import '../tokens.dart';

/// Обложка 48×48 в NowBar (`.npb-art`) с playing-cues:
///   • `.npb-ring` — вращающийся «винил» (conic 7s linear);
///   • `.npb-eq`   — 4 пляшущих бара слева-снизу;
///   • `.npb-art-load` — вуаль с процентом, пока трек грузится.
///
/// Анимации гейтятся `idleAnim` перфа (light → статичный кадр).
class NowBarArtwork extends StatefulWidget {
  final String? artworkUrl;
  final bool playing;
  final bool loading;
  final int loadPercent;
  final VoidCallback? onTap;

  const NowBarArtwork({
    super.key,
    required this.artworkUrl,
    required this.playing,
    required this.loading,
    required this.loadPercent,
    this.onTap,
  });

  @override
  State<NowBarArtwork> createState() => _NowBarArtworkState();
}

class _NowBarArtworkState extends State<NowBarArtwork>
    with TickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  );
  late final AnimationController _eq = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  bool _hover = false;

  void _syncAnimations() {
    final idle = ScPerf.of(context) != PerfMode.light;
    if (widget.playing && idle) {
      if (!_spin.isAnimating) _spin.repeat();
      if (!_eq.isAnimating) _eq.repeat();
    } else {
      _spin.stop();
      _eq.stop();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    _eq.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncAnimations();
    });
    final palette = ScTheme.paletteOf(context);
    final idle = ScPerf.of(context) != PerfMode.light;
    final radius = BorderRadius.circular(ScTokens.rArt);
    final showRing = widget.playing && idle;

    final transform = _hover
        ? (Matrix4.identity()
          ..scaleByDouble(1.05, 1.05, 1.05, 1.0)
          ..rotateZ(-1.5 * math.pi / 180))
        : Matrix4.identity();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: ScTokens.dFast,
          curve: ScTokens.easeApple,
          transform: transform,
          transformAlignment: Alignment.center,
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: [
              const BoxShadow(
                color: Color(0xBF000000),
                blurRadius: 20,
                spreadRadius: -8,
                offset: Offset(0, 8),
              ),
              if (_hover)
                BoxShadow(color: palette.accentGlow, blurRadius: 24, spreadRadius: -4),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _cover(palette),
                if (showRing) _vinylRing(),
                if (showRing) _eqBars(),
                if (widget.loading) _loadVeil(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cover(ScPalette palette) {
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.accent, const Color(0xFF3A2BD0)],
        ),
      ),
    );
    final url = widget.artworkUrl;
    if (url == null) return fallback;
    return Image(
      image: ScImageProxy.provider(url),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => fallback,
    );
  }

  Widget _vinylRing() {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _spin,
        builder: (context, _) {
          return CustomPaint(
            painter: _VinylRingPainter(turns: _spin.value),
          );
        },
      ),
    );
  }

  Widget _eqBars() {
    // Legacy задержки на бар: −200 / −560 / −80 / −380 мс при длине 900.
    const delays = [-200.0, -560.0, -80.0, -380.0];
    return IgnorePointer(
      child: Padding(
        padding: const EdgeInsets.only(left: 6, bottom: 6),
        child: Align(
          alignment: Alignment.bottomLeft,
          child: AnimatedBuilder(
            animation: _eq,
            builder: (context, _) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final d in delays) ...[
                    _eqBar(d),
                    const SizedBox(width: 1.5),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _eqBar(double delayMs) {
    final phase = ((_eq.value + delayMs / 900) % 1 + 1) % 1;
    final scale = 0.32 + 0.68 * (0.5 - 0.5 * math.cos(phase * 2 * math.pi));
    return Container(
      width: 2,
      height: 11 * scale,
      decoration: const BoxDecoration(
        color: Color(0xFFFFFFFF),
        boxShadow: [BoxShadow(color: Color(0x66FFFFFF), blurRadius: 4)],
      ),
    );
  }

  Widget _loadVeil() {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x57080A0C), Color(0x9E080A0C)], // 0.34 → 0.62
          ),
        ),
        child: Center(
          child: Text(
            '${widget.loadPercent}%',
            style: const TextStyle(
              color: Color(0xFFFFFFFF),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}

/// Винил-кольцо: conic от 0°, прозрачно до 74%, белая дуга к 84%, к 92% гаснет;
/// маска-«пончик» (легаси `mask` radial). opacity 0.5.
class _VinylRingPainter extends CustomPainter {
  final double turns;

  const _VinylRingPainter({required this.turns});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outer = size.shortestSide / 2;
    final stroke = outer * 0.16;
    final radius = outer - stroke / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final base = turns * 2 * math.pi;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..shader = SweepGradient(
        startAngle: base,
        endAngle: base + 2 * math.pi,
        colors: const [
          Color(0x00FFFFFF),
          Color(0x00FFFFFF),
          Color(0x8CFFFFFF), // white .55
          Color(0x00FFFFFF),
          Color(0x00FFFFFF),
        ],
        stops: const [0.0, 0.74, 0.84, 0.92, 1.0],
        transform: GradientRotation(base),
      ).createShader(rect);
    canvas.saveLayer(Rect.fromCircle(center: center, radius: outer),
        Paint()..color = const Color(0x80FFFFFF));
    canvas.drawArc(rect, 0, 2 * math.pi, false, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_VinylRingPainter old) => old.turns != turns;
}
