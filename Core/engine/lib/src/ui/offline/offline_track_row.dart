import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../providers.dart';
import '../../rust/api.dart';
import 'offline_model.dart';
import 'offline_row_parts.dart';

const double offlineRowHeight = 56;

/// Колонки манифеста: № · трек · штампы(md+) · вес · время.
const _cols = [28.0, null, 88.0, 64.0];

/// Строка офлайн-библиотеки (56px): артворк-кнопка, тайтл/артист или прогресс
/// скачки, штампы (RAW/forging/preview/missing), вес, длительность; hover —
/// рельса действий (Play/Download · Remove). В forging-режиме — акцентная вуаль.
class OfflineTrackRow extends ConsumerStatefulWidget {
  final OfflineEntry entry;
  final int index;
  final bool sortable;
  final bool likesSection;
  final bool forging;
  final double? downloadProgress;
  final ValueChanged<OfflineEntry> onPlay;
  final ValueChanged<OfflineEntry> onDownload;
  final ValueChanged<String> onRemove;
  final Widget? grip;

  const OfflineTrackRow({
    super.key,
    required this.entry,
    required this.index,
    required this.likesSection,
    required this.forging,
    required this.onPlay,
    required this.onDownload,
    required this.onRemove,
    this.sortable = false,
    this.downloadProgress,
    this.grip,
  });

  @override
  ConsumerState<OfflineTrackRow> createState() => _OfflineTrackRowState();
}

class _OfflineTrackRowState extends ConsumerState<OfflineTrackRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final perf = PerfProfile.of(context);
    final entry = widget.entry;
    final track = _resolved(entry);
    final inv = entry.inv;
    final cached = entry.cached;
    final downloading = widget.downloadProgress != null;
    final truncated = isTruncated(inv);
    final isCurrent = ref.watch(playerProvider)?.urn == entry.urn;
    final dimmed = !cached && widget.likesSection;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Opacity(
        opacity: dimmed ? 0.6 : 1,
        child: SizedBox(
          height: offlineRowHeight,
          child: Stack(
            children: [
              if (widget.forging) _forgingVeil(perf),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: _hover && !widget.forging ? const Color(0x08FFFFFF) : null,
                  border: const Border(
                      bottom: BorderSide(color: Color(0x0BFFFFFF))),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(left: 8, right: 16),
                  child: Row(
                    children: [
                      SizedBox(width: _cols[0], child: _numCol()),
                      const SizedBox(width: 12),
                      Expanded(child: _trackCol(track, cached, downloading, isCurrent)),
                      const SizedBox(width: 12),
                      _stampsCol(track, inv, truncated, downloading),
                      const SizedBox(width: 12),
                      SizedBox(width: _cols[2], child: _weightCol(inv)),
                      const SizedBox(width: 12),
                      SizedBox(width: _cols[3], child: _timeCol(entry, track, truncated)),
                    ],
                  ),
                ),
              ),
              if (_hover) Positioned.fill(child: _actionRail(cached, downloading)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _forgingVeil(PerfProfile perf) {
    final palette = ScTheme.paletteOf(context);
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(color: palette.accent.withValues(alpha: 0.18)),
          ),
          Positioned(
            left: 0,
            top: 8,
            bottom: 8,
            child: Container(
              width: 2,
              decoration: BoxDecoration(
                color: palette.accent,
                borderRadius: BorderRadius.circular(2),
                boxShadow: perf.glow
                    ? [BoxShadow(color: palette.accentGlow, blurRadius: 12)]
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _numCol() {
    if (widget.sortable && _hover && widget.grip != null) return widget.grip!;
    return Center(
      child: Text(
        '${widget.index + 1}',
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 11,
          color: Color(0x40FFFFFF),
        ),
      ),
    );
  }

  /// Кэш-строка (`lazy`) знает только urn — догружаем тайтл/арт по нему через
  /// `trackProvider`; пока нет данных, остаётся плейсхолдер по id.
  TrackDto _resolved(OfflineEntry entry) {
    if (!entry.lazy) return entry.track;
    return ref.watch(trackProvider(entry.urn)).value ?? entry.track;
  }

  /// Плейсхолдер ещё не сменился реальными метаданными — рисуем как stub.
  bool _isStub(OfflineEntry entry, TrackDto track) =>
      entry.stub || (entry.lazy && identical(track, entry.track));

  Widget _trackCol(TrackDto track, bool cached, bool downloading, bool isCurrent) {
    final title = track.title;
    final stub = _isStub(widget.entry, track);
    final palette = ScTheme.paletteOf(context);
    return Row(
      children: [
        _artButton(track, cached, downloading),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.1,
                  fontWeight: FontWeight.w500,
                  fontFamily: stub ? 'monospace' : null,
                  color: isCurrent
                      ? palette.accent
                      : stub
                          ? const Color(0x8CFFFFFF)
                          : const Color(0xE0FFFFFF),
                ),
              ),
              const SizedBox(height: 3),
              if (downloading)
                _progressBar()
              else
                Text(
                  widget.forging ? 'плавится в горне' : track.artistName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.1,
                    color: widget.forging
                        ? palette.accentHover
                        : const Color(0x66FFFFFF),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _artButton(TrackDto track, bool cached, bool downloading) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () =>
            cached ? widget.onPlay(widget.entry) : widget.onDownload(widget.entry),
        child: SizedBox(
          width: 38,
          height: 38,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                TrackArtwork(url: track.artworkUrl, size: ArtSize.row),
                if (downloading) const ColoredBox(color: Color(0x8C000000)),
                if (_hover)
                  ColoredBox(
                    color: const Color(0x73000000),
                    child: Icon(
                      cached ? LucideIcons.play : LucideIcons.download,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _progressBar() {
    return Container(
      width: 150,
      height: 2,
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(1),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: (widget.downloadProgress ?? 0).clamp(0.0, 1.0),
        child: Container(color: const Color(0xFF38BDF8)),
      ),
    );
  }

  Widget _stampsCol(
      TrackDto track, CacheInventoryEntry? inv, bool truncated, bool downloading) {
    final meta = _meta(track);
    final stamps = <Widget>[
      if (meta != null) QualityBadge(meta: meta),
      if (inv?.stage == CacheStage.raw && !widget.forging)
        const OfflineStamp(tone: OfflineStampTone.raw, label: 'RAW'),
      if (widget.forging)
        const OfflineStamp(tone: OfflineStampTone.forge, label: 'ГОРН'),
      if (truncated)
        const OfflineStamp(tone: OfflineStampTone.preview, label: 'ОБРЕЗОК'),
      if (!widget.entry.cached && widget.likesSection && !downloading)
        const OfflineStamp(tone: OfflineStampTone.missing, label: 'НЕТ ФАЙЛА'),
    ];
    if (stamps.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < stamps.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          stamps[i],
        ],
      ],
    );
  }

  Widget _weightCol(CacheInventoryEntry? inv) {
    return Text(
      inv != null ? formatBytes(inv.bytes) : '—',
      textAlign: TextAlign.right,
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 12,
        color: Color(0x66FFFFFF),
      ),
    );
  }

  Widget _timeCol(OfflineEntry entry, TrackDto track, bool truncated) {
    // lazy-кэш: длительность из резолва, не из плейсхолдера (0).
    final ms = entry.inv?.durationMs ?? track.durationMs.toInt();
    return Text(
      formatDuration(ms),
      textAlign: TextAlign.right,
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 12,
        color: truncated ? const Color(0xE6FDE68A) : const Color(0x59FFFFFF),
      ),
    );
  }

  Widget _actionRail(bool cached, bool downloading) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.only(left: 56, right: 16),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0x000F0F12), Color(0xF7121216)],
            stops: [0, 0.4],
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (cached)
              OfflineRailButton(
                icon: LucideIcons.play,
                hoverColor: ScTheme.paletteOf(context).accentHover,
                onTap: () => widget.onPlay(widget.entry),
              )
            else
              OfflineRailButton(
                icon: downloading ? Icons.hourglass_top_rounded : LucideIcons.download,
                hoverColor: const Color(0xFFBAE6FD),
                onTap: downloading ? null : () => widget.onDownload(widget.entry),
              ),
            const SizedBox(width: 6),
            if (cached)
              OfflineRailButton(
                icon: LucideIcons.trash2,
                hoverColor: const Color(0xFFFDA4AF),
                onTap: () => widget.onRemove(widget.entry.urn),
              ),
          ],
        ),
      ),
    );
  }
}

ScdMeta? _meta(TrackDto t) {
  if (t.storageState == null && t.indexState == null && t.storageQuality == null) {
    return null;
  }
  return ScdMeta(
    storageState: t.storageState,
    storageQuality: t.storageQuality,
    indexState: t.indexState,
  );
}
