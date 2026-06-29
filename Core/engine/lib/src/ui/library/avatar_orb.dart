import 'package:flutter/material.dart';
import 'package:sc_visual/sc_visual.dart';

/// Аватар-орб мастхеда: круглый аватар в акцентном гало (легаси `AvatarOrb`).
/// 84/100px по ширине, акцентная рамка и мягкое свечение.
class AvatarOrb extends StatelessWidget {
  final String? avatarUrl;
  final double size;

  const AvatarOrb({super.key, required this.avatarUrl, this.size = 100});

  @override
  Widget build(BuildContext context) {
    final accent = ScTheme.paletteOf(context).accent;
    final glow = accent.withValues(alpha: 0.32);
    final beauty = ScPerf.of(context) == PerfMode.beauty;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (beauty)
            Positioned(
              left: -8,
              top: -8,
              right: -8,
              bottom: -8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [accent.withValues(alpha: 0.45), Colors.transparent],
                    stops: const [0, 0.7],
                  ),
                ),
              ),
            ),
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: accent.withValues(alpha: 0.4), width: 0.5),
              boxShadow: [
                BoxShadow(color: glow, blurRadius: 34, offset: const Offset(0, 10)),
              ],
            ),
            child: ClipOval(child: Avatar(src: avatarUrl, size: size)),
          ),
        ],
      ),
    );
  }
}
