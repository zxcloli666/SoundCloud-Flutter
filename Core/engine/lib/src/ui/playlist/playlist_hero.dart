import 'package:flutter/material.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../rust/api.dart';
import '../../rust/dto.dart';
import 'crate_stack.dart';
import 'curator_card.dart';
import 'playlist_actions.dart';
import 'playlist_aura.dart';

/// Шапка плейлиста: «ящик» (веер обложек) слева, справа — kind-пилюля + genre-
/// пилюля + заголовок (градиент по доминантному жанру) + genre-флеки + meta-чипы
/// + действия + карточка куратора. Адаптив: на узком — колонкой по центру.
class PlaylistHero extends StatelessWidget {
  final PlaylistSummaryDto summary;
  final List<TrackDto> tracks;
  final PlaylistAura aura;
  final bool isOwner;
  final bool playing;
  final bool isPinned;
  final bool liked;
  final int trackCount;
  final VoidCallback onPlayAll;
  final VoidCallback onShuffle;
  final ValueChanged<bool> onToggleLike;
  final VoidCallback onTogglePin;
  final VoidCallback onDelete;
  final VoidCallback onOpenCurator;

  const PlaylistHero({
    super.key,
    required this.summary,
    required this.tracks,
    required this.aura,
    required this.isOwner,
    required this.playing,
    required this.isPinned,
    required this.liked,
    required this.trackCount,
    required this.onPlayAll,
    required this.onShuffle,
    required this.onToggleLike,
    required this.onTogglePin,
    required this.onDelete,
    required this.onOpenCurator,
  });

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1024;
    final crate = CrateStack(
      title: summary.title,
      playlistArtworkUrl: summary.artworkUrl,
      tracks: tracks,
      playing: playing,
      trackCount: trackCount,
      onPlay: onPlayAll,
    );

    final col = Column(
      crossAxisAlignment: wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        _kindRow(context),
        const SizedBox(height: 20),
        _title(context),
        if (aura.hasGenres) ...[
          const SizedBox(height: 16),
          _flecks(wide),
        ],
        const SizedBox(height: 20),
        _metaChips(),
        const SizedBox(height: 24),
        PlaylistActions(
          isOwner: isOwner,
          playing: playing,
          isPinned: isPinned,
          liked: liked,
          likesCount: summary.likesCount?.toInt() ?? 0,
          permalinkUrl: summary.permalinkUrl,
          onPlayAll: onPlayAll,
          onShuffle: onShuffle,
          onToggleLike: onToggleLike,
          onTogglePin: onTogglePin,
          onDelete: onDelete,
        ),
        const SizedBox(height: 24),
        CuratorCard(
          username: summary.ownerUsername ?? 'Unknown',
          avatarUrl: summary.ownerAvatarUrl,
          aura: aura.accent,
          isOwner: isOwner,
          note: summary.description,
          onOpenUser: onOpenCurator,
        ),
      ],
    );

    return GlassPanel(
      variant: GlassVariant.featured,
      radius: ScTokens.rHero,
      padding: const EdgeInsets.all(40),
      child: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                crate,
                const SizedBox(width: 48),
                Expanded(child: col),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [crate, const SizedBox(height: 32), col],
            ),
    );
  }

  Widget _kindRow(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0x0DFFFFFF),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0x14FFFFFF)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.library_music_outlined, size: 11, color: Color(0xB3FFFFFF)),
              const SizedBox(width: 6),
              Text(
                _kindLabel(),
                style: const TextStyle(
                  color: Color(0xB3FFFFFF),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.8,
                ),
              ),
            ],
          ),
        ),
        if (aura.topGenres.length > 1)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: aura.accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'SPANS ${aura.topGenres.length} GENRES',
              style: const TextStyle(
                color: Color(0x8CFFFFFF),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
              ),
            ),
          ),
      ],
    );
  }

  Widget _title(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1280;
    final fontSize = wide ? 60.0 : (MediaQuery.sizeOf(context).width >= 768 ? 48.0 : 36.0);
    final base = Text(
      summary.title,
      textAlign: MediaQuery.sizeOf(context).width >= 1024 ? TextAlign.left : TextAlign.center,
      style: TextStyle(
        color: const Color(0xFFFFFFFF),
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        height: 0.9,
        letterSpacing: -2,
        shadows: const [Shadow(color: Color(0x80000000), blurRadius: 24, offset: Offset(0, 8))],
      ),
    );
    if (!aura.hasGenres) return base;
    // Заголовок окрашивается в градиент по доминантному жанру (white→tint→white).
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        begin: const Alignment(-1, -0.2),
        end: const Alignment(1, 0.2),
        colors: [
          const Color(0xFFFFFFFF),
          const Color(0xFFFFFFFF),
          aura.topGenres.length > 1 ? aura.topGenres[1].color : aura.accent,
          aura.accent,
          const Color(0xFFFFFFFF),
        ],
        stops: const [0, 0.28, 0.45, 0.58, 0.85],
      ).createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: base,
    );
  }

  Widget _flecks(bool wide) {
    return Wrap(
      spacing: 16,
      runSpacing: 6,
      alignment: wide ? WrapAlignment.start : WrapAlignment.center,
      children: [
        for (final g in aura.topGenres)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: g.color,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: g.color, blurRadius: 8)],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                g.genre,
                style: const TextStyle(color: Color(0x73FFFFFF), fontSize: 11),
              ),
            ],
          ),
      ],
    );
  }

  Widget _metaChips() {
    final edited = _formatDate(summary.lastModified);
    final chips = <Widget>[
      if ((summary.durationMs?.toInt() ?? 0) > 0)
        _MetaChip(icon: LucideIcons.clock, text: formatDurationLong(summary.durationMs!.toInt())),
      if (summary.releaseYear != null)
        _MetaChip(icon: Icons.calendar_today_outlined, text: '${summary.releaseYear}'),
      if (edited != null)
        _MetaChip(icon: Icons.edit_calendar_outlined, text: 'Изменён $edited'),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }

  /// Метка типа «ящика»: из `kind` (compilation→COLLECTION, album/ep/single→как
  /// есть), иначе по `isAlbum` (ALBUM/SET).
  String _kindLabel() {
    switch (summary.kind?.toLowerCase()) {
      case 'compilation':
        return 'COLLECTION';
      case 'album':
        return 'ALBUM';
      case 'ep':
        return 'EP';
      case 'single':
        return 'SINGLE';
      case null:
      case '':
        return summary.isAlbum ? 'ALBUM' : 'SET';
      default:
        return summary.kind!.toUpperCase();
    }
  }

  /// `lastModified` (ISO) → короткая дата dd.mm.yyyy. Невалидное — null.
  static String? _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    final dt = DateTime.tryParse(iso);
    if (dt == null) return null;
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    return '$d.$m.${dt.year}';
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x0DFFFFFF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x12FFFFFF), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: const Color(0x73FFFFFF)),
          const SizedBox(width: 6),
          Text(
            text.toUpperCase(),
            style: const TextStyle(
              color: Color(0x8CFFFFFF),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
