import 'package:flutter/material.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../rust/api.dart';
import 'sequence_row.dart';

/// Секвенция — виртуализированный треклист. Все получают play-on-hover,
/// now-playing подсветку и жанровые hue-тики; владелец — кнопку удаления и
/// перетаскивание строк (грип слева вместо hue-тика). Рендерит ТОЛЬКО видимые
/// строки внутри общего скролла страницы (shrinkWrap + NeverScrollable).
class SequenceList extends StatelessWidget {
  static const _rowHeight = 68.0;

  final List<TrackDto> tracks;
  final bool isOwner;
  final String? currentUrn;
  final bool playing;
  final bool hasMore;
  final bool loadingMore;
  final void Function(int index) onPlayAt;
  final void Function(String urn) onRemove;

  /// Новый порядок urn после drop (только владелец). `null` — сортировка off.
  final void Function(List<String> orderedUrns)? onReorder;

  const SequenceList({
    super.key,
    required this.tracks,
    required this.isOwner,
    required this.currentUrn,
    required this.playing,
    required this.hasMore,
    required this.loadingMore,
    required this.onPlayAt,
    required this.onRemove,
    this.onReorder,
  });

  bool get _sortable => isOwner && onReorder != null && tracks.length > 1;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      radius: 32, // rounded-[2rem]
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _header(),
          if (tracks.isEmpty)
            _empty()
          else if (_sortable)
            _reorderable()
          else
            _virtual(),
          if (hasMore)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: loadingMore
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: ScTokens.textTertiary,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
        ],
      ),
    );
  }

  /// Только-чтение / не-владелец: видимые строки без drag-рукоятки.
  Widget _virtual() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemExtent: _rowHeight,
      itemCount: tracks.length,
      itemBuilder: (context, i) => _row(i),
    );
  }

  /// Владелец: перетаскиваемые строки. `onReorderItem` отдаёт newIndex уже с
  /// поправкой на изъятый элемент — переставляем urn и отдаём порядок наверх.
  Widget _reorderable() {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: tracks.length,
      onReorderItem: (oldIndex, newIndex) {
        if (newIndex == oldIndex) return;
        final urns = tracks.map((t) => t.urn).toList();
        urns.insert(newIndex, urns.removeAt(oldIndex));
        onReorder!(urns);
      },
      proxyDecorator: (child, _, __) =>
          Material(color: Colors.transparent, child: child),
      itemBuilder: (context, i) => SizedBox(
        key: ValueKey(tracks[i].urn),
        height: _rowHeight,
        child: _row(
          i,
          grip: ReorderableDragStartListener(
            index: i,
            child: const Center(
              child: Icon(LucideIcons.gripVertical,
                  size: 14, color: Color(0x73FFFFFF)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(int i, {Widget? grip}) {
    final t = tracks[i];
    final isThis = currentUrn != null && t.urn == currentUrn;
    return SequenceRow(
      track: t,
      index: i + 1,
      isCurrent: isThis,
      isPlaying: isThis && playing,
      isOwner: isOwner,
      grip: grip,
      onPlay: () => onPlayAt(i),
      onRemove: () => onRemove(t.urn),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Row(
        children: [
          const Icon(LucideIcons.listMusic, size: 12, color: Color(0x8CFFFFFF)),
          const SizedBox(width: 8),
          const Text(
            'THE SEQUENCE',
            style: TextStyle(
              color: Color(0x8CFFFFFF),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.4,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${tracks.length}',
            style: const TextStyle(
              color: Color(0x40FFFFFF),
              fontSize: 11,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const Spacer(),
          const Icon(LucideIcons.clock, size: 12, color: Color(0x40FFFFFF)),
        ],
      ),
    );
  }

  Widget _empty() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 64),
      child: Column(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0x08FFFFFF),
              borderRadius: BorderRadius.all(Radius.circular(ScTokens.rCard)),
              border: Border.fromBorderSide(BorderSide(color: Color(0x0FFFFFFF), width: 0.5)),
            ),
            child: SizedBox(
              width: 64,
              height: 64,
              child: Icon(LucideIcons.listMusic, size: 24, color: Color(0x26FFFFFF)),
            ),
          ),
          SizedBox(height: 16),
          Text(
            'This crate is empty',
            style: TextStyle(color: Color(0x4DFFFFFF), fontSize: 14),
          ),
        ],
      ),
    );
  }
}
