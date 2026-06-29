import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../providers.dart';
import '../../rust/dto.dart';
import 'collection_body.dart';
import 'history_row.dart';

/// Метки секций истории по дате (Сегодня / Вчера / Ранее) + кнопка очистки.
class HistoryLabels {
  final String today;
  final String yesterday;
  final String earlier;
  final String clear;

  const HistoryLabels({
    required this.today,
    required this.yesterday,
    required this.earlier,
    required this.clear,
  });
}

/// Раздел «История»: строки сгруппированы по дате, виртуализированный список,
/// кнопка очистки (легаси `HistoryTab`). Возвращает сливеры для страничного
/// `CustomScrollView`.
List<Widget> historyTabSlivers(
  BuildContext context,
  WidgetRef ref, {
  required String emptyMessage,
  required HistoryLabels labels,
}) {
  final value = ref.watch(historyProvider);
  final notifier = ref.read(historyProvider.notifier);
  final paged = value.value;
  final entries = paged?.items ?? const <HistoryEntryDto>[];
  final hasMore = paged?.hasMore ?? false;
  final loadingMore = paged?.loadingMore ?? false;

  final rows = _buildRows(entries, labels);

  return [
    if (entries.isNotEmpty)
      SliverToBoxAdapter(
        child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: HistoryClearButton(
              label: labels.clear,
              // Реальное удаление: ядро чистит историю и сам инвалидирует
              // historyProvider (см. SocialController.clearHistory).
              onTap: () => ref.read(socialControllerProvider).clearHistory(),
            ),
          ),
        ),
      ),
    ...collectionBodySlivers(
      state: value,
      hasItems: rows.isNotEmpty,
      filtered: false,
      hasMore: hasMore,
      loadingMore: loadingMore,
      emptyMessage: emptyMessage,
      noMatchesMessage: emptyMessage,
      onLoadMore: notifier.loadMore,
      content: () => [
        VirtualList<_HistoryRow>(
          items: rows,
          rowHeight: 60,
          overscan: 10,
          getItemKey: (r, _) => ValueKey(r.key),
          renderItem: (context, row, _) => row.header != null
              ? HistorySectionHeader(label: row.header!)
              : HistoryEntryRow(entry: row.entry!),
        ).sliver(context),
      ],
    ),
  ];
}

/// Плоский список «заголовок секции | запись» (легаси date-группировка).
List<_HistoryRow> _buildRows(
  List<HistoryEntryDto> entries,
  HistoryLabels labels,
) {
  final rows = <_HistoryRow>[];
  String? current;
  for (final e in entries) {
    final label = _sectionLabel(e.playedAt, labels);
    if (label != current) {
      current = label;
      rows.add(_HistoryRow.header(label));
    }
    rows.add(_HistoryRow.entry(e));
  }
  return rows;
}

String _sectionLabel(String playedAt, HistoryLabels labels) {
  final d = DateTime.tryParse(playedAt)?.toLocal();
  if (d == null) return labels.earlier;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  if (!d.isBefore(today)) return labels.today;
  if (!d.isBefore(yesterday)) return labels.yesterday;
  return labels.earlier;
}

class _HistoryRow {
  final String? header;
  final HistoryEntryDto? entry;

  const _HistoryRow.header(String label)
      : header = label,
        entry = null;
  const _HistoryRow.entry(this.entry) : header = null;

  String get key => header != null ? 'h:$header' : 'e:${entry!.id}';
}
