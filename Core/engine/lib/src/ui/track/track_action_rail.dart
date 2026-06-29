import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../rust/api.dart';

/// Hero-рельса: PlayPill + лайк-чип + утилитарная группа (лирика / копировать
/// ссылку). Живёт вне жанрового скоупа волны, поэтому play/лайк держат акцент
/// юзера. Все колбэки инъектируются — виджет без бизнес-логики.
class TrackActionRail extends StatelessWidget {
  final TrackDto track;
  final bool isPlaying;
  final bool liked;
  final int likeCount;
  final VoidCallback onPlay;
  final ValueChanged<bool> onToggleLike;
  final VoidCallback onLyrics;

  const TrackActionRail({
    super.key,
    required this.track,
    required this.isPlaying,
    required this.liked,
    required this.likeCount,
    required this.onPlay,
    required this.onToggleLike,
    required this.onLyrics,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _PlayPill(isPlaying: isPlaying, onTap: onPlay),
        _LikeChip(liked: liked, count: likeCount, onToggle: onToggleLike),
        _UtilityGroup(
          permalinkUrl: track.permalinkUrl,
          onLyrics: onLyrics,
        ),
      ],
    );
  }
}

class _PlayPill extends StatefulWidget {
  final bool isPlaying;
  final VoidCallback onTap;

  const _PlayPill({required this.isPlaying, required this.onTap});

  @override
  State<_PlayPill> createState() => _PlayPillState();
}

class _PlayPillState extends State<_PlayPill> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final palette = ScTheme.paletteOf(context);
    final playing = widget.isPlaying;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hover ? 1.03 : 1.0,
          duration: ScTokens.dFast,
          curve: ScTokens.easeApple,
          child: Container(
            height: 44,
            padding: const EdgeInsets.only(left: 16, right: 24),
            decoration: BoxDecoration(
              color: playing ? const Color(0xF2FFFFFF) : null,
              gradient: playing ? null : palette.playGradient,
              borderRadius: BorderRadius.circular(9999),
              boxShadow: [
                BoxShadow(color: palette.accentGlow, blurRadius: 32, offset: const Offset(0, 12)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  playing ? LucideIcons.pause : LucideIcons.play,
                  size: 18,
                  color: playing ? const Color(0xFF08080A) : palette.accentContrast,
                ),
                const SizedBox(width: 8),
                Text(
                  playing ? 'Пауза' : 'Слушать',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: playing ? const Color(0xFF08080A) : palette.accentContrast,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LikeChip extends StatefulWidget {
  final bool liked;
  final int count;
  final ValueChanged<bool> onToggle;

  const _LikeChip({required this.liked, required this.count, required this.onToggle});

  @override
  State<_LikeChip> createState() => _LikeChipState();
}

class _LikeChipState extends State<_LikeChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final accent = ScTheme.paletteOf(context).accent;
    final liked = widget.liked;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => widget.onToggle(!liked),
        child: AnimatedContainer(
          duration: ScTokens.dFast,
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: liked
                ? accent.withValues(alpha: 0.15)
                : (_hover ? const Color(0x0FFFFFFF) : const Color(0x0AFFFFFF)),
            borderRadius: BorderRadius.circular(ScTokens.rCard),
            border: Border.all(
              color: liked ? accent.withValues(alpha: 0.30) : const Color(0x12FFFFFF),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                liked ? Icons.favorite : LucideIcons.heart,
                size: 15,
                color: liked ? accent : const Color(0x8CFFFFFF),
              ),
              if (widget.count > 0) ...[
                const SizedBox(width: 7),
                Text(
                  formatCount(widget.count),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: liked ? accent : const Color(0x8CFFFFFF),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _UtilityGroup extends StatelessWidget {
  final String? permalinkUrl;
  final VoidCallback onLyrics;

  const _UtilityGroup({required this.permalinkUrl, required this.onLyrics});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: const Color(0x0AFFFFFF),
        borderRadius: BorderRadius.circular(ScTokens.rCard),
        border: Border.all(color: const Color(0x12FFFFFF), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _IconAction(icon: LucideIcons.mic, tooltip: 'Текст', onTap: onLyrics),
          if (permalinkUrl != null) ...[
            const _Divider(),
            _CopyAction(url: permalinkUrl!),
          ],
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      color: const Color(0x14FFFFFF),
    );
  }
}

class _CopyAction extends StatefulWidget {
  final String url;

  const _CopyAction({required this.url});

  @override
  State<_CopyAction> createState() => _CopyActionState();
}

class _CopyActionState extends State<_CopyAction> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    return _IconAction(
      icon: _copied ? LucideIcons.check : LucideIcons.link,
      tooltip: 'Скопировать ссылку',
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: widget.url));
        if (!mounted) return;
        setState(() => _copied = true);
        Future.delayed(const Duration(milliseconds: 1400), () {
          if (mounted) setState(() => _copied = false);
        });
      },
    );
  }
}

class _IconAction extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _IconAction({required this.icon, required this.tooltip, required this.onTap});

  @override
  State<_IconAction> createState() => _IconActionState();
}

class _IconActionState extends State<_IconAction> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return ScTooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: ScTokens.dFast,
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _hover ? const Color(0x12FFFFFF) : const Color(0x00000000),
              borderRadius: BorderRadius.circular(ScTokens.rButton),
            ),
            alignment: Alignment.center,
            child: Icon(
              widget.icon,
              size: 16,
              color: _hover ? const Color(0xF2FFFFFF) : const Color(0x99FFFFFF),
            ),
          ),
        ),
      ),
    );
  }
}
