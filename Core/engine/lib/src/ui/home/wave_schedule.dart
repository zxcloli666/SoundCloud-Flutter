import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../rust/api.dart';
import 'shared.dart';

const _scheduleSize = 10;
const _brookCap = 6;
const _freshWindow = Duration(days: 14);

/// «Волна» — программа эфира: плотный нумерованный список в 2 колонки (легаси
/// `WaveSchedule`). Каждая строка — номер · обложка-кнопка · название/артист ·
/// like (hover) · длительность; играющая строка подсвечена акцентом.
class WaveSchedule extends StatelessWidget {
  final List<TrackDto> tracks;
  final String? currentUrn;

  const WaveSchedule({super.key, required this.tracks, required this.currentUrn});

  @override
  Widget build(BuildContext context) {
    final items = tracks.take(_scheduleSize).toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoCol = constraints.maxWidth >= 720;
        if (!twoCol) {
          return Column(
            children: [
              for (var i = 0; i < items.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: ScheduleRow(
                    track: items[i],
                    index: i,
                    currentUrn: currentUrn,
                  ),
                ),
            ],
          );
        }
        final half = (items.length / 2).ceil();
        final left = items.sublist(0, half);
        final right = items.sublist(half);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _column(left, 0)),
            const SizedBox(width: 28),
            Expanded(child: _column(right, half)),
          ],
        );
      },
    );
  }

  Widget _column(List<TrackDto> items, int offset) {
    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: ScheduleRow(
              track: items[i],
              index: offset + i,
              currentUrn: currentUrn,
            ),
          ),
      ],
    );
  }
}

/// «Свежие релизы» — верховья: узкий датированный ручей-список (легаси
/// `ReleaseBrook`). Лидирующая колонка — относительная дата релиза.
class ReleaseBrook extends StatelessWidget {
  final List<TrackDto> tracks;
  final String? currentUrn;

  const ReleaseBrook({super.key, required this.tracks, required this.currentUrn});

  @override
  Widget build(BuildContext context) {
    final items = tracks.take(_brookCap).toList();
    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: ScheduleRow(
              track: items[i],
              index: i,
              currentUrn: currentUrn,
              leading: _relDate(items[i]) ?? '—',
            ),
          ),
      ],
    );
  }
}

bool _isFresh(TrackDto track) {
  final stamp = track.createdAt;
  if (stamp == null) return false;
  final ts = DateTime.tryParse(stamp);
  if (ts == null) return false;
  return DateTime.now().difference(ts) < _freshWindow;
}

String? _relDate(TrackDto track) {
  final stamp = track.createdAt;
  if (stamp == null) return null;
  final ts = DateTime.tryParse(stamp);
  if (ts == null) return null;
  final days = DateTime.now().difference(ts).inDays;
  if (days <= 0) return 'сегодня';
  if (days == 1) return 'вчера';
  const months = [
    'янв', 'фев', 'мар', 'апр', 'мая', 'июн',
    'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
  ];
  return '${ts.day} ${months[ts.month - 1]}';
}

/// Строка расписания: номер/дата · обложка-кнопка · тайтл/артист · like · длит.
class ScheduleRow extends ConsumerStatefulWidget {
  final TrackDto track;
  final int index;
  final String? currentUrn;
  final String? leading;

  const ScheduleRow({
    super.key,
    required this.track,
    required this.index,
    required this.currentUrn,
    this.leading,
  });

  @override
  ConsumerState<ScheduleRow> createState() => _ScheduleRowState();
}

class _ScheduleRowState extends ConsumerState<ScheduleRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final accent = ScTheme.paletteOf(context).accent;
    final t = widget.track;
    final playing = t.urn == widget.currentUrn;
    final fresh = !playing && _isFresh(t);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: ScTokens.dFast,
        padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
        decoration: BoxDecoration(
          color: playing
              ? accent.withValues(alpha: 0.12)
              : (_hover ? const Color(0x09FFFFFF) : Colors.transparent),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: playing
                ? accent.withValues(alpha: 0.4)
                : (_hover ? const Color(0x0FFFFFFF) : Colors.transparent),
          ),
        ),
        child: Row(
          children: [
            if (playing)
              Container(
                width: 2.5,
                height: 28,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            SizedBox(
              width: widget.leading != null ? 44 : 28,
              child: Text(
                widget.leading ?? (widget.index + 1).toString().padLeft(2, '0'),
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: playing ? accent : const Color(0x4DFFFFFF),
                  fontSize: 11,
                  fontFamily: 'monospace',
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: 12),
            _cover(playing),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          t.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xE0FFFFFF),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (fresh) ...[
                        const SizedBox(width: 6),
                        _freshBadge(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    t.artistName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0x66FFFFFF), fontSize: 12),
                  ),
                ],
              ),
            ),
            AnimatedOpacity(
              opacity: _hover ? 1 : 0,
              duration: ScTokens.dFast,
              child: LikeButton(liked: t.userFavorite ?? false, size: 30, iconSize: 15),
            ),
            const SizedBox(width: 4),
            SizedBox(
              width: 38,
              child: Text(
                formatDuration(t.durationMs.toInt()),
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Color(0x4DFFFFFF),
                  fontSize: 11.5,
                  fontFamily: 'monospace',
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cover(bool playing) {
    return GestureDetector(
      onTap: () => playHomeTrack(ref, context, widget.track),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: TrackArtwork(url: widget.track.artworkUrl, size: ArtSize.row),
              ),
              if (_hover || playing)
                Positioned.fill(
                  child: ColoredBox(
                    color: const Color(0x73000000),
                    child: Icon(
                      playing ? LucideIcons.pause : LucideIcons.play,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _freshBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0x1A34D399),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: const Color(0x4D34D399)),
      ),
      child: const Text(
        'NEW',
        style: TextStyle(
          color: Color(0xE634D399),
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
