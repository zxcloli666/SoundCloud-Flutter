import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../providers.dart';

/// Геро-панель Discover (легаси §3.3 `DiscoverHero`): стеклянный hub-rise бокс с
/// вращающимся компасом-артефактом, призматичным заголовком «Каталог», мета-пилюлями
/// (артисты·альбомы·свежак), кнопкой «Удиви меня» и стат-орбами (xl+).
class DiscoverHero extends ConsumerWidget {
  final int? artistsCount;
  final int? albumsCount;
  final int? freshCount;
  final bool isLoading;
  final bool isSurprising;
  final VoidCallback onSurpriseMe;

  const DiscoverHero({
    super.key,
    required this.artistsCount,
    required this.albumsCount,
    required this.freshCount,
    required this.isLoading,
    required this.isSurprising,
    required this.onSurpriseMe,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perf = PerfProfile.of(context);
    final accent = ScTheme.paletteOf(context).accent;
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 1024; // lg: горизонтальная раскладка
    final showStats = width >= 1280; // xl: стат-орбы справа

    final body = wide
        ? IntrinsicHeight(
            // Равновысокие колонки. Без IntrinsicHeight `stretch` в безграничной
            // высоте сливера растягивает детей в бесконечность и гасит вьюпорт.
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CompassArtifact(accent: accent, spinning: perf.idleAnim),
                const SizedBox(width: 48),
                Expanded(child: _textColumn(ref, accent, true)),
                if (showStats) ...[
                  const SizedBox(width: 48),
                  _statColumn(ref, accent),
                ],
              ],
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              _CompassArtifact(accent: accent, spinning: perf.idleAnim),
              const SizedBox(height: 32),
              _textColumn(ref, accent, false),
            ],
          );

    return _HeroShell(
      child: Padding(
        padding: EdgeInsets.all(wide ? 48 : 24),
        child: body,
      ),
    );
  }

  Widget _textColumn(WidgetRef ref, Color accent, bool wide) {
    final align = wide ? CrossAxisAlignment.start : CrossAxisAlignment.center;
    final width = MediaQuery.sizeOf(ref.context).width;
    final titleSize = width >= 1024 ? 88.0 : (width >= 768 ? 72.0 : 48.0);
    return Column(
      crossAxisAlignment: align,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      mainAxisSize: MainAxisSize.min,
      children: [
        ShaderMask(
          shaderCallback: (rect) => LinearGradient(
            colors: [accent, accent.withValues(alpha: 0.7), const Color(0xFFFFFFFF)],
          ).createShader(rect),
          child: Text(
            ref.tr('discover.title'),
            textAlign: wide ? TextAlign.left : TextAlign.center,
            style: TextStyle(
              color: const Color(0xFFFFFFFF),
              fontSize: titleSize,
              height: 0.85,
              fontWeight: FontWeight.w900,
              letterSpacing: -titleSize * 0.045,
            ),
          ),
        ),
        const SizedBox(height: 24),
        _metaPills(ref, accent, wide),
        const SizedBox(height: 20),
        _SurpriseButton(
          accent: accent,
          busy: isSurprising,
          onTap: onSurpriseMe,
          label: ref.tr('discover.surpriseMe'),
        ),
      ],
    );
  }

  Widget _metaPills(WidgetRef ref, Color accent, bool wide) {
    return Wrap(
      alignment: wide ? WrapAlignment.start : WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 6,
      children: [
        _MetaPill(
          icon: LucideIcons.mic,
          color: const Color(0x73FFFFFF),
          text: artistsCount == null
              ? ref.tr('common.loading')
              : ref.tr('discover.metaArtists', {'count': artistsCount}),
          loading: isLoading && artistsCount == null,
        ),
        const Text('·', style: TextStyle(color: Color(0x26FFFFFF))),
        _MetaPill(
          icon: LucideIcons.disc3,
          color: const Color(0x73FFFFFF),
          text: albumsCount == null
              ? ref.tr('common.loading')
              : ref.tr('discover.metaAlbums', {'count': albumsCount}),
          loading: isLoading && albumsCount == null,
        ),
        const Text('·', style: TextStyle(color: Color(0x26FFFFFF))),
        _MetaPill(
          icon: LucideIcons.sparkles,
          color: accent.withValues(alpha: 0.85),
          text: freshCount == null
              ? ref.tr('common.loading')
              : ref.tr('discover.metaFresh', {'count': freshCount}),
          loading: isLoading && freshCount == null,
          highlight: true,
        ),
      ],
    );
  }

  Widget _statColumn(WidgetRef ref, Color accent) {
    return SizedBox(
      width: 200,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatOrb(
            icon: LucideIcons.mic,
            value: artistsCount,
            label: ref.tr('discover.statArtists'),
            accent: accent,
            loading: isLoading && artistsCount == null,
          ),
          const SizedBox(height: 12),
          _StatOrb(
            icon: LucideIcons.disc3,
            value: albumsCount,
            label: ref.tr('discover.statAlbums'),
            accent: accent,
            loading: isLoading && albumsCount == null,
          ),
          const SizedBox(height: 12),
          _StatOrb(
            icon: LucideIcons.sparkles,
            value: freshCount,
            label: ref.tr('discover.statFresh'),
            accent: accent,
            highlight: true,
            loading: isLoading && freshCount == null,
          ),
        ],
      ),
    );
  }
}

/// Стеклянная hub-rise оболочка геро (легаси `GlassHeroPanel`, hasStar=false):
/// frosted backdrop-blur(40) + subtle white-градиент, specular-хайлайт по кромке,
/// чёрная тень (без aura-glow — он только у star).
class _HeroShell extends StatelessWidget {
  final Widget child;

  const _HeroShell({required this.child});

  @override
  Widget build(BuildContext context) {
    final perf = PerfProfile.of(context);
    final blur = perf.blur(40);
    final radius = BorderRadius.circular(ScTokens.rHero); // rounded-[2.5rem]

    Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: blur > 0
            ? const LinearGradient(
                begin: Alignment(-0.6, -1),
                end: Alignment(0.6, 1),
                colors: [Color(0x0FFFFFFF), Color(0x05FFFFFF), Color(0x0AFFFFFF)],
                stops: [0, 0.5, 1],
              )
            : null,
        color: blur > 0 ? null : const Color(0xD1141418),
        border: Border.all(color: const Color(0x14FFFFFF), width: 0.5),
      ),
      child: Stack(
        children: [
          const Positioned(top: 0, left: 24, right: 24, child: SpecularHairline()),
          child,
        ],
      ),
    );

    if (blur > 0) {
      surface = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: surface,
      );
    }

    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(ScTokens.rHero)),
        boxShadow: [
          BoxShadow(
              color: Color(0x59000000), blurRadius: 80, offset: Offset(0, 30)),
        ],
      ),
      child: ClipRRect(borderRadius: radius, child: surface),
    );
  }
}

/// Компас-артефакт (легаси §3.3): conic-кольцо `ring-rotate 14s` + Compass 96
/// (`ring-rotate 30s`), радиальная подложка ауры.
class _CompassArtifact extends StatefulWidget {
  final Color accent;
  final bool spinning;

  const _CompassArtifact({required this.accent, required this.spinning});

  @override
  State<_CompassArtifact> createState() => _CompassArtifactState();
}

class _CompassArtifactState extends State<_CompassArtifact>
    with TickerProviderStateMixin {
  late final AnimationController _ring =
      AnimationController(vsync: this, duration: const Duration(seconds: 14));
  late final AnimationController _needle =
      AnimationController(vsync: this, duration: const Duration(seconds: 30));

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_CompassArtifact old) {
    super.didUpdateWidget(old);
    if (old.spinning != widget.spinning) _sync();
  }

  void _sync() {
    if (widget.spinning) {
      if (!_ring.isAnimating) _ring.repeat();
      if (!_needle.isAnimating) _needle.repeat();
    } else {
      _ring.stop();
      _needle.stop();
    }
  }

  @override
  void dispose() {
    _ring.dispose();
    _needle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    final wide = MediaQuery.sizeOf(context).width >= 768;
    final side = wide ? 220.0 : 180.0;
    return SizedBox(
      width: side,
      height: side,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _ring,
            builder: (_, __) => CustomPaint(
              size: Size.square(side),
              painter: _ConicRingPainter(
                accent: accent,
                angle: _ring.value * 2 * math.pi,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(35.2),
              gradient: RadialGradient(
                center: const Alignment(-0.4, -0.6),
                radius: 1.2,
                colors: [
                  accent.withValues(alpha: 0.38),
                  const Color(0xFF141418).withValues(alpha: 0.4),
                  const Color(0xFF0A0A0C).withValues(alpha: 0.7),
                ],
                stops: const [0, 0.6, 1],
              ),
              boxShadow: [
                BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 70, offset: const Offset(0, 30)),
              ],
              border: Border.all(color: const Color(0x1AFFFFFF)),
            ),
            margin: const EdgeInsets.all(5),
            child: Center(
              child: RotationTransition(
                turns: _needle,
                child: Icon(LucideIcons.compass, size: 96, color: accent.withValues(alpha: 0.95)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConicRingPainter extends CustomPainter {
  final Color accent;
  final double angle;

  _ConicRingPainter({required this.accent, required this.angle});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final sweep = SweepGradient(
      transform: GradientRotation(angle),
      colors: [
        accent,
        accent.withValues(alpha: 0.5),
        const Color(0xFFFFFFFF).withValues(alpha: 0.4),
        accent,
      ],
    );
    final paint = Paint()
      ..shader = sweep.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(2), const Radius.circular(36)),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ConicRingPainter old) => old.angle != angle || old.accent != accent;
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  final bool loading;
  final bool highlight;

  const _MetaPill({
    required this.icon,
    required this.color,
    required this.text,
    required this.loading,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return const Skeleton(width: 64, height: 12, rounded: SkeletonRound.full);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: highlight ? const Color(0xB3FFFFFF) : const Color(0x8CFFFFFF),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.4,
          ),
        ),
      ],
    );
  }
}

class _StatOrb extends StatelessWidget {
  final IconData icon;
  final int? value;
  final String label;
  final Color accent;
  final bool highlight;
  final bool loading;

  const _StatOrb({
    required this.icon,
    required this.value,
    required this.label,
    required this.accent,
    this.highlight = false,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ScTokens.rCard),
        gradient: highlight
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [accent.withValues(alpha: 0.16), const Color(0x05FFFFFF)],
              )
            : null,
        color: highlight ? null : const Color(0x08FFFFFF),
        border: Border.all(color: const Color(0x14FFFFFF), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: highlight ? 0.28 : 0.14),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 12, color: const Color(0x8CFFFFFF)),
          const SizedBox(width: 10),
          if (loading || value == null)
            const Skeleton(width: 56, height: 20, rounded: SkeletonRound.sm)
          else
            Text(
              formatCount(value!),
              style: const TextStyle(
                color: Color(0xFFFFFFFF),
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
          const SizedBox(width: 10),
          Text(
            label,
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
  }
}

/// «Удиви меня» — белая градиент-пилюля с шиммер-проходом и hover scale 1.04.
class _SurpriseButton extends StatefulWidget {
  final Color accent;
  final bool busy;
  final VoidCallback onTap;
  final String label;

  const _SurpriseButton({
    required this.accent,
    required this.busy,
    required this.onTap,
    required this.label,
  });

  @override
  State<_SurpriseButton> createState() => _SurpriseButtonState();
}

class _SurpriseButtonState extends State<_SurpriseButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.busy ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.busy ? null : widget.onTap,
        child: AnimatedScale(
          scale: _hover && !widget.busy ? 1.04 : 1.0,
          duration: ScTokens.dGlass,
          curve: ScTokens.easeLabel,
          child: Opacity(
            opacity: widget.busy ? 0.6 : 1,
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 28),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9999),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFFFFF), Color(0xFFE5E7EB)],
                ),
                border: Border.all(color: const Color(0x66FFFFFF), width: 0.5),
                boxShadow: [
                  BoxShadow(color: widget.accent.withValues(alpha: 0.35), blurRadius: 32, offset: const Offset(0, 12)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.sparkles, size: 14, color: Color(0xFF000000)),
                  const SizedBox(width: 8),
                  Text(
                    widget.label,
                    style: const TextStyle(
                      color: Color(0xFF000000),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
