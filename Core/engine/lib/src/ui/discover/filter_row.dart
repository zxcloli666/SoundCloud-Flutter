import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:sc_visual/sc_visual.dart';

/// Опция фильтра/сортировки (легаси `FilterOption`).
class FilterOption {
  final String id;
  final String label;
  final int? count;

  const FilterOption({required this.id, required this.label, this.count});
}

/// Пилюль-группа фильтров (легаси `discover/FilterRow`): стеклянный контейнер,
/// активная пилюля = градиент ауры + inset-кольцо; size sm/md правит хром.
class FilterRow extends StatelessWidget {
  final List<FilterOption> options;
  final String active;
  final ValueChanged<String> onChanged;
  final bool small;

  const FilterRow({
    super.key,
    required this.options,
    required this.active,
    required this.onChanged,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = ScTheme.paletteOf(context).accent;
    final blur = PerfProfile.of(context).sigma(20);
    final radius = BorderRadius.circular(ScTokens.rCard);

    Widget group = Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: blur > 0 ? const Color(0x08FFFFFF) : const Color(0xE616161B),
        borderRadius: radius,
        border: Border.all(color: const Color(0x0FFFFFFF), width: 0.5),
      ),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final opt in options)
            _FilterPill(
              option: opt,
              active: opt.id == active,
              accent: accent,
              small: small,
              onTap: () => onChanged(opt.id),
            ),
        ],
      ),
    );

    if (blur > 0) {
      group = ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: group,
        ),
      );
    }
    return group;
  }
}

class _FilterPill extends StatelessWidget {
  final FilterOption option;
  final bool active;
  final Color accent;
  final bool small;
  final VoidCallback onTap;

  const _FilterPill({
    required this.option,
    required this.active,
    required this.accent,
    required this.small,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: ScTokens.dFast,
          curve: ScTokens.easeApple,
          height: small ? 28 : 32,
          padding: EdgeInsets.symmetric(horizontal: small ? 12 : 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ScTokens.rButton),
            gradient: active
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [accent.withValues(alpha: 0.22), accent.withValues(alpha: 0.06)],
                  )
                : null,
            border: active
                ? Border.all(color: accent.withValues(alpha: 0.35), width: 0.5)
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                option.label,
                style: TextStyle(
                  color: active ? const Color(0xFFFFFFFF) : const Color(0x73FFFFFF),
                  fontSize: small ? 10.5 : 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (option.count != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: active ? const Color(0x2EFFFFFF) : const Color(0x0DFFFFFF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${option.count}',
                    style: TextStyle(
                      color: active ? const Color(0xFFFFFFFF) : const Color(0x59FFFFFF),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
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
