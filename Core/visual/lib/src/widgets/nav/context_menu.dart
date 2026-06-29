import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../perf.dart';
import '../../theme.dart';
import '../../tokens.dart';

class ContextMenuItem {
  final String label;
  final IconData? icon;
  final VoidCallback? onSelected;
  final bool danger;

  const ContextMenuItem({
    required this.label,
    this.icon,
    this.onSelected,
    this.danger = false,
  });
}

/// Стеклянное всплывающее меню (легаси Radix-поповеры/инлайн-рейлы): тёмная
/// стеклянная карточка со строками-действиями. Сам surface — [ContextMenu];
/// открыть у якоря — [showContextMenu] (overlay + tap-to-dismiss).
class ContextMenu extends StatelessWidget {
  final List<ContextMenuItem> items;
  final double minWidth;
  final ValueChanged<ContextMenuItem>? onItemTap;

  const ContextMenu({
    super.key,
    required this.items,
    this.minWidth = 200,
    this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    final perf = ScPerf.of(context);
    final radius = BorderRadius.circular(ScTokens.rCard);
    final blur = PerfProfile(perf).sigma(32); // dropdown blur(32)

    Widget body = Container(
      constraints: BoxConstraints(minWidth: minWidth),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: perf == PerfMode.light
            ? const Color(0xF0101014)
            : const Color(0xC7101014), // rgba(16,16,20,0.78)
        borderRadius: radius,
        border: Border.all(color: const Color(0x1AFFFFFF), width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (final item in items) _MenuRow(item: item, onTap: onItemTap)],
      ),
    );

    if (blur > 0) {
      body = ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: body,
        ),
      );
    } else {
      body = ClipRRect(borderRadius: radius, child: body);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: perf == PerfMode.light
            ? const []
            : const [
                BoxShadow(
                    color: Color(0x8C000000), blurRadius: 60, offset: Offset(0, 24)),
              ],
      ),
      child: body,
    );
  }
}

class _MenuRow extends StatefulWidget {
  final ContextMenuItem item;
  final ValueChanged<ContextMenuItem>? onTap;

  const _MenuRow({required this.item, this.onTap});

  @override
  State<_MenuRow> createState() => _MenuRowState();
}

class _MenuRowState extends State<_MenuRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final danger = widget.item.danger;
    final base = danger ? const Color(0xFFFB7185) : const Color(0xD9FFFFFF);
    final color = _hover ? (danger ? const Color(0xFFFB7185) : const Color(0xFFFFFFFF)) : base;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () {
          widget.item.onSelected?.call();
          widget.onTap?.call(widget.item);
        },
        child: AnimatedContainer(
          duration: ScTokens.dFast,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ScTokens.rButton),
            color: _hover
                ? (danger ? const Color(0x1AFB7185) : const Color(0x14FFFFFF))
                : Colors.transparent,
          ),
          child: Row(
            children: [
              if (widget.item.icon != null) ...[
                Icon(widget.item.icon, size: 15, color: color),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  widget.item.label,
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500, color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Открывает [ContextMenu] у точки [position] (обычно — globalPosition тапа).
/// Прозрачный barrier гасит меню по тапу снаружи. Возвращает выбранный пункт.
Future<ContextMenuItem?> showContextMenu({
  required BuildContext context,
  required Offset position,
  required List<ContextMenuItem> items,
  double minWidth = 200,
}) {
  final overlay =
      Overlay.of(context).context.findRenderObject() as RenderBox?;
  final size = overlay?.size ?? MediaQuery.of(context).size;
  final palette = ScTheme.paletteOf(context);
  final perf = ScPerf.of(context);

  return showGeneralDialog<ContextMenuItem>(
    context: context,
    barrierColor: Colors.transparent,
    barrierDismissible: true,
    barrierLabel: 'menu',
    transitionDuration: ScTokens.dFast,
    pageBuilder: (ctx, _, __) {
      final left = position.dx.clamp(8.0, size.width - minWidth - 8.0);
      final fromBottom = position.dy > size.height * 0.6;
      return Stack(
        children: [
          Positioned(
            left: left,
            top: fromBottom ? null : position.dy,
            bottom: fromBottom ? size.height - position.dy : null,
            child: ScTheme(
              palette: palette,
              child: ScPerf(
                mode: perf,
                child: Material(
                  type: MaterialType.transparency,
                  child: ContextMenu(
                    items: items,
                    minWidth: minWidth,
                    onItemTap: (item) => Navigator.of(ctx).pop(item),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
    transitionBuilder: (_, anim, __, child) {
      final curved = CurvedAnimation(parent: anim, curve: ScTokens.easeApple);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: 0.96, end: 1.0).animate(curved),
          alignment: Alignment.topLeft,
          child: child,
        ),
      );
    },
  );
}
