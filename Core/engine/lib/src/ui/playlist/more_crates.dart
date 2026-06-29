import 'package:flutter/material.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../rust/dto.dart';

/// «Ещё ящики» — горизонтальная лента других плейлистов того же куратора.
/// Drag-to-scroll лента 176px-карточек (только видимые рендерятся:
/// [ListView.builder] по горизонтали).
class MoreCrates extends StatelessWidget {
  final String curatorName;
  final List<PlaylistSummaryDto> playlists;
  final void Function(String urn) onOpen;

  const MoreCrates({
    super.key,
    required this.curatorName,
    required this.playlists,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    if (playlists.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'More from $curatorName',
            style: const TextStyle(
              color: Color(0xB3FFFFFF),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 240,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemCount: playlists.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, i) {
              final p = playlists[i];
              return SizedBox(
                width: 176,
                child: PlaylistCard(
                  data: PlaylistCardData(
                    title: p.title,
                    artworkUrl: p.artworkUrl,
                    trackCount: p.trackCount,
                    typeLabel: p.isAlbum ? 'Album' : 'Playlist',
                    likesLabel:
                        p.likesCount != null ? formatCount(p.likesCount!.toInt()) : null,
                  ),
                  showPlayback: true,
                  onTap: () => onOpen(p.urn),
                  onPlay: () => onOpen(p.urn),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
