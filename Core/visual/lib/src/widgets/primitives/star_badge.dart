import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../perf.dart';

enum StarBadgeSize { sm, lg }

/// Бейдж STAR-подписки (легаси `StarBadge`): фиолетовый стеклянный pill,
/// янтарная звезда + литерал «Star». Размеры sm/lg.
class StarBadge extends StatelessWidget {
  final StarBadgeSize size;

  const StarBadge({super.key, this.size = StarBadgeSize.sm});

  static const _amber = Color(0xFFFBBF24);

  @override
  Widget build(BuildContext context) {
    final lg = size == StarBadgeSize.lg;
    final blur = ScPerf.of(context) == PerfMode.light ? 0.0 : 6.0; // CSS blur(12) → sigma 6

    Widget pill = Container(
      padding: lg
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 4)
          : const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x738B5CF6), Color(0x52A855F7), Color(0x40C084FC)],
        ),
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: const Color(0x59A855F7), width: 0.5), // rgba(168,85,247,0.35)
        boxShadow: [
          const BoxShadow(color: Color(0x33FFFFFF), blurRadius: 0, offset: Offset(0, 0.5)),
          if (lg) const BoxShadow(color: Color(0x668B5CF6), blurRadius: 20),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: lg ? 12 : 10, color: _amber),
          SizedBox(width: lg ? 6 : 3),
          Text(
            'Star',
            style: TextStyle(
              color: const Color(0xF2FFFFFF),
              fontSize: lg ? 10 : 9,
              fontWeight: lg ? FontWeight.w800 : FontWeight.w700,
              letterSpacing: lg ? 1.4 : 0.8,
            ),
          ),
        ],
      ),
    );

    if (blur > 0) {
      pill = ClipRRect(
        borderRadius: BorderRadius.circular(9999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: pill,
        ),
      );
    }
    return pill;
  }
}
