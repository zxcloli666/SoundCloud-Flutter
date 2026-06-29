import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../tokens.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Кнопка лайка трека: круглая, Heart заливается при liked, окрашивается в
/// акцент. Состояние [liked] контролирует вызывающий (оптимистичный апдейт —
/// его забота); кнопка только рисует и зовёт [onToggle].
class LikeButton extends StatefulWidget {
  final bool liked;
  final ValueChanged<bool>? onToggle;
  final double size; // диаметр круга
  final double iconSize;

  const LikeButton({
    super.key,
    required this.liked,
    this.onToggle,
    this.size = 36,
    this.iconSize = 16,
  });

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final accent = ScTheme.paletteOf(context).accent;
    final color = widget.liked
        ? accent
        : (_hover ? const Color(0xCCFFFFFF) : const Color(0x4DFFFFFF));

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => widget.onToggle?.call(!widget.liked),
        child: AnimatedContainer(
          duration: ScTokens.dFast,
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _hover ? ScTokens.glassTintHover : const Color(0x00000000),
          ),
          alignment: Alignment.center,
          child: Icon(
            widget.liked ? Icons.favorite : LucideIcons.heart,
            size: widget.iconSize,
            color: color,
          ),
        ),
      ),
    );
  }
}
