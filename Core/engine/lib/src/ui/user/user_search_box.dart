import 'package:flutter/material.dart';
import 'package:sc_visual/sc_visual.dart';

/// Inline-поиск контента юзера (легаси `UserSearchBox`): всегда бьёт в нашу базу,
/// поэтому справа бейдж «DB». На followers/following/likes — [enabled]=false.
class UserSearchBox extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  /// «tracks»/«playlists» — подсказка скоупа в placeholder.
  final String scopeLabel;
  final bool enabled;

  const UserSearchBox({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.scopeLabel,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final accent = ScTheme.paletteOf(context).accent;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: enabled ? const Color(0x08FFFFFF) : const Color(0x04FFFFFF),
        borderRadius: BorderRadius.circular(ScTokens.rCard),
        border: Border.all(
          color: enabled ? const Color(0x0DFFFFFF) : const Color(0x08FFFFFF),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(
            LucideIcons.search,
            size: 16,
            color: enabled ? const Color(0x59FFFFFF) : const Color(0x26FFFFFF),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              onChanged: onChanged,
              cursorColor: accent,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: InputBorder.none,
                hintText: enabled ? 'Search $scopeLabel' : 'Search unavailable here',
                hintStyle: TextStyle(
                  color: enabled ? const Color(0x4DFFFFFF) : const Color(0x26FFFFFF),
                  fontSize: 13,
                ),
              ),
            ),
          ),
          if (enabled && controller.text.isNotEmpty)
            _ClearButton(onTap: () {
              controller.clear();
              onChanged('');
            }),
          const SizedBox(width: 6),
          const _DbBadge(),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _ClearButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ClearButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: const SizedBox(
          width: 24,
          height: 24,
          child: Icon(LucideIcons.x, size: 12, color: Color(0x4DFFFFFF)),
        ),
      ),
    );
  }
}

class _DbBadge extends StatelessWidget {
  const _DbBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x0AFFFFFF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x0DFFFFFF)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.hardDrive, size: 9, color: Color(0x66FFFFFF)),
          SizedBox(width: 4),
          Text(
            'DB',
            style: TextStyle(
              color: Color(0x66FFFFFF),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
