import 'package:flutter/material.dart';

import '../tokens.dart';
import 'track/track_art.dart';

class TrackCardData {
  final String title;
  final String artist;
  final String? artworkUrl;

  const TrackCardData({required this.title, required this.artist, this.artworkUrl});
}

/// Лёгкая стеклянная строка трека для списков. БЕЗ per-row BackdropFilter
/// (десятки блюров дороги) — tint + hover поверх общей атмосферы.
class TrackCard extends StatefulWidget {
  final TrackCardData data;
  final VoidCallback? onTap;

  const TrackCard({super.key, required this.data, this.onTap});

  @override
  State<TrackCard> createState() => _TrackCardState();
}

class _TrackCardState extends State<TrackCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: ScTokens.dFast,
          curve: ScTokens.easeApple,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _hover ? ScTokens.glassTintHover : ScTokens.glassTint,
            borderRadius: BorderRadius.circular(ScTokens.rCard),
            border: Border.all(color: ScTokens.glassBorder),
          ),
          child: Row(
            children: [
              _artwork(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.data.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ScTokens.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      widget.data.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: ScTokens.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _artwork() {
    return SizedBox(
      width: 48,
      height: 48,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ScTokens.rArt),
        child: TrackArtwork(url: widget.data.artworkUrl, size: ArtSize.row),
      ),
    );
  }
}
