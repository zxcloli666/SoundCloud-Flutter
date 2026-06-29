import 'package:flutter/material.dart';
import 'package:sc_visual/sc_visual.dart';

import 'offline_model.dart';
import 'offline_track_row.dart';

/// Список-манифест: шапка-сетка + виртуализированные строки. В режиме «Свой
/// порядок» (sortable) строки перетаскиваются. Пусто — пунктирная плашка.
class OfflineTrackList extends StatelessWidget {
  final List<OfflineEntry> entries;
  final bool sortable;
  final bool likesSection;
  final Set<String> forgingUrns;
  final Map<String, double> downloads;
  final String emptyText;
  final ValueChanged<OfflineEntry> onPlay;
  final ValueChanged<OfflineEntry> onDownload;
  final ValueChanged<String> onRemove;
  final ValueChanged<List<String>> onReorder;

  const OfflineTrackList({
    super.key,
    required this.entries,
    required this.sortable,
    required this.likesSection,
    required this.forgingUrns,
    required this.downloads,
    required this.emptyText,
    required this.onPlay,
    required this.onDownload,
    required this.onRemove,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 48),
        decoration: BoxDecoration(
          color: const Color(0x04FFFFFF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x14FFFFFF)),
        ),
        child: Center(
          child: Text(
            emptyText,
            style: const TextStyle(fontSize: 13, color: Color(0x40FFFFFF)),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0x04FFFFFF),
          border: Border.all(color: const Color(0x12FFFFFF)),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            const _ListHead(),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 640),
              child: sortable ? _reorderable() : _virtual(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _virtual() {
    return VirtualList<OfflineEntry>(
      items: entries,
      rowHeight: offlineRowHeight,
      overscan: 8,
      getItemKey: (e, _) => ValueKey(e.urn),
      renderItem: (context, e, i) => _row(e, i),
    );
  }

  /// dnd через ReorderableListView: грип-ячейка таскает строку, drop меняет
  /// канонический порядок кэша. Виртуализирован самим ReorderableListView.
  Widget _reorderable() {
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      itemCount: entries.length,
      onReorderItem: (from, to) {
        final urns = entries.map((e) => e.urn).toList();
        final moved = urns.removeAt(from);
        urns.insert(to, moved);
        onReorder(urns);
      },
      proxyDecorator: (child, index, animation) => Material(
        color: Colors.transparent,
        child: child,
      ),
      itemBuilder: (context, i) {
        final e = entries[i];
        return SizedBox(
          key: ValueKey(e.urn),
          height: offlineRowHeight,
          child: _row(
            e,
            i,
            grip: ReorderableDragStartListener(
              index: i,
              child: const Center(
                child: Icon(LucideIcons.gripVertical,
                    size: 14, color: Color(0x73FFFFFF)),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _row(OfflineEntry e, int i, {Widget? grip}) {
    return OfflineTrackRow(
      entry: e,
      index: i,
      sortable: sortable,
      likesSection: likesSection,
      forging: forgingUrns.contains(e.urn),
      downloadProgress: downloads[e.urn],
      grip: grip,
      onPlay: onPlay,
      onDownload: onDownload,
      onRemove: onRemove,
    );
  }
}

class _ListHead extends StatelessWidget {
  const _ListHead();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontFamily: 'monospace',
      fontSize: 9,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.6,
      color: Color(0x4DFFFFFF),
    );
    return Container(
      height: 32,
      padding: const EdgeInsets.only(left: 8, right: 16),
      decoration: const BoxDecoration(
        color: Color(0x04FFFFFF),
        border: Border(bottom: BorderSide(color: Color(0x12FFFFFF))),
      ),
      child: const Row(
        children: [
          SizedBox(width: 28, child: Center(child: Text('№', style: style))),
          SizedBox(width: 12),
          Expanded(child: Text('ТРЕК', style: style)),
          SizedBox(width: 88, child: Text('ВЕС', textAlign: TextAlign.right, style: style)),
          SizedBox(width: 12),
          SizedBox(width: 64, child: Text('ВРЕМЯ', textAlign: TextAlign.right, style: style)),
        ],
      ),
    );
  }
}
