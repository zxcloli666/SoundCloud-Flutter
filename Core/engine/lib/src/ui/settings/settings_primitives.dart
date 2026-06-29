import 'package:flutter/material.dart';
import 'package:sc_visual/sc_visual.dart';

export 'settings_controls.dart';

/// Единый визуальный язык настроек (легаси `components/settings/primitives.tsx`):
/// карточка-секция, ряды и переключатель. Сегменты/слайдер/lock — в
/// `settings_controls.dart` (реэкспортируются отсюда).

/// Карточка-секция: `rounded-3xl p-6` стекло blur 40 + акцентная иконка-тайл и
/// верхняя specular-хайрлайн (легаси `Card`). Hover поднимает яркость рамки.
class SettingsCard extends StatefulWidget {
  final String title;
  final String? description;
  final IconData? icon;
  final Widget? action;
  final Widget child;

  const SettingsCard({
    super.key,
    required this.title,
    required this.child,
    this.description,
    this.icon,
    this.action,
  });

  @override
  State<SettingsCard> createState() => _SettingsCardState();
}

class _SettingsCardState extends State<SettingsCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final palette = ScTheme.paletteOf(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: ScTokens.dGlass,
        curve: ScTokens.easeApple,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24), // rounded-3xl
          gradient: const LinearGradient(
            begin: Alignment(0.4, -1),
            end: Alignment(-0.4, 1),
            colors: [Color(0x0EFFFFFF), Color(0x04FFFFFF), Color(0x08FFFFFF)],
            stops: [0, 0.58, 1],
          ),
          border: Border.all(
            color: _hover ? const Color(0x24FFFFFF) : const Color(0x1AFFFFFF),
            width: 0.5,
          ),
          boxShadow: const [
            BoxShadow(color: Color(0x66000000), blurRadius: 50, offset: Offset(0, 18)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              const Positioned(left: 24, right: 24, top: 0, child: SpecularHairline.subtle()),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _header(palette),
                    const SizedBox(height: 20),
                    widget.child,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(ScPalette palette) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.icon != null) ...[
          AccentIconTile(icon: widget.icon!, size: 36, iconSize: 17),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  color: Color(0xD9FFFFFF),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              if (widget.description != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    widget.description!,
                    style: const TextStyle(
                      color: Color(0x59FFFFFF),
                      fontSize: 11.5,
                      height: 1.3,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (widget.action != null) widget.action!,
      ],
    );
  }
}

/// Акцентная иконка-тайл (легаси header icon-box): стеклянный квадрат, тонкая
/// акцентная рамка и glow в beauty.
class AccentIconTile extends StatelessWidget {
  final IconData icon;
  final double size;
  final double iconSize;

  const AccentIconTile({
    super.key,
    required this.icon,
    this.size = 36,
    this.iconSize = 17,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ScTheme.paletteOf(context);
    final glow = ScPerf.of(context) == PerfMode.beauty;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size >= 44 ? 16 : 12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.accentGlow, const Color(0x0AFFFFFF)],
        ),
        border: Border.all(color: palette.accentGlow, width: 0.5),
        boxShadow: glow
            ? [BoxShadow(color: palette.accentGlow, blurRadius: size >= 44 ? 26 : 18)]
            : null,
      ),
      child: Icon(icon, size: iconSize, color: palette.accent),
    );
  }
}

/// Ряд настройки: заголовок (+опц. описание) слева, контрол справа (легаси `Row`).
class SettingsRow extends StatelessWidget {
  final Widget title;
  final String? description;
  final Widget? trailing;

  const SettingsRow({
    super.key,
    required this.title,
    this.description,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DefaultTextStyle.merge(
                  style: const TextStyle(
                    color: Color(0xCCFFFFFF),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                  child: title,
                ),
                if (description != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      description!,
                      style: const TextStyle(
                        color: Color(0x59FFFFFF),
                        fontSize: 11.5,
                        height: 1.3,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 16),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// Тонкая разделительная линия между рядами (легаси `divide-y`).
class SettingsDivider extends StatelessWidget {
  const SettingsDivider();

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, thickness: 1, color: Color(0x0DFFFFFF));
}

/// Переключатель `w-11 h-6`: включён = акцентный трек + glow, иначе `white/10`;
/// кнопка скользит (легаси `Toggle`).
class SettingsToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool disabled;

  const SettingsToggle({
    super.key,
    required this.value,
    this.onChanged,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ScTheme.paletteOf(context);
    final on = value && !disabled;
    return Opacity(
      opacity: disabled ? 0.4 : 1,
      child: MouseRegion(
        cursor: disabled ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
        child: GestureDetector(
          onTap: disabled || onChanged == null ? null : () => onChanged!(!value),
          child: AnimatedContainer(
            duration: ScTokens.dFast,
            curve: ScTokens.easeApple,
            width: 44,
            height: 24,
            decoration: BoxDecoration(
              color: on ? palette.accent : const Color(0x1AFFFFFF),
              borderRadius: BorderRadius.circular(9999),
              boxShadow: on ? [BoxShadow(color: palette.accentGlow, blurRadius: 16)] : null,
            ),
            child: AnimatedAlign(
              duration: ScTokens.dFast,
              curve: ScTokens.easeApple,
              alignment: on ? Alignment.centerRight : Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: on ? palette.accentContrast : Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(color: Color(0x40000000), blurRadius: 4, offset: Offset(0, 1)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
