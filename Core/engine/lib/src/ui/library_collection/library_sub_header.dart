import 'package:flutter/material.dart';
import 'package:sc_visual/sc_visual.dart';

/// Шапка раздела библиотеки (легаси `LibrarySubHeader`): назад в хаб, акцентная
/// полоска + заголовок + счётчик, и опциональный фильтр (нет у истории).
class LibrarySubHeader extends StatelessWidget {
  final String title;
  final String backLabel;
  final int? count;
  final VoidCallback onBack;

  /// Текущее значение фильтра и его сеттер. Если [onFilter] == null — поля нет
  /// (история).
  final String? filter;
  final String filterHint;
  final ValueChanged<String>? onFilter;

  const LibrarySubHeader({
    super.key,
    required this.title,
    required this.backLabel,
    required this.onBack,
    required this.count,
    this.filter,
    this.filterHint = '',
    this.onFilter,
  });

  @override
  Widget build(BuildContext context) {
    final accent = ScTheme.paletteOf(context).accent;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BackLink(label: backLabel, onTap: onBack),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 4,
                      height: 28,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(9999),
                        boxShadow: [
                          BoxShadow(color: accent.withValues(alpha: 0.55), blurRadius: 14),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xF2FFFFFF), // white/95
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    if (count != null && count! > 0) ...[
                      const SizedBox(width: 12),
                      Text(
                        formatCount(count!),
                        style: const TextStyle(
                          color: ScTokens.textTertiary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onFilter != null) ...[
                const SizedBox(width: 16),
                _FilterField(
                  value: filter ?? '',
                  hint: filterHint,
                  onChanged: onFilter!,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _BackLink extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _BackLink({required this.label, required this.onTap});

  @override
  State<_BackLink> createState() => _BackLinkState();
}

class _BackLinkState extends State<_BackLink> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedDefaultTextStyle(
          duration: ScTokens.dFast,
          style: TextStyle(
            color: _hover ? const Color(0xD9FFFFFF) : const Color(0x66FFFFFF), // white/85 : white/40
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.chevronLeft,
                size: 15,
                color: _hover ? const Color(0xD9FFFFFF) : const Color(0x66FFFFFF),
              ),
              const SizedBox(width: 2),
              Text(widget.label),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterField extends StatefulWidget {
  final String value;
  final String hint;
  final ValueChanged<String> onChanged;

  const _FilterField({required this.value, required this.hint, required this.onChanged});

  @override
  State<_FilterField> createState() => _FilterFieldState();
}

class _FilterFieldState extends State<_FilterField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value);
  final _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void didUpdateWidget(_FilterField old) {
    super.didUpdateWidget(old);
    // Внешний сброс (clear): синхронизируем контроллер, не теряя курсор.
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final border = _focused ? const Color(0x1FFFFFFF) : const Color(0x0DFFFFFF); // white/12 : white/5
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 320),
      child: AnimatedContainer(
        duration: ScTokens.dFast,
        decoration: BoxDecoration(
          color: _focused ? const Color(0x14FFFFFF) : const Color(0x0AFFFFFF), // white/8 : white/4
          borderRadius: BorderRadius.circular(ScTokens.rButton),
          border: Border.all(color: border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            const Icon(LucideIcons.search, size: 15, color: ScTokens.textTertiary),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                onChanged: widget.onChanged,
                style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 13), // white/80
                cursorColor: ScTheme.paletteOf(context).accent,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: InputBorder.none,
                  hintText: widget.hint,
                  hintStyle: const TextStyle(color: Color(0x40FFFFFF), fontSize: 13), // white/25
                ),
              ),
            ),
            if (widget.value.isNotEmpty)
              GestureDetector(
                onTap: () => widget.onChanged(''),
                child: const MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(LucideIcons.x, size: 14, color: ScTokens.textTertiary),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
