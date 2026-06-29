import 'package:flutter/material.dart';
import 'package:sc_visual/sc_visual.dart';

import 'offline_model.dart';

/// Тулбар манифеста: коллекции (лайки/кэш), транспорт, поиск, сортировка.
class OfflineToolbar extends StatelessWidget {
  final OfflineSection section;
  final ValueChanged<OfflineSection> onSection;
  final int likesCount;
  final int cachedCount;
  final int playableCount;
  final VoidCallback onPlayAll;
  final VoidCallback onShuffle;
  final String query;
  final ValueChanged<String> onQuery;
  final SortMode sort;
  final ValueChanged<SortMode> onSort;

  const OfflineToolbar({
    super.key,
    required this.section,
    required this.onSection,
    required this.likesCount,
    required this.cachedCount,
    required this.playableCount,
    required this.onPlayAll,
    required this.onShuffle,
    required this.query,
    required this.onQuery,
    required this.sort,
    required this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    final canPlay = playableCount > 0;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: const Color(0x05FFFFFF),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: const Color(0x14FFFFFF)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _tab(OfflineSection.likes, 'Лайки', likesCount),
              const SizedBox(width: 2),
              _tab(OfflineSection.cached, 'Кэш', cachedCount),
            ],
          ),
        ),
        _PlayAllButton(enabled: canPlay, onTap: onPlayAll),
        _GhostButton(
          enabled: canPlay,
          icon: LucideIcons.shuffle,
          label: 'Вперемешку',
          onTap: onShuffle,
        ),
        const _Spring(),
        _SearchField(query: query, onQuery: onQuery),
        _SortMenu(section: section, sort: sort, onSort: onSort),
      ],
    );
  }

  Widget _tab(OfflineSection key, String label, int count) {
    final active = section == key;
    return _TabButton(
      active: active,
      onTap: () => onSection(key),
      label: label,
      count: count,
    );
  }
}

/// Распорка: толкает поиск+сортировку вправо в Wrap (полная ширина строки).
class _Spring extends StatelessWidget {
  const _Spring();

  @override
  Widget build(BuildContext context) => const SizedBox(width: double.infinity);
}

class _TabButton extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  final String label;
  final int count;

  const _TabButton({
    required this.active,
    required this.onTap,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: active ? const Color(0x14FFFFFF) : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: active ? const Color(0xEBFFFFFF) : const Color(0x80FFFFFF),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$count',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0x59FFFFFF),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayAllButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _PlayAllButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = ScTheme.paletteOf(context);
    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
        child: GestureDetector(
          onTap: enabled ? onTap : null,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: palette.accent,
              borderRadius: BorderRadius.circular(11),
              boxShadow: [
                BoxShadow(
                    color: palette.accentGlow, blurRadius: 22, offset: const Offset(0, 6)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.play, size: 16, color: palette.accentContrast),
                const SizedBox(width: 8),
                Text(
                  'Слушать всё',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: palette.accentContrast,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GhostButton extends StatefulWidget {
  final bool enabled;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _GhostButton({
    required this.enabled,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_GhostButton> createState() => _GhostButtonState();
}

class _GhostButtonState extends State<_GhostButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final on = widget.enabled;
    final color = _hover && on ? const Color(0xE6FFFFFF) : const Color(0x99FFFFFF);
    return Opacity(
      opacity: on ? 1 : 0.35,
      child: MouseRegion(
        cursor: on ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: on ? widget.onTap : null,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0x08FFFFFF),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                  color: _hover && on ? const Color(0x24FFFFFF) : const Color(0x14FFFFFF)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, size: 13, color: color),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w600, color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final String query;
  final ValueChanged<String> onQuery;

  const _SearchField({required this.query, required this.onQuery});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: SearchInput(
        initialValue: query,
        hintText: 'Поиск',
        pill: false,
        debounce: const Duration(milliseconds: 200),
        onChanged: onQuery,
        onCleared: () => onQuery(''),
      ),
    );
  }
}

class _SortMenu extends StatelessWidget {
  final OfflineSection section;
  final SortMode sort;
  final ValueChanged<SortMode> onSort;

  const _SortMenu({
    required this.section,
    required this.sort,
    required this.onSort,
  });

  String _label(SortMode m) => switch (m) {
        SortMode.custom =>
          section == OfflineSection.likes ? 'По лайканью' : 'Свой порядок',
        SortMode.recent => 'Недавние',
        SortMode.title => 'Название',
        SortMode.artist => 'Артист',
        SortMode.duration => 'Длительность',
        SortMode.size => 'Размер',
      };

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<SortMode>(
      tooltip: '',
      position: PopupMenuPosition.under,
      color: const Color(0xFF161618),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0x14FFFFFF)),
      ),
      onSelected: onSort,
      itemBuilder: (context) => [
        for (final m in SortMode.values)
          PopupMenuItem(
            value: m,
            height: 38,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _label(m),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: m == sort
                          ? const Color(0xEBFFFFFF)
                          : const Color(0x8CFFFFFF),
                    ),
                  ),
                ),
                if (m == sort)
                  Icon(LucideIcons.check,
                      size: 12, color: ScTheme.paletteOf(context).accent),
              ],
            ),
          ),
      ],
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0x08FFFFFF),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: const Color(0x14FFFFFF)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Сорт · ',
                style: TextStyle(fontSize: 12, color: Color(0x8CFFFFFF))),
            Text(_label(sort),
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xD9FFFFFF))),
            const SizedBox(width: 6),
            const Icon(LucideIcons.chevronDown,
                size: 14, color: Color(0x8CFFFFFF)),
          ],
        ),
      ),
    );
  }
}
