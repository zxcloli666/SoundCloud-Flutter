import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:sc_visual/sc_visual.dart';

/// Поле поиска каталога (легаси §3.3 `SearchInput`): `max-w 320 rounded-2xl`,
/// Search 15 слева, clear-X справа, дебаунс 220ms.
class DiscoverSearchInput extends StatefulWidget {
  final ValueChanged<String> onChanged;

  const DiscoverSearchInput({super.key, required this.onChanged});

  @override
  State<DiscoverSearchInput> createState() => _DiscoverSearchInputState();
}

class _DiscoverSearchInputState extends State<DiscoverSearchInput> {
  final _controller = TextEditingController();
  Timer? _debounce;
  bool _hasText = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    final has = value.isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () {
      widget.onChanged(value.trim());
    });
  }

  void _clear() {
    _controller.clear();
    _onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final blur = PerfProfile.of(context).sigma(20);
    final radius = BorderRadius.circular(ScTokens.rCard);

    Widget field = Container(
      height: 42,
      decoration: BoxDecoration(
        color: blur > 0 ? const Color(0x0AFFFFFF) : const Color(0xE618181C),
        borderRadius: radius,
        border: Border.all(color: const Color(0x0FFFFFFF), width: 0.5),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          const Icon(LucideIcons.search, size: 15, color: Color(0x4DFFFFFF)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              onChanged: _onChanged,
              style: const TextStyle(color: Color(0xD9FFFFFF), fontSize: 13),
              cursorColor: Theme.of(context).colorScheme.primary,
              cursorHeight: 14,
              decoration: const InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'Найти в каталоге',
                hintStyle: TextStyle(color: Color(0x40FFFFFF), fontSize: 13),
              ),
            ),
          ),
          if (_hasText)
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: _clear,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(LucideIcons.x, size: 14, color: Color(0x4DFFFFFF)),
                ),
              ),
            )
          else
            const SizedBox(width: 8),
        ],
      ),
    );

    if (blur > 0) {
      field = ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: field,
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: field,
    );
  }
}
