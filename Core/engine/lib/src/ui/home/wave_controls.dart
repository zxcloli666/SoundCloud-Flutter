import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../providers.dart';

/// Пульт волны деки (легаси `EstuaryDeck`): тумблеры «Свежак»/«Скрыть лайки» и
/// фильтр языков. Состояние — [waveFiltersProvider]; смена пере-запрашивает реку.

/// Языки фильтра волны (легаси `language-filter`).
const _languages = <(String, String)>[
  ('en', 'English'),
  ('ru', 'Русский'),
  ('es', 'Español'),
  ('de', 'Deutsch'),
  ('fr', 'Français'),
  ('it', 'Italiano'),
  ('pt', 'Português'),
  ('ja', '日本語'),
  ('ko', '한국어'),
  ('tr', 'Türkçe'),
  ('pl', 'Polski'),
  ('uk', 'Українська'),
];

/// Пилюля-тумблер с мини-свитчем (легаси `HideListenedToggle`/`HideLikedToggle`):
/// активна — accent-glow фон + accent текст + свитч вправо.
class WaveToggle extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const WaveToggle({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final accent = ScTheme.paletteOf(context).accent;
    final glow = ScTheme.paletteOf(context).accentGlow;
    final fg = value ? accent : const Color(0xB3FFFFFF);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: ScTokens.dFast,
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: value ? glow : const Color(0x0FFFFFFF),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: value ? glow : const Color(0x14FFFFFF)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                    color: fg, fontSize: 11, fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 8),
              _MiniSwitch(value: value, accent: accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniSwitch extends StatelessWidget {
  final bool value;
  final Color accent;

  const _MiniSwitch({required this.value, required this.accent});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 12,
      child: Stack(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: value ? accent : const Color(0x2EFFFFFF),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const SizedBox.expand(),
          ),
          AnimatedPositioned(
            duration: ScTokens.dFast,
            curve: ScTokens.easeApple,
            top: 1,
            left: value ? 11 : 1,
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle),
            ),
          ),
        ],
      ),
    );
  }
}

/// Фильтр языков (легаси `LanguageFilter`): пилюля Globe + «Все языки»/«N яз»,
/// по тапу — стеклянный поповер с чипами языков (мультивыбор).
class LanguageFilterButton extends ConsumerWidget {
  const LanguageFilterButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(waveFiltersProvider.select((f) => f.languages));
    final count = selected.length;
    final label = count == 0
        ? ref.tr('soundwave.allLanguages')
        : '$count ${ref.tr('soundwave.langShort')}';

    return MenuAnchor(
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(Color(0xE0121216)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0x14FFFFFF)),
          ),
        ),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(8)),
      ),
      menuChildren: [
        SizedBox(
          width: 240,
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (code, name) in _languages)
                _LangChip(
                  code: code,
                  name: name,
                  selected: selected.contains(code),
                  onTap: () => ref
                      .read(settingsProvider.notifier)
                      .toggleSoundwaveLanguage(code),
                ),
            ],
          ),
        ),
      ],
      builder: (context, controller, _) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => controller.isOpen ? controller.close() : controller.open(),
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0x0FFFFFFF),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0x14FFFFFF)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.globe, size: 12, color: Color(0xB3FFFFFF)),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                      color: Color(0xB3FFFFFF),
                      fontSize: 11,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LangChip extends StatelessWidget {
  final String code;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  const _LangChip({
    required this.code,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = ScTheme.paletteOf(context).accent;
    final glow = ScTheme.paletteOf(context).accentGlow;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? glow : const Color(0x0AFFFFFF),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
                color: selected ? accent.withValues(alpha: 0.5) : const Color(0x14FFFFFF)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                Icon(LucideIcons.check, size: 12, color: accent),
                const SizedBox(width: 4),
              ],
              Text(
                name,
                style: TextStyle(
                  color: selected ? accent : const Color(0xCCFFFFFF),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
