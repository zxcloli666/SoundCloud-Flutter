import 'package:flutter/material.dart';
import 'package:sc_visual/sc_visual.dart';

/// Контролы настроек: сегменты, слайдер и премиум-lock элементы (легаси
/// `Segmented`/`RangeSlider`/`PremiumBadge`/`LockedToggle`). Базовые карточки и
/// ряды — в `settings_primitives.dart`.

/// Сегментированный выбор: активный — акцентный градиент + рамка + glow.
class SettingsSegmented<T> extends StatelessWidget {
  final T value;
  final List<SegmentedOption<T>> options;
  final ValueChanged<T> onChanged;
  final int? columns;

  const SettingsSegmented({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.columns,
  });

  @override
  Widget build(BuildContext context) {
    final cols = columns ?? options.length;
    return GridView.count(
      crossAxisCount: cols,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 3.2,
      children: [for (final o in options) _segment(context, o)],
    );
  }

  Widget _segment(BuildContext context, SegmentedOption<T> option) {
    final palette = ScTheme.paletteOf(context);
    final active = option.id == value;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => onChanged(option.id),
        child: AnimatedContainer(
          duration: ScTokens.dFast,
          curve: ScTokens.easeApple,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: active
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [palette.accentGlow, const Color(0x0DFFFFFF)],
                  )
                : null,
            color: active ? null : const Color(0x05FFFFFF),
            border: Border.all(
              color: active ? palette.accent : const Color(0x0DFFFFFF),
            ),
            boxShadow: active ? [BoxShadow(color: palette.accentGlow, blurRadius: 16)] : null,
          ),
          child: Text(
            option.label,
            style: TextStyle(
              color: active ? Colors.white : const Color(0x73FFFFFF),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class SegmentedOption<T> {
  final T id;
  final String label;

  const SegmentedOption(this.id, this.label);
}

/// Акцентный слайдер диапазона (легаси `RangeSlider`, `accent-[var(--accent)]`).
class SettingsSlider extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;

  const SettingsSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.divisions,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ScTheme.paletteOf(context);
    return SliderTheme(
      data: SliderThemeData(
        trackHeight: 4,
        activeTrackColor: palette.accent,
        inactiveTrackColor: const Color(0x1AFFFFFF),
        thumbColor: Colors.white,
        overlayColor: palette.accentGlow,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
      ),
      child: Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        divisions: divisions,
        onChanged: onChanged,
      ),
    );
  }
}

/// «Star»-lock бейдж рядом с премиум-контролом (легаси `PremiumBadge`).
class PremiumLockBadge extends StatelessWidget {
  const PremiumLockBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x338B5CF6), Color(0x1FA855F7)],
        ),
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: const Color(0x40A855F7), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.star_rounded, size: 10, color: Color(0xFFFBBF24)),
          SizedBox(width: 4),
          Text(
            'Star',
            style: TextStyle(
              color: Color(0xCCC4B5FD),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Силуэт выключенного переключателя для премиум-locked контрола (легаси
/// `LockedToggle`).
class LockedToggle extends StatelessWidget {
  const LockedToggle();

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.4,
      child: Container(
        width: 44,
        height: 24,
        decoration: BoxDecoration(
          color: const Color(0x1AFFFFFF),
          borderRadius: BorderRadius.circular(9999),
        ),
        child: const Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.all(2),
            child: SizedBox(
              width: 20,
              height: 20,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
