import 'package:flutter/material.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../rust/dto.dart';
import 'album_aura.dart';

const _kindLabels = {
  'album': 'АЛЬБОМ',
  'ep': 'EP',
  'single': 'СИНГЛ',
  'compilation': 'СБОРНИК',
};

const _roleLabels = {
  'primary': 'Артист',
  'featured': 'При участии',
  'remixer': 'Ремикс',
  'producer': 'Продюсер',
};

/// Kind-пилюля (Disc3, аура-tint у звёздного) + Verified-пилюля при
/// `confidence >= 0.7` (легаси).
class AlbumKindBadges extends StatelessWidget {
  final AlbumDetailDto album;
  final AlbumAura aura;
  final bool hasStar;
  final WrapAlignment align;

  const AlbumKindBadges({
    super.key,
    required this.album,
    required this.aura,
    required this.hasStar,
    required this.align,
  });

  @override
  Widget build(BuildContext context) {
    final kindLabel = _kindLabels['album'] ?? 'АЛЬБОМ';
    return Wrap(
      alignment: align,
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: hasStar
                ? LinearGradient(colors: [aura.rgba(0.25), aura.rgba(0.08)])
                : null,
            color: hasStar ? null : const Color(0x0DFFFFFF),
            border: Border.all(color: hasStar ? aura.rgba(0.4) : const Color(0x14FFFFFF)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.disc3, size: 11, color: hasStar ? Colors.white : const Color(0xB3FFFFFF)),
              const SizedBox(width: 6),
              Text(
                kindLabel,
                style: TextStyle(
                  color: hasStar ? Colors.white : const Color(0xB3FFFFFF),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.8,
                ),
              ),
            ],
          ),
        ),
        if (album.confidence >= 0.7)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: const Color(0x1410B981),
              border: Border.all(color: const Color(0x3810B981)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.check, size: 11, color: Color(0xFF6EE7B7)),
                SizedBox(width: 4),
                Text(
                  'ПОДТВЕРЖДЁН',
                  style: TextStyle(
                    color: Color(0xFF6EE7B7),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.8,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Чипы артистов: primary — аура-градиент, featured — стекло. Аватар 28 + имя +
/// роль; тап → ArtistRoute.
class AlbumArtistChips extends StatelessWidget {
  final AlbumArtistDto primary;
  final List<AlbumArtistDto> featured;
  final AlbumAura aura;
  final WrapAlignment align;
  final ValueChanged<String> onTap;

  const AlbumArtistChips({
    super.key,
    required this.primary,
    required this.featured,
    required this.aura,
    required this.align,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: align,
      spacing: 8,
      runSpacing: 8,
      children: [
        if (primary.name.isNotEmpty)
          _ArtistChip(artist: primary, role: 'primary', aura: aura, onTap: onTap),
        for (final a in featured)
          _ArtistChip(artist: a, role: a.role ?? 'featured', aura: aura, onTap: onTap),
      ],
    );
  }
}

class _ArtistChip extends StatefulWidget {
  final AlbumArtistDto artist;
  final String role;
  final AlbumAura aura;
  final ValueChanged<String> onTap;

  const _ArtistChip({required this.artist, required this.role, required this.aura, required this.onTap});

  @override
  State<_ArtistChip> createState() => _ArtistChipState();
}

class _ArtistChipState extends State<_ArtistChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final isPrimary = widget.role == 'primary';
    final a = widget.aura;
    final subLabel = (_roleLabels[widget.role] ?? widget.role).toUpperCase();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => widget.onTap(widget.artist.id),
        child: AnimatedScale(
          scale: _hover ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 300),
          curve: ScTokens.easeApple,
          child: Container(
            padding: const EdgeInsets.fromLTRB(4, 4, 14, 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: isPrimary ? LinearGradient(colors: [a.rgba(0.18), a.rgba(0.04)]) : null,
              color: isPrimary ? null : const Color(0x0AFFFFFF),
              border: Border.all(color: isPrimary ? a.rgba(0.35) : const Color(0x14FFFFFF)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.fromBorderSide(BorderSide(color: Color(0x26FFFFFF))),
                  ),
                  child: ClipOval(child: Avatar(src: widget.artist.avatarUrl, alt: widget.artist.name, size: 28)),
                ),
                const SizedBox(width: 10),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.artist.name,
                      style: TextStyle(
                        color: _hover ? Colors.white : const Color(0xE6FFFFFF),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subLabel,
                      style: const TextStyle(
                        color: Color(0x59FFFFFF),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.8,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Инфо-чипы: год / число треков / суммарная длительность / доступность
/// (`indexed/total`, аура-tint).
class AlbumInfoChips extends StatelessWidget {
  final AlbumDetailDto album;
  final AlbumAura aura;
  final int totalMs;
  final int indexedCount;
  final WrapAlignment align;

  const AlbumInfoChips({
    super.key,
    required this.album,
    required this.aura,
    required this.totalMs,
    required this.indexedCount,
    required this.align,
  });

  @override
  Widget build(BuildContext context) {
    final total = album.tracks.length;
    return Wrap(
      alignment: align,
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (album.releaseYear != null)
          _InfoChip(icon: Icons.calendar_today, label: '${album.releaseYear}'),
        _InfoChip(icon: LucideIcons.listMusic, label: '$total ${_trackWord(total)}'),
        if (totalMs > 0) _InfoChip(icon: LucideIcons.clock, label: formatDurationLong(totalMs)),
        if (indexedCount < total)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: aura.rgba(0.12),
              border: Border.all(color: aura.rgba(0.3)),
            ),
            child: Text(
              'ДОСТУПНО $indexedCount/$total',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
              ),
            ),
          ),
      ],
    );
  }
}

String _trackWord(int n) {
  final mod10 = n % 10;
  final mod100 = n % 100;
  if (mod10 == 1 && mod100 != 11) return 'трек';
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return 'трека';
  return 'треков';
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: const Color(0x0AFFFFFF),
        border: Border.all(color: const Color(0x0FFFFFFF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: ScTokens.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: ScTokens.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
