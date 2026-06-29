import 'package:flutter/material.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../rust/api.dart';
import 'album_aura.dart';
import 'album_panel.dart';
import 'album_track_row.dart';

/// Признак «wanted» (трек ещё не индексирован/недоступен). В DTO нет
/// `enrichment.availability` — берём плоский `indexState == 'wanted'`.
bool isWanted(TrackDto t) => t.indexState == 'wanted';

/// Треклист альбома (легаси `AlbumTrackList`). Панель `2rem`, заголовок с
/// числом + суммарной длительностью, доступные строки, затем секция «скоро».
/// Пусто — иконка + текст.
class AlbumTrackList extends StatelessWidget {
  final List<TrackDto> tracks;
  final AlbumAura aura;

  const AlbumTrackList({super.key, required this.tracks, required this.aura});

  @override
  Widget build(BuildContext context) {
    if (tracks.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 96),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.music, size: 24, color: Color(0x26FFFFFF)),
              SizedBox(height: 16),
              Text('В альбоме нет треков', style: TextStyle(color: ScTokens.textTertiary, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    final available = <TrackDto>[];
    final wanted = <TrackDto>[];
    var totalMs = 0;
    for (final t in tracks) {
      if (isWanted(t)) {
        wanted.add(t);
      } else {
        available.add(t);
        totalMs += t.durationMs.toInt();
      }
    }

    return AlbumPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(available: available.length, totalMs: totalMs),
          const SizedBox(height: 8),
          if (available.isNotEmpty)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: available.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (context, i) => AlbumTrackRow(
                key: ValueKey(available[i].urn),
                track: available[i],
                position: i + 1,
                queue: available,
                aura: aura,
              ),
            ),
          if (wanted.isNotEmpty) ...[
            const SizedBox(height: 24),
            _ComingSoonDivider(aura: aura, count: wanted.length),
            const SizedBox(height: 12),
            for (var i = 0; i < wanted.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _WantedRow(track: wanted[i], position: available.length + i + 1),
              ),
          ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final int available;
  final int totalMs;

  const _Header({required this.available, required this.totalMs});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.listMusic, size: 12, color: ScTokens.textSecondary),
              const SizedBox(width: 8),
              const Text(
                'ТРЕКИ',
                style: TextStyle(
                  color: ScTokens.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.4,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$available',
                style: const TextStyle(color: ScTokens.textTertiary, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          Text(
            formatDurationLong(totalMs),
            style: const TextStyle(
              color: ScTokens.textTertiary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _ComingSoonDivider extends StatelessWidget {
  final AlbumAura aura;
  final int count;

  const _ComingSoonDivider({required this.aura, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: aura.rgba(0.16),
              border: Border.all(color: aura.rgba(0.3)),
            ),
            child: const Text(
              'СКОРО',
              style: TextStyle(
                color: Color(0xFFFFFFFF),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.2,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text('$count', style: const TextStyle(color: ScTokens.textTertiary, fontSize: 11)),
          const SizedBox(width: 12),
          const Expanded(child: Divider(color: Color(0x0DFFFFFF), height: 1)),
        ],
      ),
    );
  }
}

/// Недоступный трек: приглушённый, без play, длительность или прочерк.
class _WantedRow extends StatelessWidget {
  final TrackDto track;
  final int position;

  const _WantedRow({required this.track, required this.position});

  @override
  Widget build(BuildContext context) {
    final ms = track.durationMs.toInt();
    return Opacity(
      opacity: 0.5,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ScTokens.rCard),
          color: const Color(0x04FFFFFF),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Text(
                '$position',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: ScTokens.textTertiary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: const Color(0x08FFFFFF),
                border: Border.all(color: const Color(0x0FFFFFFF)),
              ),
              child: const Icon(LucideIcons.music, size: 14, color: Color(0x33FFFFFF)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0x8CFFFFFF), fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    track.artistName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: ScTokens.textTertiary, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 48,
              child: Text(
                ms > 0 ? formatDuration(ms) : '—',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: ScTokens.textTertiary,
                  fontSize: 11,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
