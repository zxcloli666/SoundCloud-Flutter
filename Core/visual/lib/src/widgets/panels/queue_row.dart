import 'package:flutter/material.dart';

import '../../image_proxy.dart';
import '../../theme.dart';
import '../../tokens.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Строка очереди (легаси `QueueRow`): lead-ячейка (номер ↔ grip на hover),
/// 36px обложка с playing-оверлеем для текущего, тайтл/артист, длительность,
/// remove на hover. Презентационная; перенос делает родительский reorder-список.
class QueueRow extends StatefulWidget {
  /// 1-based позиция в "up next" (или 0 для now-playing — номер скрыт).
  final int position;
  final String title;
  final String artistLine;
  final String? artworkUrl;
  final String durationLabel;
  final bool isCurrent;
  final bool isPlaying;

  /// Текущий трек или now-playing-карточка не таскаются — скрывает grip.
  final bool reorderable;

  /// `_scd_meta`-бейдж качества/состояния (легаси `TrackStatusBadges`), уже
  /// собранный вызывающим. Сидит между телом и длительностью; null — скрыт.
  final Widget? badge;

  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  const QueueRow({
    super.key,
    required this.position,
    required this.title,
    required this.artistLine,
    this.artworkUrl,
    required this.durationLabel,
    required this.isCurrent,
    required this.isPlaying,
    this.reorderable = true,
    this.badge,
    this.onTap,
    this.onRemove,
  });

  @override
  State<QueueRow> createState() => _QueueRowState();
}

class _QueueRowState extends State<QueueRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final accent = ScTheme.paletteOf(context).accent;
    final current = widget.isCurrent;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
        decoration: BoxDecoration(
          color: current
              ? const Color(0x14FFFFFF)
              : (_hover ? const Color(0x0DFFFFFF) : const Color(0x00000000)),
          borderRadius: BorderRadius.circular(ScTokens.rButton),
          border: current ? Border.all(color: const Color(0x14FFFFFF)) : null,
        ),
        child: Row(
          children: [
            _lead(),
            const SizedBox(width: 10),
            _artwork(accent),
            const SizedBox(width: 10),
            Expanded(child: _body(accent)),
            if (widget.badge != null) ...[
              const SizedBox(width: 8),
              widget.badge!,
            ],
            const SizedBox(width: 8),
            Text(
              widget.durationLabel,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0x33FFFFFF),
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            _remove(),
          ],
        ),
      ),
    );
  }

  Widget _lead() {
    final showGrip = widget.reorderable && _hover;
    return SizedBox(
      width: 20,
      child: Center(
        child: showGrip
            ? const Icon(LucideIcons.gripVertical, size: 14, color: Color(0x73FFFFFF))
            : Text(
                '${widget.position}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0x33FFFFFF),
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
      ),
    );
  }

  Widget _artwork(Color accent) {
    final radius = BorderRadius.circular(8);
    final placeholder = DecoratedBox(
      decoration: BoxDecoration(color: const Color(0x0AFFFFFF), borderRadius: radius),
    );
    return SizedBox(
      width: 36,
      height: 36,
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (widget.artworkUrl != null)
              Image(
                image: ScImageProxy.provider(widget.artworkUrl!),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => placeholder,
              )
            else
              placeholder,
            if (widget.isCurrent) _PlayingOverlay(playing: widget.isPlaying, accent: accent),
          ],
        ),
      ),
    );
  }

  Widget _body(Color accent) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            height: 1.3,
            fontWeight: widget.isCurrent ? FontWeight.w500 : FontWeight.w400,
            color: widget.isCurrent ? accent : const Color(0xCCFFFFFF),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          widget.artistLine,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10, color: Color(0x4DFFFFFF)),
        ),
      ],
    );
  }

  Widget _remove() {
    final visible = _hover && widget.onRemove != null;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: visible ? 1 : 0,
      child: IgnorePointer(
        ignoring: !visible,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: widget.onRemove,
            child: const SizedBox(
              width: 24,
              height: 24,
              child: Icon(LucideIcons.x, size: 12, color: Color(0x40FFFFFF)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Оверлей играющего трека: 3 accent-бара с пульсом (паузы 0/150/300ms) или
/// глиф паузы. Подложка `black/45` (легаси `PlayingOverlay`).
class _PlayingOverlay extends StatefulWidget {
  final bool playing;
  final Color accent;

  const _PlayingOverlay({required this.playing, required this.accent});

  @override
  State<_PlayingOverlay> createState() => _PlayingOverlayState();
}

class _PlayingOverlayState extends State<_PlayingOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;

  // Базовые высоты баров (легаси 12 / 8 / 14) и фазовые сдвиги пульса.
  static const _heights = [12.0, 8.0, 14.0];
  static const _delays = [0.0, 0.15, 0.3];

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    if (widget.playing) _ctl.repeat();
  }

  @override
  void didUpdateWidget(_PlayingOverlay old) {
    super.didUpdateWidget(old);
    if (widget.playing && !_ctl.isAnimating) {
      _ctl.repeat();
    } else if (!widget.playing && _ctl.isAnimating) {
      _ctl.stop();
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0x73000000),
      child: Center(
        child: widget.playing
            ? Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(width: 2),
                    _bar(i),
                  ],
                ],
              )
            : Icon(LucideIcons.pause, size: 12, color: const Color(0xE6FFFFFF)),
      ),
    );
  }

  Widget _bar(int i) {
    return AnimatedBuilder(
      animation: _ctl,
      builder: (_, __) {
        final phase = (_ctl.value + _delays[i]) % 1.0;
        // animate-pulse: opacity 1 → 0.5 → 1 (Tailwind).
        final opacity = 0.5 + 0.5 * (1 - (phase * 2 - 1).abs());
        return Opacity(
          opacity: opacity,
          child: Container(
            width: 2,
            height: _heights[i],
            decoration: BoxDecoration(
              color: widget.accent,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      },
    );
  }
}
