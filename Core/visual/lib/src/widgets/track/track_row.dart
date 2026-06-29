import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../tokens.dart';
import 'like_button.dart';
import 'track_art.dart';
import 'track_format.dart';
import 'track_status_badge.dart';
import 'upload_kind_dot.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Данные строки трека для списков. Title/artist — уже разрешённые по §5.1
/// (artistLine = enrichment, иначе uploader); вызывающий считает их сам.
class TrackRowData {
  final String title;
  final String artistLine;
  final String? artworkUrl;
  final int durationMs;
  final TrackStatusMeta? meta;
  final UploadKind? uploadKind;
  final bool liked;
  final bool wanted; // availability != 'indexed' → dimmed, non-clickable

  /// Прослушивания/лайки для колонки статистики (показывается при [TrackRow.showStats]).
  final int? playbackCount;
  final int? likesCount;

  const TrackRowData({
    required this.title,
    required this.artistLine,
    this.artworkUrl,
    this.durationMs = 0,
    this.meta,
    this.uploadKind,
    this.liked = false,
    this.wanted = false,
    this.playbackCount,
    this.likesCount,
  });
}

/// Строка списка треков (легаси `LibraryTrackRow`/`ThemedTrackRow`/`SequenceRow`
/// и т.п. — один параметрический ряд). Колонки: номер↔play (на hover/при
/// playing), обложка, title+artist, бейджи, like, menu, длительность.
///
/// [highlight] — источник подсветки активного ряда (accent у Library, aura у
/// User/Artist/Album). [lightHighlight] делает иконку play чёрной (§5.6).
/// Опциональные [grip]-DnD, [onAddToPlaylist]/[onAddToQueue] и [onRemove]
/// добавляют колонки. [showStats] — колонка прослушиваний/лайков (md+).
class TrackRow extends StatefulWidget {
  final TrackRowData data;
  final int index; // 1-based номер в колонке
  final bool playing; // этот трек звучит прямо сейчас
  final bool current; // этот трек активен (звучит или на паузе)
  final Color highlight;
  final bool lightHighlight;
  final bool showStats;
  final VoidCallback? onPlay;
  final ValueChanged<bool>? onToggleLike;
  final VoidCallback? onAddToPlaylist;
  final VoidCallback? onAddToQueue;
  final VoidCallback? onRemove;
  final Widget? grip; // drag-handle (DnD): когда задан — заменяет номер на hover

  const TrackRow({
    super.key,
    required this.data,
    required this.index,
    required this.highlight,
    this.playing = false,
    this.current = false,
    this.lightHighlight = false,
    this.showStats = false,
    this.onPlay,
    this.onToggleLike,
    this.onAddToPlaylist,
    this.onAddToQueue,
    this.onRemove,
    this.grip,
  });

  @override
  State<TrackRow> createState() => _TrackRowState();
}

class _TrackRowState extends State<TrackRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final hl = widget.highlight;
    final radius = BorderRadius.circular(ScTokens.rCard);

    final Color bg;
    final Border? border;
    if (widget.current) {
      bg = hl.withValues(alpha: 0.06);
      border = Border.all(color: hl.withValues(alpha: 0.20));
    } else if (_hover) {
      bg = const Color(0x0AFFFFFF); // white/0.04
      border = null;
    } else {
      bg = const Color(0x00000000);
      border = null;
    }

    return MouseRegion(
      cursor: d.wanted ? MouseCursor.defer : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: d.wanted ? null : widget.onPlay,
        child: AnimatedContainer(
          duration: ScTokens.dSidebar,
          curve: ScTokens.easeApple,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: bg, borderRadius: radius, border: border),
          child: Row(
            children: [
              _lead(hl),
              const SizedBox(width: 16),
              _artwork(),
              const SizedBox(width: 16),
              Expanded(child: _titleArtist()),
              if (d.meta != null) ...[
                const SizedBox(width: 12),
                TrackStatusBadge(meta: d.meta!),
              ],
              const SizedBox(width: 8),
              LikeButton(liked: d.liked, onToggle: widget.onToggleLike),
              if (widget.onAddToPlaylist != null)
                _IconAction(
                  icon: LucideIcons.listPlus,
                  visible: _hover,
                  onTap: widget.onAddToPlaylist,
                ),
              if (widget.onAddToQueue != null)
                _IconAction(
                  icon: LucideIcons.listMusic,
                  visible: _hover,
                  onTap: widget.onAddToQueue,
                ),
              if (widget.onRemove != null)
                _IconAction(
                  icon: LucideIcons.x,
                  visible: _hover,
                  onTap: widget.onRemove,
                ),
              if (widget.showStats) ...[
                const SizedBox(width: 12),
                _stats(),
              ],
              const SizedBox(width: 8),
              SizedBox(
                width: 48,
                child: Text(
                  formatDuration(d.durationMs),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: ScTokens.textSecondary,
                    fontSize: 12,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Номер ↔ play. Playing → круг подсветки с pause; иначе номер, на hover —
  /// play (или grip, если задан DnD).
  Widget _lead(Color hl) {
    const cell = 32.0;
    if (widget.playing) {
      return Container(
        width: cell,
        height: cell,
        decoration: BoxDecoration(color: hl, shape: BoxShape.circle),
        child: Icon(
          LucideIcons.pause,
          size: 16,
          color: widget.lightHighlight ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
        ),
      );
    }
    final showAction = _hover && !widget.data.wanted;
    if (showAction && widget.grip != null) {
      return SizedBox(width: cell, height: cell, child: Center(child: widget.grip));
    }
    return SizedBox(
      width: cell,
      height: cell,
      child: Center(
        child: showAction
            ? const Icon(LucideIcons.play, size: 18, color: Color(0xFFFFFFFF))
            : Text(
                '${widget.index}',
                style: const TextStyle(
                  color: ScTokens.textTertiary,
                  fontSize: 12,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
      ),
    );
  }

  Widget _artwork() {
    return SizedBox(
      width: 44,
      height: 44,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ScTokens.rButton),
        child: TrackArtwork(url: widget.data.artworkUrl, size: ArtSize.row),
      ),
    );
  }

  Widget _titleArtist() {
    final d = widget.data;
    final titleColor =
        d.wanted || !widget.current ? ScTokens.textPrimary : ScTheme.paletteOf(context).accent;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          d.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: d.wanted ? ScTokens.textSecondary : titleColor,
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
                d.wanted ? 'not found on SoundCloud' : d.artistLine,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: ScTokens.textSecondary, fontSize: 11),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Колонка прослушиваний/лайков (легаси `plays/likes`, md+). Скрыта, если
  /// статистики нет.
  Widget _stats() {
    final d = widget.data;
    final parts = <String>[
      if (d.playbackCount != null) '${formatCount(d.playbackCount!)} ▸',
      if (d.likesCount != null) '${formatCount(d.likesCount!)} ♥',
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return Text(
      parts.join('  '),
      style: const TextStyle(
        color: ScTokens.textTertiary,
        fontSize: 11,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final bool visible;
  final VoidCallback? onTap;

  const _IconAction({required this.icon, required this.visible, this.onTap});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: ScTokens.dFast,
      child: IgnorePointer(
        ignoring: !visible,
        child: GestureDetector(
          onTap: onTap,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: SizedBox(
              width: 32,
              height: 32,
              child: Icon(icon, size: 16, color: ScTokens.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}
