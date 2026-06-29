import 'package:flutter/material.dart';
import 'package:sc_visual/sc_visual.dart';

import 'track_aura.dart';

/// Источник света комнаты: квадратная обложка (220px) с жанровым кольцом, когда
/// артист подтверждён, и play/pause-наложением. Клик переключает воспроизведение.
class TrackCover extends StatefulWidget {
  final String? coverUrl;
  final TrackAura aura;
  final bool verified;
  final bool isPlaying;
  final VoidCallback onToggle;

  const TrackCover({
    super.key,
    required this.coverUrl,
    required this.aura,
    required this.verified,
    required this.isPlaying,
    required this.onToggle,
  });

  @override
  State<TrackCover> createState() => _TrackCoverState();
}

class _TrackCoverState extends State<TrackCover> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final showOverlay = widget.isPlaying || _hover;
    final ring = widget.verified
        ? Border.all(color: widget.aura.accent.withValues(alpha: 0.55), width: 2)
        : Border.all(color: const Color(0x1AFFFFFF), width: 1);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onToggle,
        child: SizedBox(
          width: 220,
          height: 220,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(35),
                  border: ring,
                  boxShadow: [
                    BoxShadow(
                      color: widget.verified
                          ? widget.aura.glow
                          : const Color(0x66000000),
                      blurRadius: 40,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(35),
                  child: TrackArtwork(url: widget.coverUrl, size: ArtSize.hero),
                ),
              ),
              IgnorePointer(
                child: AnimatedOpacity(
                  duration: ScTokens.dSidebar,
                  opacity: showOverlay ? 1 : 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0x40000000),
                      borderRadius: BorderRadius.circular(35),
                    ),
                    alignment: Alignment.center,
                    child: AnimatedScale(
                      duration: ScTokens.dSidebar,
                      curve: ScTokens.easeApple,
                      scale: showOverlay ? 1 : 0.75,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFFFFF),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Color(0x59000000), blurRadius: 24, offset: Offset(0, 10)),
                          ],
                        ),
                        child: Icon(
                          widget.isPlaying ? LucideIcons.pause : LucideIcons.play,
                          size: 30,
                          color: const Color(0xFF08080A),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
