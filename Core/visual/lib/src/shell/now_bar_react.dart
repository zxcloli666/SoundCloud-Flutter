import 'package:flutter/material.dart';

import '../theme.dart';
import 'now_bar_controls.dart';
import 'now_bar_data.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Кластер реакции в `.npb-row` (§2.4): Like (36×36, accent при like) + Dislike
/// (rose при dislike) + бейдж качества HQ/SQ (+ CDN-пилюля для storage).
class NowBarReactCluster extends StatelessWidget {
  final bool liked;
  final bool disliked;
  final NowBarQuality? quality;
  final NowBarSource? source;
  final VoidCallback? onLike;
  final VoidCallback? onDislike;

  const NowBarReactCluster({
    super.key,
    required this.liked,
    required this.disliked,
    required this.quality,
    required this.source,
    this.onLike,
    this.onDislike,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        NowBarIconButton(
          icon: liked ? Icons.favorite_rounded : LucideIcons.heart,
          size: 36,
          active: liked,
          onTap: onLike,
          tooltip: 'Like',
        ),
        NowBarIconButton(
          icon: Icons.thumb_down_alt_outlined,
          size: 36,
          active: disliked,
          activeColor: const Color(0xFFFB7185), // rose-400
          onTap: onDislike,
          tooltip: 'Dislike',
        ),
        if (quality != null) ...[
          const SizedBox(width: 4),
          PlaybackQualityBadge(quality: quality!, source: source),
        ],
      ],
    );
  }
}

/// Пилюля качества `h-6 rounded-md` (HQ/SQ) + опциональная CDN-метка для storage.
class PlaybackQualityBadge extends StatelessWidget {
  final NowBarQuality quality;
  final NowBarSource? source;

  const PlaybackQualityBadge({super.key, required this.quality, this.source});

  @override
  Widget build(BuildContext context) {
    final palette = ScTheme.paletteOf(context);
    final hq = quality == NowBarQuality.hq;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _pill(
          hq ? 'HQ' : 'SQ',
          fg: hq ? palette.accent : const Color(0x8CFFFFFF),
          bg: hq ? palette.accent.withValues(alpha: 0.15) : const Color(0x0FFFFFFF),
          border: hq ? palette.accent.withValues(alpha: 0.3) : const Color(0x14FFFFFF),
        ),
        if (source == NowBarSource.storage) ...[
          const SizedBox(width: 4),
          _pill(
            'CDN',
            fg: const Color(0x99FFFFFF),
            bg: const Color(0x0AFFFFFF),
            border: const Color(0x12FFFFFF),
          ),
        ],
      ],
    );
  }

  Widget _pill(String label, {required Color fg, required Color bg, required Color border}) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border, width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
