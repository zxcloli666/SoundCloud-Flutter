import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../rust/api.dart';
import 'artist_aura.dart';
import 'tab_segmented.dart';
import 'tab_states.dart';
import 'themed_track_row.dart';
import 'wanted_rows.dart';
import 'year_marker.dart';

enum TracksSort { popular, recent }

enum TracksView { list, years }

/// Вкладка треков артиста (§3.9 `ArtistTracksTab`). Источник — список треков
/// (primary из пагинированного провайдера / featured из `popular_tracks`),
/// сортировка/группировка по году считаются на клиенте. Тоглы Sort + View,
/// раздел «coming soon» для `wanted`-треков, виртуализованный список.
class ArtistTracksTab extends ConsumerStatefulWidget {
  final List<TrackDto> tracks;
  final ArtistAura aura;
  final bool isLoading;
  final String emptyLabel;
  final bool showSort;

  const ArtistTracksTab({
    super.key,
    required this.tracks,
    required this.aura,
    required this.emptyLabel,
    this.isLoading = false,
    this.showSort = true,
  });

  @override
  ConsumerState<ArtistTracksTab> createState() => _ArtistTracksTabState();
}

class _ArtistTracksTabState extends ConsumerState<ArtistTracksTab> {
  static const _rowHeight = 72.0;

  TracksSort _sort = TracksSort.popular;
  TracksView _view = TracksView.list;

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) return const TabLoader();
    if (widget.tracks.isEmpty) {
      return TabEmpty(icon: LucideIcons.music, label: widget.emptyLabel);
    }

    final available = <TrackDto>[];
    final wanted = <TrackDto>[];
    for (final t in widget.tracks) {
      // Бридж не несёт enrichment.availability; «wanted» приближаем по отсутствию
      // storage (трек не в хранилище → ещё не доступен на стрим).
      if ((t.storageState == null || t.storageState == 'missing') && t.indexState == null) {
        wanted.add(t);
      } else {
        available.add(t);
      }
    }

    final sorted = _applySort(available);
    final totalMs = widget.tracks.fold<int>(0, (acc, t) => acc + t.durationMs.toInt());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showSort) ...[
          _toolbar(sorted.length, totalMs),
          const SizedBox(height: 20),
        ],
        if (_view == TracksView.list)
          _list(sorted)
        else
          _years(sorted),
        if (wanted.isNotEmpty) ...[
          const SizedBox(height: 24),
          ComingSoonSection(wanted: wanted, aura: widget.aura),
        ],
      ],
    );
  }

  List<TrackDto> _applySort(List<TrackDto> tracks) {
    final out = [...tracks];
    if (_sort == TracksSort.recent || _view == TracksView.years) {
      out.sort((a, b) => _releaseKey(b).compareTo(_releaseKey(a)));
    } else {
      out.sort((a, b) => (b.playCount?.toInt() ?? 0).compareTo(a.playCount?.toInt() ?? 0));
    }
    return out;
  }

  int _releaseKey(TrackDto t) {
    final y = t.releaseYear;
    if (y != null && y > 1900) return y * 10000;
    return DateTime.tryParse(t.createdAt ?? '')?.millisecondsSinceEpoch ?? 0;
  }

  Widget _toolbar(int count, int totalMs) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TabSegmented<TracksSort>(
              aura: widget.aura.primary,
              value: _sort,
              disabled: _view == TracksView.years,
              options: const [
                SegmentedOption(value: TracksSort.popular, label: 'Популярные'),
                SegmentedOption(value: TracksSort.recent, label: 'Свежие'),
              ],
              onChanged: (v) => setState(() => _sort = v),
            ),
            const SizedBox(width: 8),
            TabSegmented<TracksView>(
              aura: widget.aura.primary,
              value: _view,
              options: const [
                SegmentedOption(value: TracksView.list, label: 'Список', icon: LucideIcons.listMusic),
                SegmentedOption(value: TracksView.years, label: 'Годы', icon: Icons.calendar_today_rounded),
              ],
              onChanged: (v) => setState(() => _view = v),
            ),
          ],
        ),
        Text(
          '${formatCount(count)} · ${formatDuration(totalMs)}',
          style: const TextStyle(
            color: Color(0x4DFFFFFF),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.8,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  /// Виртуализованный список фиксированной высоты строки (как легаси VirtualList).
  Widget _list(List<TrackDto> tracks) {
    return ListView.builder(
      shrinkWrap: true,
      primary: false,
      physics: const NeverScrollableScrollPhysics(),
      itemExtent: _rowHeight,
      itemCount: tracks.length,
      itemBuilder: (context, i) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: ThemedTrackRow(
          track: tracks[i],
          index: i + 1,
          queue: tracks,
          aura: widget.aura,
        ),
      ),
    );
  }

  Widget _years(List<TrackDto> tracks) {
    final buckets = _groupByYear(tracks);
    final flat = buckets.expand((b) => b.tracks).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final b in buckets) ...[
          _yearBlock(b, flat),
          const SizedBox(height: 40),
        ],
      ],
    );
  }

  Widget _yearBlock(_YearBucket bucket, List<TrackDto> queue) {
    final total = bucket.tracks.fold<int>(0, (acc, t) => acc + t.durationMs.toInt());
    final label = bucket.year != null
        ? 'Год выхода · ${bucket.tracks.length} · ${formatDuration(total)}'
        : 'Без даты · ${bucket.tracks.length} · ${formatDuration(total)}';
    return YearMarkerRow(
      year: bucket.year,
      sublabel: label,
      aura: widget.aura,
      children: [
        for (var i = 0; i < bucket.tracks.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: ThemedTrackRow(
              track: bucket.tracks[i],
              index: i + 1,
              queue: queue,
              aura: widget.aura,
            ),
          ),
      ],
    );
  }

  List<_YearBucket> _groupByYear(List<TrackDto> tracks) {
    final map = <int?, List<TrackDto>>{};
    for (final t in tracks) {
      final y = (t.releaseYear != null && t.releaseYear! > 1900) ? t.releaseYear : null;
      (map[y] ??= []).add(t);
    }
    final known = map.entries.where((e) => e.key != null).toList()
      ..sort((a, b) => (b.key ?? 0).compareTo(a.key ?? 0));
    final out = [for (final e in known) _YearBucket(e.key, e.value)];
    final undated = map[null];
    if (undated != null && undated.isNotEmpty) out.add(_YearBucket(null, undated));
    return out;
  }
}

class _YearBucket {
  final int? year;
  final List<TrackDto> tracks;
  const _YearBucket(this.year, this.tracks);
}
