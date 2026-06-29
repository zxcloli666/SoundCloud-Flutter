import 'package:flutter/material.dart';

class SegmentedOption<T> {
  final T value;
  final String label;
  final IconData? icon;

  const SegmentedOption({required this.value, required this.label, this.icon});
}

/// Сегментный тогл вкладок артиста (легаси `SortToggle`/`ViewToggle`): стеклянный
/// контейнер, активный сегмент — градиент ауры. Меньше TabDock — для локальных
/// переключателей (Sort/View) без скользящей пилюли.
class TabSegmented<T> extends StatelessWidget {
  final T value;
  final List<SegmentedOption<T>> options;
  final ValueChanged<T> onChanged;
  final Color aura;
  final bool disabled;

  const TabSegmented({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.aura,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.4 : 1,
      child: IgnorePointer(
        ignoring: disabled,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0x08FFFFFF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x0FFFFFFF)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final o in options) _segment(o),
            ],
          ),
        ),
      ),
    );
  }

  Widget _segment(SegmentedOption<T> o) {
    final active = o.value == value;
    return GestureDetector(
      onTap: () => onChanged(o.value),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: active
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [aura.withValues(alpha: 0.22), aura.withValues(alpha: 0.06)],
                  )
                : null,
            border: active ? Border.all(color: aura.withValues(alpha: 0.35), width: 0.5) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (o.icon != null) ...[
                Icon(o.icon, size: 13, color: active ? Colors.white : const Color(0x66FFFFFF)),
                const SizedBox(width: 6),
              ],
              Text(
                o.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : const Color(0x66FFFFFF),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
