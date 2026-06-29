import 'package:flutter/material.dart';
import 'package:sc_visual/sc_visual.dart';

/// Категории настроек (легаси `registry.tsx`), сведённые к разделам, которые
/// движок отдаёт без платформенных портов (язык/старт, вид, аудио, хранилище,
/// аккаунт, о приложении). Сеть/Discord — десктоп-онли, опущены.
enum SettingsCategory { general, appearance, audio, storage, account, about }

extension SettingsCategoryMeta on SettingsCategory {
  IconData get icon => switch (this) {
        SettingsCategory.general => LucideIcons.languages,
        SettingsCategory.appearance => LucideIcons.sparkles,
        SettingsCategory.audio => LucideIcons.headphones,
        SettingsCategory.storage => LucideIcons.hardDrive,
        SettingsCategory.account => LucideIcons.user,
        SettingsCategory.about => LucideIcons.info,
      };

  String get label => switch (this) {
        SettingsCategory.general => 'Основные',
        SettingsCategory.appearance => 'Вид',
        SettingsCategory.audio => 'Звук',
        SettingsCategory.storage => 'Хранилище',
        SettingsCategory.account => 'Аккаунт',
        SettingsCategory.about => 'О приложении',
      };
}

/// Левый рельс — sticky frosted-панель из category-pill, подсвеченных акцентом
/// (легаси `SettingsNav`). 212px, скрывается на узких окнах (адаптив).
class SettingsNav extends StatelessWidget {
  final SettingsCategory active;
  final ValueChanged<SettingsCategory> onChanged;

  const SettingsNav({super.key, required this.active, required this.onChanged});

  static const double width = 212;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: GlassPanel(
        radius: 28, // rounded-[1.75rem]
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final c in SettingsCategory.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _NavPill(
                  category: c,
                  active: c == active,
                  onTap: () => onChanged(c),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavPill extends StatefulWidget {
  final SettingsCategory category;
  final bool active;
  final VoidCallback onTap;

  const _NavPill({
    required this.category,
    required this.active,
    required this.onTap,
  });

  @override
  State<_NavPill> createState() => _NavPillState();
}

class _NavPillState extends State<_NavPill> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final palette = ScTheme.paletteOf(context);
    final on = widget.active;
    final glow = ScPerf.of(context) == PerfMode.beauty;
    final fg = on
        ? Colors.white
        : _hover
            ? const Color(0xD9FFFFFF)
            : const Color(0x73FFFFFF);
    final iconColor = on
        ? palette.accent
        : _hover
            ? const Color(0xB3FFFFFF)
            : const Color(0x66FFFFFF);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: ScTokens.dFast,
          curve: ScTokens.easeApple,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16), // rounded-2xl
            gradient: on
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [palette.accentGlow, const Color(0x0FFFFFFF)],
                  )
                : null,
            color: on
                ? null
                : _hover
                    ? const Color(0x0DFFFFFF)
                    : null,
            boxShadow: on && glow ? [BoxShadow(color: palette.accentGlow, blurRadius: 22)] : null,
          ),
          child: Stack(
            children: [
              if (on)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Container(
                      width: 3,
                      height: 20,
                      decoration: BoxDecoration(
                        color: palette.accent,
                        borderRadius: BorderRadius.circular(9999),
                        boxShadow: glow ? [BoxShadow(color: palette.accent, blurRadius: 10)] : null,
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(left: 14, right: 12),
                child: Row(
                  children: [
                    Icon(widget.category.icon, size: 17, color: iconColor),
                    const SizedBox(width: 12),
                    Text(
                      widget.category.label,
                      style: TextStyle(
                        color: fg,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
