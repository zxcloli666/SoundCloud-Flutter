import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:sc_visual/sc_visual.dart';

/// Бейдж верификации (легаси `VerifiedBadge`): синий круг 24 с галкой.
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0x33FFFFFF), width: 2),
        boxShadow: const [BoxShadow(color: Color(0x8C3B82F6), blurRadius: 16)],
      ),
      child: const Icon(LucideIcons.check, size: 13, color: Colors.white, weight: 700),
    );
  }
}

/// Pro-чип (легаси `ProChip`): оранжевый градиент + точка + план uppercase.
class ProChip extends StatelessWidget {
  final String plan;

  const ProChip({super.key, required this.plan});

  @override
  Widget build(BuildContext context) {
    final blur = PerfProfile.of(context).sigma(12);
    return _Frosted(
      blur: blur,
      gradient: blur > 0
          ? const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0x2EFF5500), Color(0x1AFF0080)],
            )
          : const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xEB3A1C0E), Color(0xEB301020)],
            ),
      border: const Color(0x40FF5500),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFFFB923C),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Color(0xFFFF5500), blurRadius: 6)],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            plan.toUpperCase(),
            style: const TextStyle(
              color: Color(0xE6FDBA74),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
            ),
          ),
        ],
      ),
    );
  }
}

/// Инфо-чип (легаси `InfoChip`): стеклянная пилюля с иконкой + текстом uppercase.
class InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const InfoChip({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final blur = PerfProfile.of(context).sigma(12);
    return _Frosted(
      blur: blur,
      color: blur > 0 ? const Color(0x0AFFFFFF) : const Color(0xD91C1C20),
      border: const Color(0x12FFFFFF),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: const Color(0x73FFFFFF)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0x8CFFFFFF),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

/// Общая стеклянная оболочка чипа `px-2.5 py-1 rounded-full`.
class _Frosted extends StatelessWidget {
  final double blur;
  final Color? color;
  final Gradient? gradient;
  final Color border;
  final Widget child;

  const _Frosted({
    required this.blur,
    required this.border,
    required this.child,
    this.color,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        gradient: gradient,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border, width: 0.5),
      ),
      child: child,
    );
    if (blur > 0) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: content,
        ),
      );
    }
    return content;
  }
}
