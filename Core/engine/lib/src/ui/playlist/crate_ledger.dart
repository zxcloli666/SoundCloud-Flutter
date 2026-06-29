import 'package:flutter/material.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../rust/api.dart';

/// Реестр ящика: факты, какие есть только у курированной коллекции — число
/// треков, длительность, число артистов, спанятых жанров, диапазон лет.
class CrateLedger extends StatelessWidget {
  final List<TrackDto> tracks;
  final int trackCount;
  final int durationMs;
  final Color accentGlow;

  const CrateLedger({
    super.key,
    required this.tracks,
    required this.trackCount,
    required this.durationMs,
    required this.accentGlow,
  });

  @override
  Widget build(BuildContext context) {
    final artists = <String>{};
    final genres = <String>{};
    int? minYear;
    int? maxYear;
    for (final tr in tracks) {
      final aid = tr.artistId.isNotEmpty ? tr.artistId : tr.uploaderId;
      if (aid != null && aid.isNotEmpty) artists.add(aid);
      final g = tr.genre?.trim();
      if (g != null && g.isNotEmpty) genres.add(g.toLowerCase());
      final y = tr.releaseYear;
      if (y != null && y > 1900) {
        minYear = minYear == null ? y : (y < minYear ? y : minYear);
        maxYear = maxYear == null ? y : (y > maxYear ? y : maxYear);
      }
    }

    final facts = <Widget>[
      _Fact(
        icon: LucideIcons.listMusic,
        text: '$trackCount tracks',
        glow: accentGlow,
      ),
      if (durationMs > 0)
        _Fact(icon: LucideIcons.clock, text: formatDurationLong(durationMs), glow: accentGlow),
      if (artists.length > 1)
        _Fact(icon: Icons.group_outlined, text: '${artists.length} artists', glow: accentGlow),
      if (genres.length > 1)
        _Fact(icon: Icons.tag, text: '${genres.length} genres', glow: accentGlow),
      if (minYear != null && maxYear != null)
        _Fact(
          icon: Icons.calendar_today_outlined,
          text: minYear == maxYear ? '$minYear' : '$minYear – $maxYear',
          glow: accentGlow,
        ),
    ];

    return Wrap(spacing: 10, runSpacing: 10, children: facts);
  }
}

class _Fact extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color glow;

  const _Fact({required this.icon, required this.text, required this.glow});

  @override
  Widget build(BuildContext context) {
    final perfGlow = ScPerf.of(context) == PerfMode.beauty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x09FFFFFF),
        borderRadius: BorderRadius.circular(ScTokens.rCard),
        border: Border.all(color: const Color(0x12FFFFFF), width: 0.5),
        boxShadow: perfGlow
            ? [BoxShadow(color: glow, blurRadius: 22, offset: const Offset(0, 8))]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0x66FFFFFF)),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xB3FFFFFF),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
