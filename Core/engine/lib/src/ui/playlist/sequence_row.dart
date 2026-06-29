import 'package:flutter/material.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../rust/api.dart';
import '../track/track_aura.dart';

/// Строка секвенции (легаси `SequenceRow`). Левый hue-тик окрашен жанром ЭТОГО
/// трека — последовательность видимо меняет цвет, пока листаешь ящик. Колонки:
/// hue-тик, номер↔play, обложка 40, title/artist, scd-бейдж, статы, like,
/// длительность, (владельцу) удаление на hover.
class SequenceRow extends StatefulWidget {
  final TrackDto track;
  final int index; // 1-based
  final bool isCurrent;
  final bool isPlaying;
  final bool isOwner;
  final VoidCallback onPlay;
  final VoidCallback onRemove;

  /// Рукоятка перетаскивания (`ReorderableDragStartListener`). `null` — режим
  /// без сортировки: показываем обычный hue-тик/номер.
  final Widget? grip;

  const SequenceRow({
    super.key,
    required this.track,
    required this.index,
    required this.isCurrent,
    required this.isPlaying,
    required this.isOwner,
    required this.onPlay,
    required this.onRemove,
    this.grip,
  });

  @override
  State<SequenceRow> createState() => _SequenceRowState();
}

class _SequenceRowState extends State<SequenceRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.track;
    final palette = ScTheme.paletteOf(context);
    final aura = TrackAura.resolve(t.genre, palette.accent);
    final radius = BorderRadius.circular(ScTokens.rButton);

    final Color bg;
    Border? border;
    if (widget.isCurrent) {
      bg = palette.accent.withValues(alpha: 0.06);
      border = Border.all(color: palette.accent.withValues(alpha: 0.20));
    } else if (_hover) {
      bg = const Color(0x08FFFFFF);
    } else {
      bg = const Color(0x00000000);
    }

    final artistLine = (t.artistName.isNotEmpty ? t.artistName : t.uploaderUsername) ?? '';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: AnimatedContainer(
          duration: ScTokens.dFast,
          curve: ScTokens.easeApple,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(color: bg, borderRadius: radius, border: border),
          child: Row(
            children: [
              if (widget.grip != null)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: AnimatedOpacity(
                    duration: ScTokens.dFast,
                    opacity: _hover ? 0.9 : 0.4,
                    child: SizedBox(width: 18, height: 32, child: widget.grip),
                  ),
                )
              else if (aura.hasGenre)
                _hueTick(aura.accent),
              _lead(palette.accent),
              const SizedBox(width: 14),
              _cover(),
              const SizedBox(width: 14),
              Expanded(child: _titleArtist(artistLine, palette.accent)),
              if (_meta(t) != null) ...[
                const SizedBox(width: 12),
                QualityBadge(meta: _meta(t)!),
              ],
              const SizedBox(width: 8),
              _stats(t),
              const SizedBox(width: 8),
              SizedBox(
                width: 40,
                child: Text(
                  formatDuration(t.durationMs.toInt()),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: ScTokens.textTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              if (widget.isOwner) _remove(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hueTick(Color hue) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: AnimatedOpacity(
        duration: ScTokens.dSidebar,
        opacity: widget.isCurrent ? 1 : 0.4,
        child: Container(
          width: 3,
          height: 32,
          decoration: BoxDecoration(
            color: hue,
            borderRadius: BorderRadius.circular(999),
            boxShadow: widget.isCurrent ? [BoxShadow(color: hue, blurRadius: 10)] : null,
          ),
        ),
      ),
    );
  }

  /// Номер ↔ play. Playing → акцентный круг с pause; иначе номер, на hover — play.
  Widget _lead(Color accent) {
    if (widget.isPlaying) {
      return GestureDetector(
        onTap: widget.onPlay,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: accent,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.20), blurRadius: 12)],
          ),
          child: const Icon(LucideIcons.pause, size: 14, color: Color(0xFFFFFFFF)),
        ),
      );
    }
    return GestureDetector(
      onTap: widget.onPlay,
      child: SizedBox(
        width: 32,
        height: 32,
        child: Center(
          child: _hover
              ? Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: Color(0x1AFFFFFF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.play, size: 16, color: Color(0xFFFFFFFF)),
                )
              : Text(
                  '${widget.index}',
                  style: const TextStyle(
                    color: ScTokens.textTertiary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _cover() {
    return SizedBox(
      width: 40,
      height: 40,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ScTokens.rButton),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ScTokens.rButton),
            border: Border.all(color: const Color(0x0FFFFFFF)),
          ),
          child: TrackArtwork(url: widget.track.artworkUrl, size: ArtSize.row),
        ),
      ),
    );
  }

  Widget _titleArtist(String artistLine, Color accent) {
    final t = widget.track;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: widget.isCurrent ? accent : ScTokens.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          artistLine,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: ScTokens.textSecondary, fontSize: 11),
        ),
      ],
    );
  }

  Widget _stats(TrackDto t) {
    final parts = <String>[
      if (t.playCount != null) '${formatCount(t.playCount!.toInt())} ▸',
      if (t.likesCount != null) '${formatCount(t.likesCount!.toInt())} ♥',
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return Text(
      parts.join('  '),
      style: const TextStyle(
        color: Color(0x33FFFFFF),
        fontSize: 10,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
    );
  }

  Widget _remove() {
    return AnimatedOpacity(
      opacity: _hover ? 1 : 0,
      duration: ScTokens.dFast,
      child: IgnorePointer(
        ignoring: !_hover,
        child: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: widget.onRemove,
              child: const SizedBox(
                width: 28,
                height: 28,
                child: Icon(LucideIcons.trash2, size: 14, color: Color(0x33FFFFFF)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `_scd_meta` из полей TrackDto (storage/index state + quality) для бейджа.
ScdMeta? _meta(TrackDto t) {
  if (t.storageState == null && t.indexState == null && t.storageQuality == null) {
    return null;
  }
  return ScdMeta(
    storageState: t.storageState,
    storageQuality: t.storageQuality,
    indexState: t.indexState,
  );
}
