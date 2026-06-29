import 'package:flutter/material.dart';
import 'package:sc_visual/sc_visual.dart';

/// Геро входа (легаси `BrandMark`): парящий акцентный логотип, излучающий сонар-
/// импульсы, под шиммер-вордмарком. Единственное, что запоминается с экрана входа.
///
/// Idle-анимации (float + 3 сонар-кольца) гейтятся перф-профилем: в light они
/// замирают, плитка и свечение остаются.
class BrandMark extends StatefulWidget {
  final String subtitle;

  const BrandMark({super.key, required this.subtitle});

  @override
  State<BrandMark> createState() => _BrandMarkState();
}

class _BrandMarkState extends State<BrandMark> with TickerProviderStateMixin {
  late final AnimationController _float;
  late final AnimationController _sonar;

  @override
  void initState() {
    super.initState();
    _float = AnimationController(vsync: this, duration: const Duration(seconds: 6))
      ..repeat(reverse: true);
    _sonar = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat();
  }

  @override
  void dispose() {
    _float.dispose();
    _sonar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ScTheme.paletteOf(context);
    final profile = PerfProfile.of(context);
    final idle = profile.idleAnim;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 84,
          height: 84,
          child: AnimatedBuilder(
            animation: _float,
            builder: (context, child) {
              final dy = idle ? -6.0 * (0.5 - (0.5 - _float.value).abs()) * 2 : 0.0;
              return Transform.translate(offset: Offset(0, dy), child: child);
            },
            child: _logoStack(palette, idle, profile.glow),
          ),
        ),
        const SizedBox(height: 24),
        _wordmark(palette),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 18),
          child: Text(
            widget.subtitle,
            style: const TextStyle(fontSize: 13, color: Color(0x66FFFFFF)),
          ),
        ),
      ],
    );
  }

  Widget _logoStack(ScPalette palette, bool idle, bool glow) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // Ambient glow.
        Positioned(
          left: -24,
          right: -24,
          top: -24,
          bottom: -24,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [palette.accentGlow, const Color(0x00000000)],
                stops: const [0.0, 0.7],
              ),
            ),
          ),
        ),
        // Sonar pulses — sound radiating out.
        if (idle)
          for (var i = 0; i < 3; i++)
            _SonarRing(controller: _sonar, delay: i / 3, color: palette.accent),
        // Logo tile.
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: LinearGradient(
              begin: const Alignment(-0.6, -0.8),
              end: const Alignment(0.6, 0.8),
              colors: [palette.accent, palette.accentHover],
            ),
            boxShadow: [
              BoxShadow(color: palette.accentGlow, blurRadius: 44, offset: const Offset(0, 14)),
              BoxShadow(color: palette.accentGlow, blurRadius: 30),
            ],
          ),
          child: SizedBox(
            width: 84,
            height: 84,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                border: const Border(
                  top: BorderSide(color: Color(0x52FFFFFF), width: 1),
                ),
              ),
              child: Icon(LucideIcons.audioLines, size: 36, color: palette.accentContrast),
            ),
          ),
        ),
      ],
    );
  }

  Widget _wordmark(ScPalette palette) {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white, palette.accentHover, palette.accent],
      ).createShader(bounds),
      child: const Text(
        'SoundCloud',
        style: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
          height: 1,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Одно сонар-кольцо: `scale 0.7→2.5`, `opacity 0.5→0` за 3s с фазовым сдвигом.
class _SonarRing extends StatelessWidget {
  final AnimationController controller;
  final double delay;
  final Color color;

  const _SonarRing({required this.controller, required this.delay, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = (controller.value + delay) % 1.0;
        final scale = 0.7 + t * 1.8;
        final opacity = (0.5 * (1 - t)).clamp(0.0, 0.5);
        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: color, width: 1),
              ),
            ),
          ),
        );
      },
    );
  }
}
