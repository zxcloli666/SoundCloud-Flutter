import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../image_proxy.dart';
import '../../perf.dart';
import '../../theme.dart';
import '../../tokens.dart';
import 'collection_art.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Стат-чип карточки артиста (иконка + значение + i18n-лейбл из вызова).
class ArtistStat {
  final IconData icon;
  final String value;
  final String label;

  const ArtistStat({required this.icon, required this.value, required this.label});
}

/// Данные карточки артиста каталога (легаси `CatalogArtist`). Тексты (lis­teners/
/// trend) форматируются вызовом; `popularity` 0..1 правит ширину бара.
class ArtistCardData {
  final String id;
  final String name;
  final String? avatarUrl;
  final String? country;
  final List<String> tags;
  final List<ArtistStat> stats;
  final double popularity; // 0..1
  final String monthlyListenersLabel;
  final String trendLabel;
  final bool verified;
  final bool star;

  /// Цвета ауры [primary, secondary, tertiary] для STAR-кольца/бара; если
  /// пусто — используется акцент темы.
  final List<Color> auraOrbs;

  const ArtistCardData({
    required this.id,
    required this.name,
    required this.stats,
    required this.monthlyListenersLabel,
    required this.trendLabel,
    this.avatarUrl,
    this.country,
    this.tags = const [],
    this.popularity = 0,
    this.verified = false,
    this.star = false,
    this.auraOrbs = const [],
  });
}

/// Карточка артиста каталога (легаси `discover/ArtistGridCard`). Стеклянный
/// `p-5 rounded-3xl` бокс, hover scale 1.03; 96px круглый аватар (STAR →
/// вращающееся conic-кольцо ауры), verified-чек, страна, теги, стат-пилюли,
/// бар популярности + слушатели/тренд.
class ArtistCard extends StatefulWidget {
  final ArtistCardData data;
  final VoidCallback? onTap;

  const ArtistCard({super.key, required this.data, this.onTap});

  @override
  State<ArtistCard> createState() => _ArtistCardState();
}

class _ArtistCardState extends State<ArtistCard> with SingleTickerProviderStateMixin {
  bool _hover = false;
  late final AnimationController _ring;

  @override
  void initState() {
    super.initState();
    // НЕ репитим безусловно: тикер гнал бы кадры 60Гц даже когда кольцо не
    // показано (не-star/light). Запускаем только когда оно реально крутится.
    _ring = AnimationController(vsync: this, duration: const Duration(seconds: 12));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final spin = widget.data.star && ScPerf.of(context) != PerfMode.light;
    if (spin && !_ring.isAnimating) {
      _ring.repeat();
    } else if (!spin && _ring.isAnimating) {
      _ring.stop();
    }
  }

  @override
  void dispose() {
    _ring.dispose();
    super.dispose();
  }

  List<Color> get _orbs {
    if (widget.data.auraOrbs.length >= 3) return widget.data.auraOrbs;
    final a = ScTheme.paletteOf(context).accent;
    return [a, a, a];
  }

  @override
  Widget build(BuildContext context) {
    final perf = ScPerf.of(context);
    final light = perf == PerfMode.light;
    final cardBlur = light ? 0.0 : (perf == PerfMode.medium ? 10.0 : 20.0);
    final radius = BorderRadius.circular(24);

    Widget body = Container(
      decoration: BoxDecoration(
        color: cardBlur > 0 ? const Color(0x08FFFFFF) : const Color(0xEB16161B),
        borderRadius: radius,
        border: Border.all(color: const Color(0x0FFFFFFF), width: 0.5),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: _avatar(perf)),
          const SizedBox(height: 12),
          _nameRow(),
          if (widget.data.country != null) ...[const SizedBox(height: 4), _country()],
          if (widget.data.tags.isNotEmpty) ...[const SizedBox(height: 12), _tags()],
          const SizedBox(height: 12),
          _statPills(),
          const SizedBox(height: 12),
          _popularityBar(),
        ],
      ),
    );

    if (cardBlur > 0) {
      body = ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: cardBlur / 2, sigmaY: cardBlur / 2),
          child: body,
        ),
      );
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hover ? 1.03 : 1.0,
          duration: ScTokens.dGlass,
          curve: ScTokens.easeLabel,
          child: body,
        ),
      ),
    );
  }

  Widget _avatar(PerfMode perf) {
    final orbs = _orbs;
    final spinning = widget.data.star && perf != PerfMode.light;
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (widget.data.star) _starRing(orbs, spinning),
          Positioned.fill(
            child: AnimatedScale(
              scale: _hover ? 1.04 : 1.0,
              duration: ScTokens.dGlass,
              child: _avatarTile(orbs),
            ),
          ),
        ],
      ),
    );
  }

  Widget _starRing(List<Color> orbs, bool spinning) {
    final ring = AnimatedBuilder(
      animation: _ring,
      builder: (_, child) => CustomPaint(
        size: const Size.square(104),
        painter: _ConicRingPainter(
          orbs: orbs,
          angle: spinning ? _ring.value * 2 * math.pi : 0,
        ),
      ),
    );
    return Positioned(
      left: -4,
      top: -4,
      child: spinning ? ring : RepaintBoundary(child: _staticRing(orbs)),
    );
  }

  Widget _staticRing(List<Color> orbs) =>
      CustomPaint(size: const Size.square(104), painter: _ConicRingPainter(orbs: orbs, angle: 0));

  Widget _avatarTile(List<Color> orbs) {
    final g = gradientForId(widget.data.id);
    final url = upscaleArtwork(widget.data.avatarUrl, size: 't200x200');
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: g,
          stops: const [0, 0.5, 1],
        ),
      ),
      child: Center(
        child: Text(
          monogramOf(widget.data.name),
          style: const TextStyle(
            color: Color(0xF2FFFFFF),
            fontSize: 32,
            fontWeight: FontWeight.w900,
            shadows: [Shadow(color: Color(0x80000000), blurRadius: 18, offset: Offset(0, 6))],
          ),
        ),
      ),
    );
    // PERF: декодируем в размер аватара×DPR, а не полный t200x200 ARGB —
    // карточка заполняет виртуальные гриды (см. TrackArtwork).
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final img = (url == null)
        ? fallback
        : LayoutBuilder(
            builder: (context, c) => Image(
              image: ScImageProxy.sized(
                  url, c.maxWidth.isFinite ? (c.maxWidth * dpr).round() : null),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallback,
            ),
          );

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: orbs[0].withValues(alpha: 0.35), blurRadius: 28, offset: const Offset(0, 12))],
        border: Border.all(color: _hover ? const Color(0x4DFFFFFF) : const Color(0x26FFFFFF)),
      ),
      child: ClipOval(
        child: Stack(
          fit: StackFit.expand,
          children: [
            img,
            if (widget.data.star)
              Positioned(bottom: -2, right: -2, child: _StarBadge(accent: orbs[0])),
          ],
        ),
      ),
    );
  }

  Widget _nameRow() => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              widget.data.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _hover ? const Color(0xFFFFFFFF) : const Color(0xF2FFFFFF),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (widget.data.verified) ...[const SizedBox(width: 6), const _VerifiedCheck()],
        ],
      );

  Widget _country() => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.globe, size: 9, color: Color(0x59FFFFFF)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              widget.data.country!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0x59FFFFFF), fontSize: 10),
            ),
          ),
        ],
      );

  Widget _tags() => Wrap(
        alignment: WrapAlignment.center,
        spacing: 4,
        runSpacing: 4,
        children: widget.data.tags.take(2).map((tag) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0x0AFFFFFF),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0x14FFFFFF), width: 0.5),
            ),
            child: Text(
              tag.toUpperCase(),
              style: const TextStyle(
                color: Color(0x8CFFFFFF),
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
              ),
            ),
          );
        }).toList(),
      );

  Widget _statPills() => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < widget.data.stats.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            _StatPill(stat: widget.data.stats[i]),
          ],
        ],
      );

  Widget _popularityBar() {
    final orbs = _orbs;
    final width = (widget.data.popularity.clamp(0.0, 1.0));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 4,
            color: const Color(0x0DFFFFFF),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: width,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: LinearGradient(colors: [orbs[0], orbs.length > 1 ? orbs[1] : orbs[0]]),
                  boxShadow: [BoxShadow(color: orbs[0].withValues(alpha: 0.5), blurRadius: 10)],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.headphones, size: 9, color: Color(0x4DFFFFFF)),
                const SizedBox(width: 4),
                Text(
                  widget.data.monthlyListenersLabel,
                  style: const TextStyle(
                    color: Color(0x59FFFFFF),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.8,
                  ),
                ),
              ],
            ),
            Text(
              widget.data.trendLabel,
              style: TextStyle(
                color: orbs[0].withValues(alpha: 0.9),
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.8,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Стат-пилюля (иконка + значение), `bg white/3 rounded-lg`.
class _StatPill extends StatelessWidget {
  final ArtistStat stat;
  const _StatPill({required this.stat});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: stat.label,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0x08FFFFFF),
            borderRadius: BorderRadius.circular(ScTokens.rButton),
            border: Border.all(color: const Color(0x0FFFFFFF), width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(stat.icon, size: 10, color: const Color(0x66FFFFFF)),
              const SizedBox(width: 4),
              Text(
                stat.value,
                style: const TextStyle(
                  color: Color(0xD9FFFFFF),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
}

/// Синяя verified-метка (Check), легаси `w-3.5 h-3.5 bg-blue-500`.
class _VerifiedCheck extends StatelessWidget {
  const _VerifiedCheck();

  @override
  Widget build(BuildContext context) => Container(
        width: 14,
        height: 14,
        decoration: const BoxDecoration(
          color: Color(0xFF3B82F6),
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Color(0x8C3B82F6), blurRadius: 8)],
        ),
        child: const Icon(LucideIcons.check, size: 8, color: Color(0xFFFFFFFF), weight: 900),
      );
}

/// STAR-бейдж на аватаре артиста (нижний правый угол).
class _StarBadge extends StatelessWidget {
  final Color accent;
  const _StarBadge({required this.accent});

  @override
  Widget build(BuildContext context) => Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [accent.withValues(alpha: 0.65), accent.withValues(alpha: 0.15)],
          ),
          boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.6), blurRadius: 12)],
          border: Border.all(color: accent.withValues(alpha: 0.7)),
        ),
        child: const Icon(Icons.star, size: 11, color: Color(0xFFFFFFFF)),
      );
}

/// Conic-кольцо ауры (STAR). Рисуем тонкое кольцо по краю круга — цвет вращается,
/// сам круг нет (легаси GLASS_UI_GUIDE §5.11: крутим ЦВЕТ через mask).
class _ConicRingPainter extends CustomPainter {
  final List<Color> orbs;
  final double angle;

  _ConicRingPainter({required this.orbs, required this.angle});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final ringWidth = 3.0;
    final radius = size.width / 2 - ringWidth / 2;

    final sweep = SweepGradient(
      transform: GradientRotation(angle),
      colors: [orbs[0], orbs[1], orbs[2], orbs[0]],
    );
    final paint = Paint()
      ..shader = sweep.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.5);
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_ConicRingPainter old) => old.angle != angle || old.orbs != orbs;
}
