import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../providers.dart';

/// Контрольный ряд страницы поиска (легаси `SearchControls`): сегмент режимов
/// Текст|Вайб|Лирика (нашей БД) + тумблер источника **SoundCloud** (живой поиск).
/// При активном SC режимы гаснут (opacity 0.4); выбор режима возвращает источник
/// в БД. Запрос живёт в шапке — это лишь то, КАК он интерпретируется.
class SearchControls extends ConsumerWidget {
  final SearchMode mode;
  final ValueChanged<SearchMode> onMode;
  final SearchSource source;
  final ValueChanged<SearchSource> onSource;

  const SearchControls({
    super.key,
    required this.mode,
    required this.onMode,
    required this.source,
    required this.onSource,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = ScTheme.paletteOf(context).accent;
    final db = source == SearchSource.db;
    void pickMode(SearchMode m) {
      onMode(m);
      onSource(SearchSource.db);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedOpacity(
          duration: ScTokens.dGlass,
          opacity: db ? 1 : 0.4,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: const Color(0x0AFFFFFF),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0x1AFFFFFF), width: 0.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ModePill(
                  active: db && mode == SearchMode.text,
                  accent: accent,
                  icon: Icons.title_rounded,
                  label: ref.tr('search.mode.text'),
                  onTap: () => pickMode(SearchMode.text),
                ),
                const SizedBox(width: 2),
                _ModePill(
                  active: db && mode == SearchMode.vibe,
                  accent: accent,
                  icon: LucideIcons.sparkles,
                  label: ref.tr('search.mode.vibe'),
                  onTap: () => pickMode(SearchMode.vibe),
                ),
                const SizedBox(width: 2),
                _ModePill(
                  active: db && mode == SearchMode.lyrics,
                  accent: accent,
                  icon: Icons.format_quote_rounded,
                  label: ref.tr('search.mode.lyrics'),
                  onTap: () => pickMode(SearchMode.lyrics),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        _SourcePill(
          active: !db,
          accent: accent,
          label: ref.tr('search.source.sc'),
          onTap: () => onSource(db ? SearchSource.sc : SearchSource.db),
        ),
      ],
    );
  }
}

/// Тумблер источника SoundCloud: активный — акцентная рамка + glow.
class _SourcePill extends StatelessWidget {
  final bool active;
  final Color accent;
  final String label;
  final VoidCallback onTap;

  const _SourcePill({
    required this.active,
    required this.accent,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = active ? Colors.white : const Color(0x73FFFFFF);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: ScTokens.dGlass,
          curve: ScTokens.easeApple,
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: const Color(0x0AFFFFFF),
            border: Border.all(
              color: active ? accent : const Color(0x1AFFFFFF),
              width: 0.5,
            ),
            boxShadow: active
                ? [BoxShadow(color: accent.withValues(alpha: 0.2), blurRadius: 16)]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.cloud, size: 13, color: fg),
              const SizedBox(width: 5),
              Text(label,
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500, color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Пилюля выбора режима внутри сегмента. Активная — акцентное гало.
class _ModePill extends StatefulWidget {
  final bool active;
  final Color accent;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ModePill({
    required this.active,
    required this.accent,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_ModePill> createState() => _ModePillState();
}

class _ModePillState extends State<_ModePill> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final glow = widget.accent.withValues(alpha: 0.2);
    final fg = widget.active
        ? Colors.white
        : (_hover ? const Color(0xB3FFFFFF) : const Color(0x73FFFFFF));
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: ScTokens.dGlass,
          curve: ScTokens.easeApple,
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: widget.active ? const Color(0x0AFFFFFF) : null,
            boxShadow: widget.active
                ? [BoxShadow(color: glow, blurRadius: 16)]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 13, color: fg),
              const SizedBox(width: 4),
              Text(
                widget.label,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w500, color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
