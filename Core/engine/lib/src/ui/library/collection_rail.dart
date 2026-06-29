import 'package:flutter/material.dart';
import 'package:sc_visual/sc_visual.dart';

import 'horizontal_shelf.dart';

/// Полка-превью в хабе: срез одной коллекции с «Показать все» в её страницу
/// (легаси `CollectionRail`). Заголовок (иконка + название + счётчик + ссылка),
/// под ним — горизонтальная лента карточек.
class CollectionRail extends StatelessWidget {
  final IconData icon;
  final String title;
  final int? count;
  final VoidCallback? onSeeAll;
  final List<Widget> items;

  const CollectionRail({
    super.key,
    required this.icon,
    required this.title,
    required this.items,
    this.onSeeAll,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              Icon(icon, size: 16, color: const Color(0x8CFFFFFF)),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xE6FFFFFF),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (count != null && count! > 0) ...[
                const SizedBox(width: 8),
                Text(
                  formatCount(count!),
                  style: const TextStyle(
                    color: Color(0x4DFFFFFF),
                    fontSize: 12,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
              const Spacer(),
              if (onSeeAll != null) _SeeAll(onTap: onSeeAll!),
            ],
          ),
        ),
        HorizontalShelf(children: items),
      ],
    );
  }
}

class _SeeAll extends StatefulWidget {
  final VoidCallback onTap;

  const _SeeAll({required this.onTap});

  @override
  State<_SeeAll> createState() => _SeeAllState();
}

class _SeeAllState extends State<_SeeAll> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Показать все',
              style: TextStyle(
                color: _hover ? const Color(0xE6FFFFFF) : const Color(0x73FFFFFF),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              LucideIcons.chevronRight,
              size: 16,
              color: _hover ? const Color(0xE6FFFFFF) : const Color(0x73FFFFFF),
            ),
          ],
        ),
      ),
    );
  }
}
