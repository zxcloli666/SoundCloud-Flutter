import 'package:flutter/material.dart';
import 'package:sc_visual/sc_visual.dart';

/// Тон штампа строки манифеста.
enum OfflineStampTone { raw, forge, preview, missing }

/// Мини-штамп статуса файла (RAW / ГОРН / ОБРЕЗОК / НЕТ ФАЙЛА).
///
/// Примечание: RAW в легаси — пунктирная рамка; Flutter `Border` не умеет
/// пунктир из коробки, поэтому здесь сплошная (визуальный гэп, не функция).
class OfflineStamp extends StatelessWidget {
  final OfflineStampTone tone;
  final String label;

  const OfflineStamp({super.key, required this.tone, required this.label});

  @override
  Widget build(BuildContext context) {
    final palette = ScTheme.paletteOf(context);
    final (Color? bg, Color border, Color color) = switch (tone) {
      OfflineStampTone.raw =>
        (null, const Color(0x2EFFFFFF), const Color(0x73FFFFFF)),
      OfflineStampTone.forge =>
        (palette.accentGlow, palette.accentGlow, palette.accentHover),
      OfflineStampTone.preview =>
        (const Color(0x14FBBF24), const Color(0x66FBBF24), const Color(0xE6FDE68A)),
      OfflineStampTone.missing =>
        (null, const Color(0x14FFFFFF), const Color(0x40FFFFFF)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.3,
          color: color,
        ),
      ),
    );
  }
}

/// Кнопка hover-рельсы строки (Play / Download / Remove): 29×29 стекло, на
/// hover подсвечивается в [hoverColor]. `onTap == null` ⇒ задизейблена.
class OfflineRailButton extends StatefulWidget {
  final IconData icon;
  final Color hoverColor;
  final VoidCallback? onTap;

  const OfflineRailButton({
    super.key,
    required this.icon,
    required this.hoverColor,
    required this.onTap,
  });

  @override
  State<OfflineRailButton> createState() => _OfflineRailButtonState();
}

class _OfflineRailButtonState extends State<OfflineRailButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final on = widget.onTap != null;
    return MouseRegion(
      cursor: on ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Opacity(
          opacity: on ? 1 : 0.4,
          child: Container(
            width: 29,
            height: 29,
            decoration: BoxDecoration(
              color: const Color(0x0DFFFFFF),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                  color: _hover && on
                      ? widget.hoverColor.withValues(alpha: 0.4)
                      : const Color(0x1FFFFFFF)),
            ),
            child: Icon(
              widget.icon,
              size: 14,
              color: _hover && on ? widget.hoverColor : const Color(0x8CFFFFFF),
            ),
          ),
        ),
      ),
    );
  }
}
