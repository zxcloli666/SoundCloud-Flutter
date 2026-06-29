import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../image_proxy.dart';
import '../../perf.dart';
import '../../theme.dart';
import '../../tokens.dart';
import 'collection_art.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Данные карточки альбома (легаси `CatalogAlbum` в `discover/AlbumGridCard`).
/// `id` сидирует fallback-градиент; счётчики/длительность форматируются вызовом.
class AlbumCardData {
  final String id;
  final String title;
  final String artistName;
  final String? coverUrl;
  final String kindLabel; // album / ep / single / compilation
  final String? trackCountLabel;
  final String? durationLabel;
  final int? releaseYear;
  final bool star;

  const AlbumCardData({
    required this.id,
    required this.title,
    required this.artistName,
    required this.kindLabel,
    this.coverUrl,
    this.trackCountLabel,
    this.durationLabel,
    this.releaseYear,
    this.star = false,
  });
}

/// Карточка альбома каталога (легаси `discover/AlbumGridCard`). Стеклянный
/// `p-3 rounded-3xl` бокс, hover scale 1.03; квадратная обложка с
/// градиент-fallback (монограмма + Disc3), бейдж типа и STAR-метка (тинт ауры).
class AlbumCard extends StatefulWidget {
  final AlbumCardData data;
  final VoidCallback? onTap;

  /// Цвет STAR-метки (праймери ауры артиста); по умолчанию — акцент темы.
  final Color? accent;

  const AlbumCard({super.key, required this.data, this.onTap, this.accent});

  @override
  State<AlbumCard> createState() => _AlbumCardState();
}

class _AlbumCardState extends State<AlbumCard> {
  bool _hover = false;

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
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(aspectRatio: 1, child: _cover()),
          const SizedBox(height: 12),
          _meta(),
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

  Widget _cover() {
    final g = gradientForId(widget.data.id, 3);
    final accent = widget.accent ?? ScTheme.paletteOf(context).accent;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ScTokens.rCard),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: g,
          stops: const [0, 0.55, 1],
        ),
        boxShadow: const [BoxShadow(color: Color(0x73000000), blurRadius: 40, offset: Offset(0, 20))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ScTokens.rCard),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _artworkOrMonogram(),
            Positioned(top: 8, left: 8, child: _kindBadge()),
            if (widget.data.star) Positioned(top: 8, right: 8, child: _StarDot(accent: accent)),
          ],
        ),
      ),
    );
  }

  Widget _artworkOrMonogram() {
    final url = upscaleArtwork(widget.data.coverUrl);
    if (url != null) {
      // PERF: декодируем в размер ячейки×DPR, а не полный t300x300 ARGB —
      // карточка заполняет виртуальные гриды (см. TrackArtwork).
      final dpr = MediaQuery.devicePixelRatioOf(context);
      return AnimatedScale(
        scale: _hover ? 1.08 : 1.0,
        duration: const Duration(milliseconds: 700),
        child: LayoutBuilder(
          builder: (context, c) => Image(
            image: ScImageProxy.sized(
                url, c.maxWidth.isFinite ? (c.maxWidth * dpr).round() : null),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _monogram(),
          ),
        ),
      );
    }
    return _monogram();
  }

  Widget _monogram() => Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Text(
              monogramOf(widget.data.title),
              style: const TextStyle(
                color: Color(0xF2FFFFFF),
                fontSize: 52,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
                shadows: [Shadow(color: Color(0x8C000000), blurRadius: 24, offset: Offset(0, 8))],
              ),
            ),
          ),
          const Positioned(bottom: 8, right: 8, child: _DiscChip()),
        ],
      );

  Widget _kindBadge() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0x8C000000),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0x1FFFFFFF), width: 0.5),
        ),
        child: Text(
          widget.data.kindLabel.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFFFFFFFF),
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
          ),
        ),
      );

  Widget _meta() {
    final stats = <Widget>[
      const Icon(LucideIcons.listMusic, size: 10, color: Color(0x4DFFFFFF)),
      const SizedBox(width: 4),
      if (widget.data.trackCountLabel != null) _statText(widget.data.trackCountLabel!),
    ];
    void addDivided(String? v) {
      if (v == null || v.isEmpty) return;
      stats
        ..add(const _Dot())
        ..add(_statText(v));
    }

    addDivided(widget.data.durationLabel);
    addDivided(widget.data.releaseYear?.toString());

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.data.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _hover ? const Color(0xFFFFFFFF) : const Color(0xE6FFFFFF),
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.data.artistName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0x73FFFFFF), fontSize: 11),
          ),
          const SizedBox(height: 6),
          Row(children: stats),
        ],
      ),
    );
  }

  Widget _statText(String v) => Text(
        v,
        style: const TextStyle(color: Color(0x4DFFFFFF), fontSize: 10),
      );
}

class _Dot extends StatelessWidget {
  const _Dot();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 6),
        child: Text('·', style: TextStyle(color: Color(0x26FFFFFF), fontSize: 10)),
      );
}

class _DiscChip extends StatelessWidget {
  const _DiscChip();
  @override
  Widget build(BuildContext context) => Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0x99000000),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0x29FFFFFF), width: 0.5),
        ),
        child: const Icon(LucideIcons.disc3, size: 14, color: Color(0xB3FFFFFF)),
      );
}

/// STAR-метка на обложке: круглый бейдж с градиентом ауры + glow.
class _StarDot extends StatelessWidget {
  final Color accent;
  const _StarDot({required this.accent});

  @override
  Widget build(BuildContext context) => Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [accent.withValues(alpha: 0.6), accent.withValues(alpha: 0.15)],
          ),
          boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.6), blurRadius: 12)],
          border: Border.all(color: accent.withValues(alpha: 0.7)),
        ),
        child: const Icon(Icons.star, size: 11, color: Color(0xFFFFFFFF)),
      );
}
