import 'package:flutter/material.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../rust/api.dart';
import 'artist_aura.dart';

/// Раздел «Скоро» (легаси `wanted`-партиция в `ArtistTracksTab`): аура-бейдж +
/// счётчик + разделитель, затем приглушённые строки треков, которых ещё нет в
/// хранилище (некликабельны, до 100).
class ComingSoonSection extends StatelessWidget {
  final List<TrackDto> wanted;
  final ArtistAura aura;

  const ComingSoonSection({super.key, required this.wanted, required this.aura});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: aura.rgba(0.16),
                borderRadius: BorderRadius.circular(9999),
                border: Border.all(color: aura.rgba(0.3)),
              ),
              child: const Text(
                'СКОРО',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.2,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              formatCount(wanted.length),
              style: const TextStyle(
                color: Color(0x4DFFFFFF),
                fontSize: 11,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Divider(height: 1, color: Color(0x0DFFFFFF))),
          ],
        ),
        const SizedBox(height: 12),
        for (final t in wanted.take(100)) _WantedRow(track: t),
      ],
    );
  }
}

class _WantedRow extends StatelessWidget {
  final TrackDto track;

  const _WantedRow({required this.track});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.5,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0x04FFFFFF),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0x08FFFFFF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x0FFFFFFF), width: 0.5),
                ),
                child: const Icon(LucideIcons.music, size: 16, color: Color(0x33FFFFFF)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0x8CFFFFFF), fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(track.artistName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0x40FFFFFF), fontSize: 11)),
                  ],
                ),
              ),
              if (track.releaseYear != null)
                Text('${track.releaseYear}',
                    style: const TextStyle(
                      color: Color(0x40FFFFFF),
                      fontSize: 11,
                      fontFeatures: [FontFeature.tabularFigures()],
                    )),
            ],
          ),
        ),
      ),
    );
  }
}
