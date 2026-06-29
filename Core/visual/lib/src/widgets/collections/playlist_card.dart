import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../image_proxy.dart';
import '../../tokens.dart';
import 'collection_art.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Данные карточки плейлиста. `displayCount` форматируется вызывающим
/// (легаси `fc()`); карточка чистая презентация.
class PlaylistCardData {
  final String title;
  final String? artworkUrl;
  final int? trackCount;
  final bool isPrivate;

  /// Когда `showPlayback`: тип ("PLAYLIST"/"ALBUM") + лайки; иначе — имя автора.
  final String? typeLabel;
  final String? likesLabel;
  final String? uploader;

  const PlaylistCardData({
    required this.title,
    this.artworkUrl,
    this.trackCount,
    this.isPrivate = false,
    this.typeLabel,
    this.likesLabel,
    this.uploader,
  });
}

/// Квадратная карточка плейлиста (легаси `music/PlaylistCard`). Обложка
/// `rounded-2xl ring white/6` → hover ring white/15 + рост тени + zoom 1.05;
/// приватный замок, пилюля счётчика треков, и (при `showPlayback`) play-оверлей
/// 56px с затемнением/блюром.
class PlaylistCard extends StatefulWidget {
  final PlaylistCardData data;

  /// Показывать play-кнопку, бейдж типа и лайки (вместо имени автора).
  final bool showPlayback;
  final bool playing;
  final VoidCallback? onTap;
  final VoidCallback? onPlay;

  const PlaylistCard({
    super.key,
    required this.data,
    this.showPlayback = false,
    this.playing = false,
    this.onTap,
    this.onPlay,
  });

  @override
  State<PlaylistCard> createState() => _PlaylistCardState();
}

class _PlaylistCardState extends State<PlaylistCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(aspectRatio: 1, child: _cover()),
            const SizedBox(height: 12),
            _meta(),
          ],
        ),
      ),
    );
  }

  Widget _cover() {
    final radius = BorderRadius.circular(ScTokens.rCard);
    return AnimatedContainer(
      duration: ScTokens.dGlass,
      curve: ScTokens.easeApple,
      decoration: BoxDecoration(
        color: const Color(0x05FFFFFF),
        borderRadius: radius,
        border: Border.all(color: _hover ? const Color(0x26FFFFFF) : const Color(0x0FFFFFFF)),
        boxShadow: [
          BoxShadow(
            color: _hover ? const Color(0x80000000) : const Color(0x59000000),
            blurRadius: _hover ? 50 : 18,
            offset: Offset(0, _hover ? 22 : 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _artwork(),
            if (widget.showPlayback) _playOverlay() else _hoverDim(),
            if (widget.data.isPrivate) const Positioned(top: 10, left: 10, child: _PrivateLock()),
            if (widget.data.trackCount != null)
              Positioned(bottom: 10, right: 10, child: _trackCountPill()),
          ],
        ),
      ),
    );
  }

  Widget _artwork() {
    final url = upscaleArtwork(widget.data.artworkUrl);
    final placeholder = const ColoredBox(
      color: Color(0x0AFFFFFF),
      child: Center(child: Icon(LucideIcons.listMusic, size: 32, color: Color(0x26FFFFFF))),
    );
    // PERF: декодируем в размер ячейки×DPR, а не полный t300x300 ARGB —
    // карточка заполняет виртуальные гриды (см. TrackArtwork).
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final img = (url == null)
        ? placeholder
        : LayoutBuilder(
            builder: (context, c) => Image(
              image: ScImageProxy.sized(
                  url, c.maxWidth.isFinite ? (c.maxWidth * dpr).round() : null),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => placeholder,
            ),
          );
    return AnimatedScale(
      scale: _hover ? 1.05 : 1.0,
      duration: const Duration(milliseconds: 700),
      curve: ScTokens.easeApple,
      child: img,
    );
  }

  Widget _hoverDim() => AnimatedOpacity(
        opacity: _hover ? 1 : 0,
        duration: ScTokens.dSidebar,
        child: const ColoredBox(color: Color(0x33000000)),
      );

  Widget _playOverlay() {
    final visible = _hover || widget.playing;
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: ScTokens.dSidebar,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: Container(
            color: const Color(0x66000000),
            alignment: Alignment.center,
            child: AnimatedScale(
              scale: visible ? 1.0 : 0.75,
              duration: ScTokens.dSidebar,
              curve: ScTokens.easeApple,
              child: GestureDetector(
                onTap: widget.onPlay,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(color: Color(0xFFFFFFFF), shape: BoxShape.circle),
                  child: Icon(
                    widget.playing ? LucideIcons.pause : LucideIcons.play,
                    size: 26,
                    color: const Color(0xFF000000),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _trackCountPill() {
    final pill = _CoverPill(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.listMusic, size: 11, color: Color(0xE6FFFFFF)),
          const SizedBox(width: 6),
          Text(
            '${widget.data.trackCount}',
            style: const TextStyle(
              color: Color(0xE6FFFFFF),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
    if (!widget.showPlayback) return pill;
    return AnimatedOpacity(opacity: _hover ? 1 : 0, duration: ScTokens.dSidebar, child: pill);
  }

  Widget _meta() {
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
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 4),
          widget.showPlayback ? _playbackSubtitle() : _uploaderSubtitle(),
        ],
      ),
    );
  }

  Widget _playbackSubtitle() {
    final likes = widget.data.likesLabel;
    return Row(
      children: [
        _TypeBadge(label: widget.data.typeLabel ?? 'Playlist'),
        if (likes != null && likes.isNotEmpty) ...[
          const SizedBox(width: 8),
          const Icon(Icons.favorite, size: 10, color: Color(0x33FFFFFF)),
          const SizedBox(width: 4),
          Text(likes, style: const TextStyle(color: Color(0x4DFFFFFF), fontSize: 11)),
        ],
      ],
    );
  }

  Widget _uploaderSubtitle() => Text(
        widget.data.uploader ?? 'Unknown',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Color(0x66FFFFFF), fontSize: 12),
      );
}

/// Тёмная пилюля поверх обложки (счётчик треков), `bg-black/60 px-2.5 py-1`.
class _CoverPill extends StatelessWidget {
  final Widget child;
  const _CoverPill({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: const BoxDecoration(
          color: Color(0x99000000),
          borderRadius: BorderRadius.all(Radius.circular(999)),
        ),
        child: child,
      );
}

class _PrivateLock extends StatelessWidget {
  const _PrivateLock();

  @override
  Widget build(BuildContext context) => Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(color: Color(0x99000000), shape: BoxShape.circle),
        alignment: Alignment.center,
        child: const Icon(Icons.lock, size: 11, color: Color(0xE6FCD34D)),
      );
}

/// Бейдж типа плейлиста: `text-[10px] font-bold uppercase` на `white/5`.
class _TypeBadge extends StatelessWidget {
  final String label;
  const _TypeBadge({required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: const BoxDecoration(
          color: Color(0x0DFFFFFF),
          borderRadius: BorderRadius.all(Radius.circular(6)),
        ),
        child: Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: Color(0x4DFFFFFF),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      );
}
