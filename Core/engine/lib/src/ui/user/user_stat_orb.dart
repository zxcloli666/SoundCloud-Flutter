import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:sc_visual/sc_visual.dart';

/// Орб-статистика (легаси `StatOrb`): стеклянная пилюля с крупным числом и
/// uppercase-лейблом, hover scale 1.04, аура-тень снизу. Число форматируется
/// `fc()`; null → «—».
class UserStatOrb extends StatefulWidget {
  final int? value;
  final String label;

  /// Цвет тени (аура с разной альфой per-orb).
  final Color accent;

  const UserStatOrb({
    super.key,
    required this.value,
    required this.label,
    required this.accent,
  });

  @override
  State<UserStatOrb> createState() => _UserStatOrbState();
}

class _UserStatOrbState extends State<UserStatOrb> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final blur = PerfProfile.of(context).sigma(24);
    Widget body = Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: blur > 0 ? const Color(0x0AFFFFFF) : const Color(0xD91C1C20),
        borderRadius: BorderRadius.circular(ScTokens.rCard),
        border: Border.all(color: const Color(0x14FFFFFF), width: 0.5),
        boxShadow: [BoxShadow(color: widget.accent, blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            widget.value != null ? formatCount(widget.value!) : '—',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            widget.label.toUpperCase(),
            style: const TextStyle(
              color: Color(0x66FFFFFF),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.2,
            ),
          ),
        ],
      ),
    );

    if (blur > 0) {
      body = ClipRRect(
        borderRadius: BorderRadius.circular(ScTokens.rCard),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: body,
        ),
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedScale(
        scale: _hover ? 1.04 : 1.0,
        duration: ScTokens.dGlass,
        curve: ScTokens.easeApple,
        child: body,
      ),
    );
  }
}
