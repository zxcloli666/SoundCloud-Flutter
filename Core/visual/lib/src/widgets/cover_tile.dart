import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../ambient_clock.dart';
import '../perf.dart';
import '../theme.dart';
import '../tokens.dart';
import 'track/preview_ring.dart';
import 'track/track_art.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Вариант тайла стены (легаси): обычный / vibe (AI) / lyric (цитата).
enum CoverTileVariant { normal, vibe, lyric }

class CoverTileData {
  final String urn; // сид для breathing-анимации (детерминизм)
  final String title;
  final String artist;
  final String? artworkUrl;
  final bool playing;

  /// Для lyric-варианта — строка-цитата вместо обычного оверлея.
  final String? lyricLine;

  const CoverTileData({
    required this.urn,
    required this.title,
    required this.artist,
    this.artworkUrl,
    this.playing = false,
    this.lyricLine,
  });
}

/// Квадратный тайл стены поиска/Discover (легаси `CoverTile`).
/// Покой: idle-breathing (scale/opacity, сид от urn, gate idleAnim).
/// Hover: лифт (translateY -4, scale 1.05), рост тени, zoom обложки 1.08,
/// нижний градиент с названием/артистом, play-кнопка top-right.
/// Now-playing: акцентное кольцо `inset 2px + glow`. Preview: sweep-кольцо.
/// Hero+onDive: pill «нырнуть» bottom-right.
class CoverTile extends StatefulWidget {
  final CoverTileData data;
  final bool hero;
  final CoverTileVariant variant;
  final VoidCallback? onTap;
  final VoidCallback? onDive;

  /// Наведение/уход (для hover-превью аудио). Дебаунс/окно — у вызывающего.
  final VoidCallback? onHoverStart;
  final VoidCallback? onHoverEnd;

  /// Прогресс превью 0..1 при наведении; не `null` рисует [PreviewRing] (только
  /// кольцо перерисовывается на тик, не вся плитка).
  final ValueListenable<double>? previewProgress;

  const CoverTile({
    super.key,
    required this.data,
    this.hero = false,
    this.variant = CoverTileVariant.normal,
    this.onTap,
    this.onDive,
    this.onHoverStart,
    this.onHoverEnd,
    this.previewProgress,
  });

  @override
  State<CoverTile> createState() => _CoverTileState();
}

class _CoverTileState extends State<CoverTile> {
  bool _hover = false;
  bool _subscribed = false;
  late final double _durSec;
  late final double _phaseSec;

  // FNV-1a 32-bit (§6) — сид breathing из urn.
  int get _hash {
    var h = 0x811c9dc5;
    for (final c in widget.data.urn.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h;
  }

  @override
  void initState() {
    super.initState();
    // Период 7..10.4с, стартовый сдвиг 0..9с (детерминизм по urn) — как в легаси.
    _durSec = (7000 + (_hash % 35) * 100) / 1000.0;
    _phaseSec = (_hash % 90) / 10.0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncBreathe();
  }

  // Дыхание гоним общими амбиент-часами (один 20fps-таймер на всё), а не
  // пер-виджетным 165Гц-AnimationController — иначе каждая обложка держит сцену
  // в рендере на 165fps. Подписываемся только когда реально дышим (idle, не hover).
  void _syncBreathe() {
    final active = ScPerf.of(context) != PerfMode.light && !_hover;
    if (active && !_subscribed) {
      _subscribed = true;
      AmbientClock.instance.subscribe();
    } else if (!active && _subscribed) {
      _subscribed = false;
      AmbientClock.instance.unsubscribe();
    }
  }

  @override
  void dispose() {
    if (_subscribed) AmbientClock.instance.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hero = widget.hero;
    final radius = BorderRadius.circular(ScTokens.rCard);
    final rest = widget.variant == CoverTileVariant.vibe ? 1.02 : 1.0;
    final hoverScale = widget.variant == CoverTileVariant.vibe ? 1.06 : 1.05;

    // RepaintBoundary кэширует растр тайла: анимация (transform/opacity)
    // композитит готовый слой на GPU, НЕ ре-растеризуя обложку и не пробивая
    // репейнт в страницу.
    final inner = RepaintBoundary(child: _tile(hero, radius));
    final idleBreath = ScPerf.of(context) != PerfMode.light && !_hover;

    // Дыхание в покое — ТОЛЬКО transform (composite-only поверх кэша): Opacity
    // убран, т.к. он делает saveLayer и ре-растеризует обложку каждый кадр.
    // Scale через RepaintBoundary'd слой композитится на GPU без работы растра.
    final Widget base = idleBreath
        ? AnimatedBuilder(
            animation: AmbientClock.instance.tick,
            builder: (context, child) {
              final breath = 0.5 +
                  0.5 *
                      math.sin((AmbientClock.instance.seconds + _phaseSec) *
                          2 *
                          math.pi /
                          _durSec);
              return Transform.scale(
                scale: 0.972 + 0.028 * breath,
                alignment: Alignment.center,
                child: child,
              );
            },
            child: inner,
          )
        : inner;

    // Лифт на hover — плавный (легаси `.tg-lift transition 500ms`): translateY
    // и scale едут, а не снап. Composite-only поверх `base` (RepaintBoundary'd).
    final animated = TweenAnimationBuilder<double>(
      tween: Tween(end: _hover ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 500),
      curve: ScTokens.easeLabel,
      builder: (context, t, child) {
        final scale = rest + (hoverScale - rest) * t;
        return Transform.translate(
          offset: Offset(0, -4.0 * t),
          child:
              Transform.scale(scale: scale, alignment: Alignment.center, child: child),
        );
      },
      child: base,
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() => _hover = true);
        _syncBreathe();
        widget.onHoverStart?.call();
      },
      onExit: (_) {
        setState(() => _hover = false);
        _syncBreathe();
        widget.onHoverEnd?.call();
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: animated,
      ),
    );
  }

  Widget _tile(bool hero, BorderRadius radius) {
    final accent = ScTheme.paletteOf(context).accent;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: _hover ? const Color(0x8C000000) : const Color(0x73000000),
            blurRadius: _hover ? 70 : 32,
            offset: Offset(0, _hover ? 28 : 14),
          ),
          if (widget.variant == CoverTileVariant.vibe)
            BoxShadow(color: accent.withValues(alpha: 0.25), blurRadius: 30),
        ],
      ),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          ClipRRect(
            borderRadius: radius,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _cover(hero),
                if (widget.variant == CoverTileVariant.lyric) ...[
                  _lyricQuote(hero),
                  _topHoverOverlay(hero),
                ] else
                  _bottomOverlay(hero),
                Positioned(top: 8, right: 8, child: _playButton(hero)),
                if (widget.variant == CoverTileVariant.vibe)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Icon(
                      LucideIcons.sparkles,
                      size: hero ? 16 : 12,
                      // Легаси: accent/70 в покое → accent на hover.
                      color: accent.withValues(alpha: _hover ? 1.0 : 0.7),
                    ),
                  ),
                if (hero && widget.onDive != null)
                  Positioned(bottom: 8, right: 8, child: _diveButton()),
              ],
            ),
          ),
          if (widget.data.playing) _nowPlayingRing(radius, accent),
          if (widget.previewProgress != null)
            Positioned.fill(
              child: ValueListenableBuilder<double>(
                valueListenable: widget.previewProgress!,
                builder: (_, p, __) => PreviewRing(progress: p),
              ),
            ),
        ],
      ),
    );
  }

  Widget _cover(bool hero) {
    return AnimatedScale(
      scale: _hover ? 1.08 : 1.0,
      duration: const Duration(milliseconds: 700),
      curve: ScTokens.easeLabel,
      child: TrackArtwork(
        url: widget.data.artworkUrl,
        size: hero ? ArtSize.hero : ArtSize.card,
      ),
    );
  }

  /// Карточка лирики (легаси pull-quote): обложка видна, совпавшая строка —
  /// цитатой по нижнему градиенту (акцентный левый бордер, serif-курсив), всегда.
  Widget _lyricQuote(bool hero) {
    final accent = ScTheme.paletteOf(context).accent;
    return Align(
      alignment: Alignment.bottomLeft,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Color(0xD1000000), Color(0x00000000)],
            stops: [0, 0.85],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 32, 12, 12),
          child: Container(
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: accent, width: 2)),
            ),
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              widget.data.lyricLine ?? widget.data.title,
              maxLines: hero ? 4 : 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: const Color(0xF2FFFFFF),
                fontSize: hero ? 17 : 12,
                fontStyle: FontStyle.italic,
                fontFamily: 'serif',
                height: 1.32,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Верхний оверлей на ховере (для lyric-карточки): название трека + артист,
  /// чтобы за цитатой не терялось, что это за трек.
  Widget _topHoverOverlay(bool hero) {
    return AnimatedOpacity(
      opacity: _hover ? 1 : 0,
      duration: ScTokens.dGlass,
      curve: ScTokens.easeLabel,
      child: Align(
        alignment: Alignment.topLeft,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xC7000000), Color(0x00000000)],
              stops: [0, 0.9],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 36, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.data.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFFFFFFFF),
                    fontSize: hero ? 15 : 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  widget.data.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottomOverlay(bool hero) {
    return AnimatedOpacity(
      opacity: _hover ? 1 : 0,
      duration: ScTokens.dGlass,
      curve: ScTokens.easeLabel,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Color(0xC7000000), Color(0x00000000)],
            stops: [0, 0.55],
          ),
        ),
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.data.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFFFFFFFF),
                    fontSize: hero ? 16 : 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  widget.data.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0x8CFFFFFF), fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _playButton(bool hero) {
    final size = hero ? 40.0 : 30.0;
    // Легаси: тёмная полупрозрачная кнопка с белой иконкой (НЕ белый круг),
    // фейд по opacity 300ms без scale; playing — видна всегда.
    return AnimatedOpacity(
      opacity: (_hover || widget.data.playing) ? 1 : 0,
      duration: const Duration(milliseconds: 300),
      curve: ScTokens.easeApple,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0x9E000000), // rgba(0,0,0,0.62)
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0x2EFFFFFF), width: 0.5), // white/0.18
        ),
        child: Icon(
          widget.data.playing ? LucideIcons.pause : LucideIcons.play,
          size: hero ? 18 : 14,
          color: const Color(0xFFFFFFFF),
        ),
      ),
    );
  }

  Widget _diveButton() {
    final accent = ScTheme.paletteOf(context).accent;
    return AnimatedOpacity(
      opacity: _hover ? 1 : 0,
      duration: ScTokens.dFast,
      child: GestureDetector(
        onTap: widget.onDive,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.compass, size: 13, color: Color(0xFFFFFFFF)),
              SizedBox(width: 4),
              Text('Dive', style: TextStyle(color: Color(0xFFFFFFFF), fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _nowPlayingRing(BorderRadius radius, Color accent) {
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: accent, width: 2),
            boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.20), blurRadius: 24)],
          ),
        ),
      ),
    );
  }
}
