import 'package:flutter/material.dart';
import 'package:sc_visual/sc_visual.dart';

/// Лента конвейера: 16 повёрнутых на 45° шевронов, бегущих слева направо
/// (`off-belt`, 21px шаг, 1.4с). Активна — только когда конвейер работает.
class ForgeBelt extends StatefulWidget {
  final bool active;
  final bool warm;

  const ForgeBelt({super.key, required this.active, required this.warm});

  @override
  State<ForgeBelt> createState() => _ForgeBeltState();
}

class _ForgeBeltState extends State<ForgeBelt>
    with SingleTickerProviderStateMixin {
  static const _step = 21.0;
  static const _gap = 14.0;
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant ForgeBelt old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) _sync();
  }

  void _sync() {
    if (widget.active && PerfProfile.of(context).idleAnim) {
      _c.repeat();
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
    final color = widget.warm && widget.active
        ? ScTheme.paletteOf(context).accentHover
        : const Color(0x4DFFFFFF);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: ClipRect(
        child: ShaderMask(
          shaderCallback: (rect) => const LinearGradient(
            colors: [
              Color(0x00000000),
              Color(0xFF000000),
              Color(0xFF000000),
              Color(0x00000000),
            ],
            stops: [0.0, 0.18, 0.82, 1.0],
          ).createShader(rect),
          blendMode: BlendMode.dstIn,
          child: SizedBox(
            height: 10,
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                return Transform.translate(
                  offset: Offset(-42 + _c.value * _step, 0),
                  child: Row(
                    children: [
                      for (var i = 0; i < 16; i++) ...[
                        Opacity(
                          opacity: widget.active ? 1 : 0.45,
                          child: Transform.rotate(
                            angle: 0.7853981633974483,
                            child: Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                border: Border(
                                  right: BorderSide(color: color, width: 1.5),
                                  top: BorderSide(color: color, width: 1.5),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: _gap),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
