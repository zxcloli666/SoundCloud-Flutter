import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sc_visual/sc_visual.dart';

import 'album_aura.dart';

/// Обложка-артефакт альбома (легаси `AlbumCoverArtifact`). 180→220px, скруг
/// `2.2rem`, ховер `scale(1.06)` 1000ms. Звёздный альбом получает вращающийся
/// конический ринг (цвет крутится, квадрат — нет) + аура-тень; обычный —
/// глубокую тень. Плейсхолдер — `Disc3 72`.
class AlbumCoverArtifact extends StatefulWidget {
  final String title;
  final String? coverUrl;
  final bool hasStar;
  final AlbumAura aura;

  const AlbumCoverArtifact({
    super.key,
    required this.title,
    required this.coverUrl,
    required this.hasStar,
    required this.aura,
  });

  @override
  State<AlbumCoverArtifact> createState() => _AlbumCoverArtifactState();
}

class _AlbumCoverArtifactState extends State<AlbumCoverArtifact>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ring = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  );
  bool _hover = false;

  @override
  void initState() {
    super.initState();
    if (widget.hasStar) _ring.repeat();
  }

  @override
  void dispose() {
    _ring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final idle = PerfProfile.of(context).idleAnim;
    final size = MediaQuery.sizeOf(context).width >= 768 ? 220.0 : 180.0;

    final tile = MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedScale(
        scale: _hover ? 1.06 : 1.0,
        duration: const Duration(milliseconds: 1000),
        curve: ScTokens.easeApple,
        child: _Sleeve(
          size: size,
          title: widget.title,
          coverUrl: widget.coverUrl,
          hasStar: widget.hasStar,
          aura: widget.aura,
        ),
      ),
    );

    if (!widget.hasStar) return SizedBox(width: size, height: size, child: tile);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _ring,
              builder: (context, _) => CustomPaint(
                painter: _RingPainter(
                  aura: widget.aura,
                  turns: idle ? _ring.value : 0,
                ),
              ),
            ),
          ),
          tile,
        ],
      ),
    );
  }
}

class _Sleeve extends StatelessWidget {
  final double size;
  final String title;
  final String? coverUrl;
  final bool hasStar;
  final AlbumAura aura;

  const _Sleeve({
    required this.size,
    required this.title,
    required this.coverUrl,
    required this.hasStar,
    required this.aura,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(35.2); // 2.2rem
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: hasStar
            ? [BoxShadow(color: aura.rgba(0.4), blurRadius: 80, offset: const Offset(0, 35))]
            : const [BoxShadow(color: Color(0x8C000000), blurRadius: 60, offset: Offset(0, 25))],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (coverUrl != null && coverUrl!.isNotEmpty)
              TrackArtwork(url: coverUrl, size: ArtSize.hero)
            else
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: hasStar
                      ? RadialGradient(
                          center: const Alignment(-0.4, -0.6),
                          radius: 1.0,
                          colors: [aura.rgba(0.35), const Color(0x00000000)],
                        )
                      : null,
                  color: hasStar ? null : const Color(0x08FFFFFF),
                ),
                child: const Center(child: Icon(LucideIcons.disc3, size: 72, color: Color(0x26FFFFFF))),
              ),
            // Верхний specular-блик (легаси overlay-градиент).
            const Align(
              alignment: Alignment.topCenter,
              child: FractionallySizedBox(
                heightFactor: 0.5,
                widthFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x1AFFFFFF), Color(0x00FFFFFF)],
                    ),
                  ),
                ),
              ),
            ),
            // Внутренняя обводка.
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(color: const Color(0x14FFFFFF)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Вращающийся конический ринг (3px) для звёздного альбома.
class _RingPainter extends CustomPainter {
  final AlbumAura aura;
  final double turns;

  _RingPainter({required this.aura, required this.turns});

  @override
  void paint(Canvas canvas, Size size) {
    const inset = -5.0;
    const stroke = 3.0;
    final rect = Rect.fromLTWH(inset, inset, size.width - inset * 2, size.height - inset * 2);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(38.4));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..shader = SweepGradient(
        transform: GradientRotation(turns * 2 * math.pi),
        colors: [aura.orbs[0], aura.orbs[1], aura.orbs[2], aura.orbs[0]],
      ).createShader(rect);
    canvas.drawRRect(rrect.deflate(stroke / 2), paint);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.turns != turns || old.aura != aura;
}
