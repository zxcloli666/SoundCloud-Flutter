import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:sc_visual/sc_visual.dart';

import 'user_aura.dart';

/// Премиум-герой профиля (легаси `GlassHeroPanel`): `rounded-[2.5rem]`,
/// universal-panel-стекло (§1.6), specular-хайрлайн сверху; при [hasStar] —
/// аура-гало и аура-рамка вместо нейтральной тени. Появляется hub-rise'ом.
class UserHeroPanel extends StatefulWidget {
  final UserAura aura;
  final bool hasStar;
  final Widget child;

  const UserHeroPanel({
    super.key,
    required this.aura,
    required this.hasStar,
    required this.child,
  });

  @override
  State<UserHeroPanel> createState() => _UserHeroPanelState();
}

class _UserHeroPanelState extends State<UserHeroPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rise = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  @override
  void dispose() {
    _rise.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final perf = ScPerf.of(context);
    final blur = PerfProfile(perf).sigma(40);
    final radius = BorderRadius.circular(40);
    final orb0 = widget.aura.orbs.first;

    Widget panel = DecoratedBox(
      decoration: BoxDecoration(
        gradient: blur > 0
            ? const LinearGradient(
                begin: Alignment(-0.4, -1),
                end: Alignment(0.4, 1),
                colors: [Color(0x0FFFFFFF), Color(0x05FFFFFF), Color(0x0AFFFFFF)],
                stops: [0.0, 0.5, 1.0],
              )
            : null,
        color: blur > 0 ? null : const Color(0xD114141A), // rgba(20,20,24,0.82)
        borderRadius: radius,
        border: Border.all(color: const Color(0x14FFFFFF), width: 0.5),
        boxShadow: [
          const BoxShadow(color: Color(0x59000000), blurRadius: 80, offset: Offset(0, 30)),
          if (widget.hasStar && perf == PerfMode.beauty)
            BoxShadow(color: orb0.withValues(alpha: 0.22), blurRadius: 90, spreadRadius: -10),
        ],
      ),
      child: Stack(
        children: [
          widget.child,
          const Positioned(top: 0, left: 24, right: 24, child: SpecularHairline()),
        ],
      ),
    );

    if (blur > 0) {
      panel = ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: panel,
        ),
      );
    } else {
      panel = ClipRRect(borderRadius: radius, child: panel);
    }

    return AnimatedBuilder(
      animation: _rise,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(_rise.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, 24 * (1 - t)), child: child),
        );
      },
      child: panel,
    );
  }
}
