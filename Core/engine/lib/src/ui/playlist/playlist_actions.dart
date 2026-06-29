import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sc_visual/sc_visual.dart';

/// Полная панель управления «ящиком»: Play the Set (акцентная пилюля) + Shuffle +
/// Like со счётчиком + утилитарный рельс (Pin / Copy link / владельцу — Delete).
class PlaylistActions extends StatelessWidget {
  final bool isOwner;
  final bool playing;
  final bool isPinned;
  final bool liked;
  final int likesCount;
  final String? permalinkUrl;
  final VoidCallback onPlayAll;
  final VoidCallback onShuffle;
  final ValueChanged<bool> onToggleLike;
  final VoidCallback onTogglePin;
  final VoidCallback onDelete;

  const PlaylistActions({
    super.key,
    required this.isOwner,
    required this.playing,
    required this.isPinned,
    required this.liked,
    required this.likesCount,
    required this.permalinkUrl,
    required this.onPlayAll,
    required this.onShuffle,
    required this.onToggleLike,
    required this.onTogglePin,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _PlayAll(playing: playing, onTap: onPlayAll),
        _Chip(
          icon: LucideIcons.shuffle,
          label: 'Shuffle',
          onTap: onShuffle,
        ),
        _LikeChip(liked: liked, count: likesCount, onToggle: onToggleLike),
        _UtilityRail(
          isOwner: isOwner,
          isPinned: isPinned,
          permalinkUrl: permalinkUrl,
          onTogglePin: onTogglePin,
          onDelete: onDelete,
        ),
      ],
    );
  }
}

/// Акцентная пилюля «играть весь сет» с проносящимся бликом на hover.
class _PlayAll extends StatefulWidget {
  final bool playing;
  final VoidCallback onTap;

  const _PlayAll({required this.playing, required this.onTap});

  @override
  State<_PlayAll> createState() => _PlayAllState();
}

class _PlayAllState extends State<_PlayAll> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final palette = ScTheme.paletteOf(context);
    final fg = widget.playing ? const Color(0xFF000000) : palette.accentContrast;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hover ? 1.03 : 1.0,
          duration: ScTokens.dGlass,
          curve: ScTokens.easeApple,
          child: Container(
            height: 44,
            padding: const EdgeInsets.only(left: 16, right: 24),
            decoration: BoxDecoration(
              color: widget.playing ? const Color(0xFFFFFFFF) : palette.accent,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: palette.accentGlow,
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.playing ? LucideIcons.pause : LucideIcons.play,
                  size: 18,
                  color: fg,
                ),
                const SizedBox(width: 10),
                Text(
                  'Play All',
                  style: TextStyle(
                    color: fg,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
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

/// Стеклянный чип-кнопка (Shuffle и т.п.): white/4 → hover white/7.
class _Chip extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _Chip({required this.icon, required this.label, required this.onTap});

  @override
  State<_Chip> createState() => _ChipState();
}

class _ChipState extends State<_Chip> {
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
          duration: ScTokens.dSidebar,
          curve: ScTokens.easeApple,
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: _hover ? const Color(0x12FFFFFF) : const Color(0x0AFFFFFF),
            borderRadius: BorderRadius.circular(ScTokens.rCard),
            border: Border.all(
              color: _hover ? ScTokens.glassBorderHi : const Color(0x12FFFFFF),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 14,
                color: _hover ? const Color(0xE6FFFFFF) : ScTokens.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  color: _hover ? const Color(0xE6FFFFFF) : const Color(0xA6FFFFFF),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Лайк-чип со счётчиком: liked → акцентный pill со свечением.
class _LikeChip extends StatelessWidget {
  final bool liked;
  final int count;
  final ValueChanged<bool> onToggle;

  const _LikeChip({required this.liked, required this.count, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final palette = ScTheme.paletteOf(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => onToggle(!liked),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: liked ? palette.accent.withValues(alpha: 0.15) : const Color(0x0AFFFFFF),
            borderRadius: BorderRadius.circular(ScTokens.rCard),
            border: Border.all(
              color: liked ? palette.accent.withValues(alpha: 0.30) : const Color(0x12FFFFFF),
              width: 0.5,
            ),
            boxShadow: liked
                ? [BoxShadow(color: palette.accentGlow, blurRadius: 18)]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                liked ? Icons.favorite : LucideIcons.heart,
                size: 15,
                color: liked ? palette.accent : const Color(0xA6FFFFFF),
              ),
              const SizedBox(width: 6),
              Text(
                formatCount(count),
                style: TextStyle(
                  color: liked ? palette.accent : const Color(0xA6FFFFFF),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Утилитарный рельс: Pin / Copy link / (владельцу) Delete в одной стеклянной
/// капсуле.
class _UtilityRail extends StatelessWidget {
  final bool isOwner;
  final bool isPinned;
  final String? permalinkUrl;
  final VoidCallback onTogglePin;
  final VoidCallback onDelete;

  const _UtilityRail({
    required this.isOwner,
    required this.isPinned,
    required this.permalinkUrl,
    required this.onTogglePin,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ScTheme.paletteOf(context);
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
          _RailButton(
            icon: Icons.push_pin,
            active: isPinned,
            activeColor: palette.accent,
            tooltip: isPinned ? 'Unpin' : 'Pin',
            onTap: onTogglePin,
          ),
          if (permalinkUrl != null) _CopyButton(url: permalinkUrl!),
          if (isOwner) ...[
            Container(width: 1, height: 20, color: const Color(0x14FFFFFF)),
            _RailButton(
              icon: LucideIcons.trash2,
              active: false,
              activeColor: const Color(0xFFF87171),
              danger: true,
              tooltip: 'Delete',
              onTap: onDelete,
            ),
          ],
        ],
      ),
    );
  }
}

class _RailButton extends StatefulWidget {
  final IconData icon;
  final bool active;
  final Color activeColor;
  final bool danger;
  final String tooltip;
  final VoidCallback onTap;

  const _RailButton({
    required this.icon,
    required this.active,
    required this.activeColor,
    required this.tooltip,
    required this.onTap,
    this.danger = false,
  });

  @override
  State<_RailButton> createState() => _RailButtonState();
}

class _RailButtonState extends State<_RailButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final Color fg;
    final Color bg;
    if (widget.active) {
      fg = widget.activeColor;
      bg = widget.activeColor.withValues(alpha: 0.15);
    } else if (_hover) {
      fg = widget.danger ? const Color(0xFFF87171) : const Color(0xF2FFFFFF);
      bg = widget.danger ? const Color(0x1AEF4444) : const Color(0x12FFFFFF);
    } else {
      fg = const Color(0x99FFFFFF);
      bg = const Color(0x00000000);
    }
    return ScTooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(ScTokens.rButton),
            ),
            child: Icon(widget.icon, size: 16, color: fg),
          ),
        ),
      ),
    );
  }
}

/// Копировать ссылку (без utm-параметров); 1.6s показывает галочку.
class _CopyButton extends StatefulWidget {
  final String url;
  const _CopyButton({required this.url});

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  void _copy() {
    var clean = widget.url;
    final q = clean.indexOf('?');
    if (q >= 0) {
      final base = clean.substring(0, q);
      final params = Uri.splitQueryString(clean.substring(q + 1))
        ..removeWhere((k, _) => k.startsWith('utm_'));
      clean = params.isEmpty
          ? base
          : Uri(path: base).replace(queryParameters: params).toString();
    }
    Clipboard.setData(ClipboardData(text: clean));
    setState(() => _copied = true);
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScTooltip(
      message: _copied ? 'Copied' : 'Copy link',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: _copy,
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _copied ? const Color(0x1F34D399) : const Color(0x00000000),
              borderRadius: BorderRadius.circular(ScTokens.rButton),
            ),
            child: Icon(
              _copied ? LucideIcons.check : LucideIcons.link,
              size: 16,
              color: _copied ? const Color(0xFF34D399) : const Color(0x99FFFFFF),
            ),
          ),
        ),
      ),
    );
  }
}
