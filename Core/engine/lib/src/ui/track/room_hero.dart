import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../rust/api.dart';
import 'track_action_rail.dart';
import 'track_aura.dart';
import 'track_cover.dart';
import 'track_waveform.dart';

/// Hero трека — «комната». Стеклянный монолит с размытой обложкой-фоном,
/// артефактом-обложкой слева, заголовком/артистом/рельсой действий справа и
/// живой waveform внизу. Адаптив: на узком — колонка по центру, на широком —
/// ряд cover|info.
class RoomHero extends StatelessWidget {
  final TrackDto track;
  final TrackAura aura;
  final bool isCurrent;
  final bool isPlaying;
  final bool liked;
  final VoidCallback onPlay;
  final ValueChanged<bool> onToggleLike;
  final VoidCallback onLyrics;
  final VoidCallback onOpenArtist;

  const RoomHero({
    super.key,
    required this.track,
    required this.aura,
    required this.isCurrent,
    required this.isPlaying,
    required this.liked,
    required this.onPlay,
    required this.onToggleLike,
    required this.onLyrics,
    required this.onOpenArtist,
  });

  @override
  Widget build(BuildContext context) {
    final cover = artUrl(track.artworkUrl, ArtSize.hero);
    final beauty = ScPerf.of(context) == PerfMode.beauty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(ScTokens.rHero),
      child: Stack(
        children: [
          Positioned.fill(child: GlassPanel(variant: GlassVariant.featured, radius: ScTokens.rHero, padding: EdgeInsets.zero, child: const SizedBox.shrink())),
          if (cover.isNotEmpty && beauty) _CoverBackdrop(coverUrl: cover),
          Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 720;
                    final art = TrackCover(
                      coverUrl: track.artworkUrl,
                      aura: aura,
                      verified: track.uploaderVerified,
                      isPlaying: isPlaying,
                      onToggle: onPlay,
                    );
                    final info = _HeroInfo(
                      track: track,
                      aura: aura,
                      isPlaying: isPlaying,
                      liked: liked,
                      wide: wide,
                      onPlay: onPlay,
                      onToggleLike: onToggleLike,
                      onLyrics: onLyrics,
                      onOpenArtist: onOpenArtist,
                    );
                    if (wide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          art,
                          const SizedBox(width: 32),
                          Expanded(child: info),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [art, const SizedBox(height: 24), info],
                    );
                  },
                ),
                const SizedBox(height: 24),
                Container(height: 0.5, color: const Color(0x12FFFFFF)),
                const SizedBox(height: 24),
                TrackWaveform(track: track, isCurrent: isCurrent, accent: aura.accent),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverBackdrop extends StatelessWidget {
  final String coverUrl;

  const _CoverBackdrop({required this.coverUrl});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          fit: StackFit.expand,
          children: [
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 45, sigmaY: 45),
              child: Transform.scale(
                scale: 1.4,
                child: Opacity(
                  opacity: 0.20,
                  child: Image(image: ScImageProxy.provider(coverUrl), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                ),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x660A0A0C), Color(0xA80A0A0C)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroInfo extends StatelessWidget {
  final TrackDto track;
  final TrackAura aura;
  final bool isPlaying;
  final bool liked;
  final bool wide;
  final VoidCallback onPlay;
  final ValueChanged<bool> onToggleLike;
  final VoidCallback onLyrics;
  final VoidCallback onOpenArtist;

  const _HeroInfo({
    required this.track,
    required this.aura,
    required this.isPlaying,
    required this.liked,
    required this.wide,
    required this.onPlay,
    required this.onToggleLike,
    required this.onLyrics,
    required this.onOpenArtist,
  });

  @override
  Widget build(BuildContext context) {
    final align = wide ? CrossAxisAlignment.start : CrossAxisAlignment.center;
    final likeCount = track.likesCount?.toInt() ?? 0;

    return Column(
      crossAxisAlignment: align,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: wide ? WrapAlignment.start : WrapAlignment.center,
          children: [
            QualityBadge(
              meta: ScdMeta(
                storageState: track.storageState,
                storageQuality: track.storageQuality,
                indexState: track.indexState,
              ),
            ),
            if (track.genre != null && track.genre!.isNotEmpty)
              _Chip(label: track.genre!.toUpperCase(), color: aura.accent),
            if (track.releaseYear != null)
              _Chip(label: '${track.releaseYear}', color: const Color(0x66FFFFFF)),
          ],
        ),
        const SizedBox(height: 14),
        _Title(text: track.title, aura: aura, wide: wide),
        const SizedBox(height: 16),
        _ArtistLine(track: track, aura: aura, wide: wide, onOpenArtist: onOpenArtist),
        const SizedBox(height: 24),
        TrackActionRail(
          track: track,
          isPlaying: isPlaying,
          liked: liked,
          likeCount: likeCount,
          onPlay: onPlay,
          onToggleLike: onToggleLike,
          onLyrics: onLyrics,
        ),
      ],
    );
  }
}

class _Title extends StatelessWidget {
  final String text;
  final TrackAura aura;
  final bool wide;

  const _Title({required this.text, required this.aura, required this.wide});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: wide ? 56 : 36,
      height: 0.95,
      fontWeight: FontWeight.w900,
      letterSpacing: -1.5,
      color: const Color(0xF5FFFFFF),
    );
    final title = Text(
      text,
      textAlign: wide ? TextAlign.start : TextAlign.center,
      style: style,
    );
    if (!aura.hasGenre) {
      return DefaultTextStyle.merge(
        style: const TextStyle(shadows: [Shadow(color: Color(0x80000000), blurRadius: 22, offset: Offset(0, 6))]),
        child: title,
      );
    }
    // Жанровый заголовок: градиент по тексту (легаси `aura.nameGradient`).
    return ShaderMask(
      shaderCallback: (rect) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color.lerp(aura.accent, const Color(0xFFFFFFFF), 0.35)!, aura.accent],
      ).createShader(rect),
      blendMode: BlendMode.srcIn,
      child: title,
    );
  }
}

class _ArtistLine extends StatefulWidget {
  final TrackDto track;
  final TrackAura aura;
  final bool wide;
  final VoidCallback onOpenArtist;

  const _ArtistLine({
    required this.track,
    required this.aura,
    required this.wide,
    required this.onOpenArtist,
  });

  @override
  State<_ArtistLine> createState() => _ArtistLineState();
}

class _ArtistLineState extends State<_ArtistLine> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.track;
    final avatar = t.artistAvatarUrl ?? t.uploaderAvatarUrl;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onOpenArtist,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: widget.wide ? MainAxisAlignment.start : MainAxisAlignment.center,
          children: [
            Avatar(src: avatar, alt: t.artistName, size: 28),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                t.artistName,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: _hover ? const Color(0xFFFFFFFF) : const Color(0xBFFFFFFF),
                ),
              ),
            ),
            if (t.uploaderVerified) ...[
              const SizedBox(width: 8),
              const Icon(Icons.verified_rounded, size: 14, color: Color(0xCC34D399)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x0FFFFFFF),
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: const Color(0x0FFFFFFF)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.4,
          color: color,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
