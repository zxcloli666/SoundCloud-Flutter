import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../image_proxy.dart';
import '../../palette.dart';
import '../../perf.dart';
import '../../theme.dart';
import '../../tokens.dart';
import '../track/track_format.dart';
import 'queue_row.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Элемент очереди (презентационный срез легаси `Track`).
class QueueEntry {
  final String urn;
  final String title;
  final String artistLine;
  final String? artworkUrl;
  final int durationMs;

  /// `_scd_meta`-бейдж (легаси `TrackStatusBadges`), уже собранный вызывающим.
  final Widget? badge;

  const QueueEntry({
    required this.urn,
    required this.title,
    required this.artistLine,
    this.artworkUrl,
    required this.durationMs,
    this.badge,
  });
}

/// Правый стеклянный drawer очереди (легаси `QueuePanel`, 360px). Frost-слой на
/// своём GPU-слое (wallpaper-блюр или плотный фрост), левый accent-edge glow,
/// шапка, NowPlaying-карточка, reorderable "Up Next". Презентационный: список
/// и события приходят параметрами.
class QueuePanel extends StatelessWidget {
  static const double width = 360;

  /// Полная очередь (current + up-next). `currentIndex` — играющий трек.
  final List<QueueEntry> queue;
  final int currentIndex;
  final bool isPlaying;
  final bool open;

  final String title;
  final String clearLabel;
  final String nowPlayingLabel;
  final String upNextLabel;
  final String emptyTitle;
  final String emptyHint;

  /// Картинка обоев под фростом (если задана) — уже разрешённый URL.
  final String? wallpaperUrl;

  final VoidCallback? onClose;
  final VoidCallback? onClear;

  /// Тап по строке: текущий → toggle play/pause, иначе play-from-queue.
  final void Function(int index)? onTapEntry;
  final void Function(int index)? onRemove;

  /// Перенос в очереди (absolute-индексы во всём [queue]).
  final void Function(int from, int to)? onReorder;

  const QueuePanel({
    super.key,
    required this.queue,
    required this.currentIndex,
    required this.isPlaying,
    this.open = true,
    this.title = 'Queue',
    this.clearLabel = 'Clear',
    this.nowPlayingLabel = 'NOW PLAYING',
    this.upNextLabel = 'UP NEXT',
    this.emptyTitle = 'Queue is empty',
    this.emptyHint = 'Tracks you play will appear here.',
    this.wallpaperUrl,
    this.onClose,
    this.onClear,
    this.onTapEntry,
    this.onRemove,
    this.onReorder,
  });

  QueueEntry? get _current =>
      (currentIndex >= 0 && currentIndex < queue.length) ? queue[currentIndex] : null;

  int get _upNextStart => currentIndex + 1;
  int get _upNextCount => queue.length - _upNextStart;

  @override
  Widget build(BuildContext context) {
    final mode = ScPerf.of(context);
    return AnimatedSlide(
      offset: open ? Offset.zero : const Offset(1, 0),
      duration: ScTokens.dSidebar,
      curve: ScTokens.easeApple,
      child: SizedBox(
        width: width,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: ScTokens.glassBorder)),
          ),
          child: Stack(
            children: [
              Positioned.fill(child: _Frost(mode: mode, wallpaperUrl: wallpaperUrl)),
              Positioned.fill(child: _AccentEdge(palette: ScTheme.paletteOf(context))),
              Positioned.fill(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _header(),
                    if (_current != null) _nowPlaying(),
                    Expanded(child: _upNext()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
              color: Color(0xE6FFFFFF),
            ),
          ),
          const SizedBox(width: 10),
          if (queue.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: ScTokens.glassBorder,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${queue.length}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0x66FFFFFF),
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          const Spacer(),
          if (queue.isNotEmpty)
            _ClearButton(label: clearLabel, onTap: onClear),
          _CloseButton(onTap: onClose),
        ],
      ),
    );
  }

  Widget _nowPlaying() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 0, 8),
            child: _SectionLabel(nowPlayingLabel),
          ),
          QueueRow(
            position: 0,
            title: _current!.title,
            artistLine: _current!.artistLine,
            artworkUrl: _current!.artworkUrl,
            durationLabel: formatDuration(_current!.durationMs),
            isCurrent: true,
            isPlaying: isPlaying,
            reorderable: false,
            badge: _current!.badge,
            onTap: () => onTapEntry?.call(currentIndex),
          ),
        ],
      ),
    );
  }

  Widget _upNext() {
    if (queue.isEmpty) return _empty();
    if (_upNextCount <= 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 0, 8),
          child: _SectionLabel('$upNextLabel · $_upNextCount'),
        ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
            buildDefaultDragHandles: false,
            itemCount: _upNextCount,
            // onReorderItem уже отдаёт newLocal с поправкой на изъятый элемент —
            // приводим к absolute from/to во всём queue (как `moveInQueue`).
            onReorderItem: (oldLocal, newLocal) =>
                onReorder?.call(_upNextStart + oldLocal, _upNextStart + newLocal),
            proxyDecorator: (child, _, __) => _DragProxy(child: child),
            itemBuilder: (context, localIdx) {
              final absIdx = _upNextStart + localIdx;
              final entry = queue[absIdx];
              return ReorderableDragStartListener(
                key: ValueKey('${entry.urn}-$absIdx'),
                index: localIdx,
                child: QueueRow(
                  position: localIdx + 1,
                  title: entry.title,
                  artistLine: entry.artistLine,
                  artworkUrl: entry.artworkUrl,
                  durationLabel: formatDuration(entry.durationMs),
                  isCurrent: false,
                  isPlaying: false,
                  reorderable: true,
                  badge: entry.badge,
                  onTap: () => onTapEntry?.call(absIdx),
                  onRemove: () => onRemove?.call(absIdx),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0x0AFFFFFF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ScTokens.glassBorder),
            ),
            alignment: Alignment.center,
            child: const Icon(LucideIcons.listMusic, size: 24, color: Color(0x26FFFFFF)),
          ),
          const SizedBox(height: 12),
          Text(
            emptyTitle,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0x66FFFFFF)),
          ),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Text(
              emptyHint,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, height: 1.5, color: Color(0x33FFFFFF)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Frost-фон drawer: обои (тяжёлый блюр + вуаль) или плотный фрост с backdrop.
class _Frost extends StatelessWidget {
  final PerfMode mode;
  final String? wallpaperUrl;

  const _Frost({required this.mode, required this.wallpaperUrl});

  double get _blur => switch (mode) {
        PerfMode.beauty => 60,
        PerfMode.medium => 26,
        PerfMode.light => 0,
      };

  @override
  Widget build(BuildContext context) {
    final blur = _blur;
    if (wallpaperUrl != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Transform.scale(
            scale: 1.15,
            child: ImageFiltered(
              imageFilter: blur > 0
                  ? ImageFilter.blur(sigmaX: blur, sigmaY: blur)
                  : ImageFilter.blur(sigmaX: 0.001, sigmaY: 0.001),
              child:
                  Image(image: ScImageProxy.provider(wallpaperUrl!), fit: BoxFit.cover),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
                colors: [
                  Color.fromRGBO(14, 14, 18, blur > 0 ? 0.58 : 0.82),
                  Color.fromRGBO(14, 14, 18, blur > 0 ? 0.72 : 0.92),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // rgba(16,16,20, 0.82) под блюром / 0.98 плоско.
    if (blur <= 0) return const ColoredBox(color: Color(0xFA101014));
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
      child: const ColoredBox(color: Color(0xD1101014)),
    );
  }
}

/// Левая accent-кромка (вертикальный градиент, opacity 0.4).
class _AccentEdge extends StatelessWidget {
  final ScPalette palette;

  const _AccentEdge({required this.palette});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0x00000000),
                  palette.accent.withValues(alpha: 0.4),
                  const Color(0x00000000),
                ],
                stops: const [0, 0.45, 1],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.6,
        color: Color(0x40FFFFFF),
      ),
    );
  }
}

class _ClearButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;

  const _ClearButton({required this.label, required this.onTap});

  @override
  State<_ClearButton> createState() => _ClearButtonState();
}

class _ClearButtonState extends State<_ClearButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final fg = _hover ? const Color(0x99FFFFFF) : const Color(0x4DFFFFFF);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: _hover ? const Color(0x0FFFFFFF) : const Color(0x00000000),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.trash2, size: 12, color: fg),
              const SizedBox(width: 6),
              Text(widget.label, style: TextStyle(fontSize: 11, color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CloseButton extends StatefulWidget {
  final VoidCallback? onTap;

  const _CloseButton({required this.onTap});

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: _hover ? const Color(0x0FFFFFFF) : const Color(0x00000000),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Icon(
            LucideIcons.x,
            size: 16,
            color: _hover ? const Color(0x99FFFFFF) : const Color(0x4DFFFFFF),
          ),
        ),
      ),
    );
  }
}

/// Плавающий клон строки во время drag (легаси `QueueRowClone`).
class _DragProxy extends StatelessWidget {
  final Widget child;

  const _DragProxy({required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xF51C1C22),
          borderRadius: BorderRadius.circular(ScTokens.rButton),
          border: Border.all(color: const Color(0x26FFFFFF)),
          boxShadow: const [
            BoxShadow(color: Color(0x8C000000), blurRadius: 50, offset: Offset(0, 20)),
          ],
        ),
        child: child,
      ),
    );
  }
}
