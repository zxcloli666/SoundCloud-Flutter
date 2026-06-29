import 'package:flutter/material.dart';
import 'package:sc_visual/sc_visual.dart';

/// Главная акцентная CTA входа (легаси `PrimaryButton`): `h-12 rounded-2xl`,
/// градиент accent→accent-hover, тройная тень-свечение, hover `scale 1.02`,
/// active `scale 0.97`, проходящий блик (`auth-shine 4.5s`, idle-only).
class AuthPrimaryButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;

  const AuthPrimaryButton({super.key, required this.onPressed, required this.child});

  @override
  State<AuthPrimaryButton> createState() => _AuthPrimaryButtonState();
}

class _AuthPrimaryButtonState extends State<AuthPrimaryButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shine;
  bool _hover = false;
  bool _down = false;

  @override
  void initState() {
    super.initState();
    _shine = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    )..repeat();
  }

  @override
  void dispose() {
    _shine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ScTheme.paletteOf(context);
    final idle = PerfProfile.of(context).idleAnim;
    final scale = _down ? 0.97 : (_hover ? 1.02 : 1.0);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: scale,
          duration: ScTokens.dFast,
          curve: ScTokens.easeApple,
          child: SizedBox(
            height: 48,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [palette.accent, palette.accentHover],
                  ),
                  border: const Border(top: BorderSide(color: Color(0x47FFFFFF), width: 1)),
                  boxShadow: [
                    BoxShadow(color: palette.accentGlow, blurRadius: 40, offset: const Offset(0, 14)),
                    BoxShadow(color: palette.accentGlow, blurRadius: 30),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (idle)
                      Positioned.fill(
                        child: AnimatedBuilder(
                          animation: _shine,
                          builder: (context, _) => CustomPaint(painter: _ShinePainter(_shine.value)),
                        ),
                      ),
                    DefaultTextStyle.merge(
                      style: TextStyle(
                        color: palette.accentContrast,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      child: IconTheme.merge(
                        data: IconThemeData(color: palette.accentContrast, size: 16),
                        child: widget.child,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Блик: наклонная светлая полоса шириной 1/3, скользящая `-130%→240%`.
class _ShinePainter extends CustomPainter {
  final double t;
  const _ShinePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final bandW = size.width / 3;
    // 0..0.6 — проход, 0.6..1 — пауза за правым краем.
    final progress = (t / 0.6).clamp(0.0, 1.0);
    final x = -bandW * 1.3 + (size.width * 2.4 + bandW * 1.3) * progress;
    canvas.save();
    canvas.translate(x, 0);
    canvas.transform(Matrix4.skewX(-0.32).storage);
    final rect = Rect.fromLTWH(-bandW * 0.3, -size.height, bandW, size.height * 3);
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0x00FFFFFF), Color(0x59FFFFFF), Color(0x00FFFFFF)],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ShinePainter old) => old.t != t;
}
