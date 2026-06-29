import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../tokens.dart';
import 'like_button.dart';
import 'track_art.dart';
import 'track_format.dart';
import 'track_status_badge.dart';
import 'upload_kind_dot.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Данные квадратной карточки трека. Title/artist разрешены вызывающим (§5.1).
class TrackCardTileData {
  final String title;
  final String artistLine;
  final String? artworkUrl;
  final int durationMs;
  final int? playbackCount;
  final TrackStatusMeta? meta;
  final UploadKind? uploadKind;
  final bool liked;
  final bool wanted;

  const TrackCardTileData({
    required this.title,
    required this.artistLine,
    this.artworkUrl,
    this.durationMs = 0,
    this.playbackCount,
    this.meta,
    this.uploadKind,
    this.liked = false,
    this.wanted = false,
  });
}

/// Квадратная карточка трека (легаси `music/TrackCard`) для полок/рейлов.
/// Обложка-квадрат с ring; на hover/playing — затемнение + blur и круглая
/// play-кнопка; оверлеи: like (top-left), action-иконки (top-right), бейдж
/// состояния (bottom-left), длительность (bottom-right). Под обложкой —
/// title/artist и футер прослушиваний.
class TrackCardTile extends StatefulWidget {
  final TrackCardTileData data;
  final bool playing;
  final VoidCallback? onPlay;
  final ValueChanged<bool>? onToggleLike;
  final VoidCallback? onAddToPlaylist;
  final VoidCallback? onAddToQueue;
  final double width;

  const TrackCardTile({
    super.key,
    required this.data,
    this.playing = false,
    this.onPlay,
    this.onToggleLike,
    this.onAddToPlaylist,
    this.onAddToQueue,
    this.width = 176,
  });

  @override
  State<TrackCardTile> createState() => _TrackCardTileState();
}

class _TrackCardTileState extends State<TrackCardTile> {
  bool _hover = false;

  bool get _active => _hover || widget.playing;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.data.wanted ? MouseCursor.defer : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.data.wanted ? null : widget.onPlay,
        child: SizedBox(
          width: widget.width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(aspectRatio: 1, child: _cover()),
              const SizedBox(height: 10),
              _info(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cover() {
    final radius = BorderRadius.circular(ScTokens.rCard);
    // Кольцо обложки фейдит white/0.06→white/0.12 (легаси `ring … transition-all
    // duration-300 ease-apple`) — не снап, как было.
    return AnimatedContainer(
      duration: ScTokens.dSidebar,
      curve: ScTokens.easeApple,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: _hover ? const Color(0x1FFFFFFF) : const Color(0x0FFFFFFF),
        ),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedScale(
              scale: _hover ? 1.04 : 1.0,
              duration: ScTokens.dGlass,
              curve: ScTokens.easeApple,
              child: TrackArtwork(url: widget.data.artworkUrl, size: ArtSize.card),
            ),
            _dim(),
            // Все оверлеи примонтированы и фейдят (легаси `opacity-0 group-hover:
            // opacity-100`), а не поп-ин по условию.
            Positioned(
              top: 8,
              left: 8,
              child: _fade(_like(), visible: widget.data.liked || _hover),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: _fade(_actions(), visible: _hover, interactive: true),
            ),
            if (widget.data.meta != null)
              Positioned(bottom: 8, left: 8, child: _badge()),
            if (widget.data.durationMs > 0)
              Positioned(
                bottom: 8,
                right: 8,
                child: _fade(_durationPill(), visible: _hover),
              ),
            Center(child: _playButton()),
          ],
        ),
      ),
    );
  }

  /// Фейд оверлея (легаси `group-hover:opacity-100 duration-200`); невидимый —
  /// не перехватывает клики.
  Widget _fade(Widget child, {required bool visible, bool interactive = false}) {
    final faded = AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: ScTokens.dFast,
      curve: ScTokens.easeApple,
      child: child,
    );
    if (!interactive) return faded;
    return IgnorePointer(ignoring: !visible, child: faded);
  }

  Widget _dim() {
    return AnimatedOpacity(
      opacity: _active ? 1 : 0,
      duration: ScTokens.dSidebar,
      curve: ScTokens.easeApple,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 1, sigmaY: 1),
        child: const ColoredBox(color: Color(0x4D000000)), // black/30
      ),
    );
  }

  Widget _playButton() {
    return AnimatedScale(
      scale: _active ? 1.0 : 0.75,
      duration: ScTokens.dSidebar,
      curve: ScTokens.easeApple,
      child: AnimatedOpacity(
        opacity: _active ? 1 : 0,
        duration: ScTokens.dSidebar,
        curve: ScTokens.easeApple,
        child: Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(color: Color(0xF2FFFFFF), shape: BoxShape.circle),
          child: Icon(
            widget.playing ? LucideIcons.pause : LucideIcons.play,
            size: 22,
            color: const Color(0xFF0A0A0C),
          ),
        ),
      ),
    );
  }

  Widget _like() => LikeButton(
        liked: widget.data.liked,
        onToggle: widget.onToggleLike,
        size: 30,
        iconSize: 15,
      );

  Widget _actions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.onAddToPlaylist != null)
          _OverlayIcon(icon: LucideIcons.listPlus, onTap: widget.onAddToPlaylist),
        if (widget.onAddToQueue != null)
          _OverlayIcon(icon: LucideIcons.listMusic, onTap: widget.onAddToQueue),
      ],
    );
  }

  Widget _badge() => TrackStatusBadge(meta: widget.data.meta!, variant: BadgeVariant.overlay);

  Widget _durationPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0x80000000), // black/50
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        formatDuration(widget.data.durationMs),
        style: const TextStyle(
          color: Color(0xCCFFFFFF),
          fontSize: 10,
          fontWeight: FontWeight.w500,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  Widget _info() {
    final d = widget.data;
    final footer = d.wanted
        ? 'not found'
        : (d.playbackCount != null ? '${formatCount(d.playbackCount!)} plays' : null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          d.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: d.wanted ? ScTokens.textSecondary : ScTokens.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            if (d.uploadKind != null) ...[
              UploadKindDot(kind: d.uploadKind),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                d.artistLine,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: ScTokens.textSecondary, fontSize: 11),
              ),
            ),
          ],
        ),
        if (footer != null) ...[
          const SizedBox(height: 4),
          Text(footer, style: const TextStyle(color: ScTokens.textTertiary, fontSize: 10)),
        ],
      ],
    );
  }
}

class _OverlayIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _OverlayIcon({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          margin: const EdgeInsets.only(left: 6),
          width: 32,
          height: 32,
          decoration: const BoxDecoration(color: Color(0x80000000), shape: BoxShape.circle),
          child: Icon(icon, size: 14, color: const Color(0xCCFFFFFF)),
        ),
      ),
    );
  }
}
