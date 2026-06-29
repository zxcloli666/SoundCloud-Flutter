import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../providers.dart';
import '../../rust/dto.dart';

/// Заголовок секции истории (Сегодня / Вчера / Ранее), легаси `h3` uppercase.
class HistorySectionHeader extends StatelessWidget {
  final String label;

  const HistorySectionHeader({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: ScTokens.textTertiary, // white/30
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}

/// Строка истории (60px): обложка с play-оверлеем, кликабельные title/artist,
/// время. Тап по обложке резолвит трек по urn и играет.
class HistoryEntryRow extends ConsumerStatefulWidget {
  final HistoryEntryDto entry;

  const HistoryEntryRow({super.key, required this.entry});

  @override
  ConsumerState<HistoryEntryRow> createState() => _HistoryEntryRowState();
}

class _HistoryEntryRowState extends ConsumerState<HistoryEntryRow> {
  bool _hover = false;

  String get _urn {
    final id = widget.entry.scTrackId;
    return id.startsWith('soundcloud:tracks:') ? id : 'soundcloud:tracks:$id';
  }

  Future<void> _play() async {
    final messenger = ToastScope.maybeOf(context);
    final track = await ref.read(trackProvider(_urn).future);
    if (track == null) return;
    try {
      await ref.read(playerProvider.notifier).play(track);
    } catch (e) {
      messenger?.show('Не удалось воспроизвести: $e', kind: ToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final time = _timeLabel(e.playedAt);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: ScTokens.dSidebar,
        curve: ScTokens.easeApple,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: _hover ? const Color(0x0AFFFFFF) : const Color(0x00000000),
          borderRadius: BorderRadius.circular(ScTokens.rCard),
        ),
        child: Row(
          children: [
            _Cover(entry: e, hover: _hover, onTap: _play),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Link(
                    text: e.title,
                    title: true,
                    onTap: () =>
                        ref.read(routerProvider.notifier).push(TrackRoute(_urn)),
                  ),
                  const SizedBox(height: 2),
                  _Link(
                    text: e.artistName,
                    title: false,
                    onTap: e.artistUrn == null
                        ? null
                        : () => ref
                            .read(routerProvider.notifier)
                            .push(UserRoute(e.artistUrn!)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (time != null)
              Text(
                time,
                style: const TextStyle(
                  color: Color(0x33FFFFFF), // white/20
                  fontSize: 11,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  final HistoryEntryDto entry;
  final bool hover;
  final VoidCallback onTap;

  const _Cover({required this.entry, required this.hover, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: SizedBox(
          width: 44,
          height: 44,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(ScTokens.rButton),
            child: Stack(
              fit: StackFit.expand,
              children: [
                TrackArtwork(url: entry.artworkUrl, size: ArtSize.row),
                AnimatedOpacity(
                  opacity: hover ? 1 : 0,
                  duration: ScTokens.dFast,
                  child: const ColoredBox(
                    color: Color(0x66000000), // black/40
                    child: Icon(LucideIcons.play,
                        size: 20, color: Color(0xFFFFFFFF)),
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

/// Кликабельная строка title/artist с hover-подсветкой. Неактивная (нет [onTap])
/// артист-строка не реагирует на курсор.
class _Link extends StatefulWidget {
  final String text;
  final bool title;
  final VoidCallback? onTap;

  const _Link({required this.text, required this.title, this.onTap});

  @override
  State<_Link> createState() => _LinkState();
}

class _LinkState extends State<_Link> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final clickable = widget.onTap != null;
    final Color color;
    if (widget.title) {
      color = _hover ? const Color(0xFFFFFFFF) : const Color(0xE6FFFFFF);
    } else {
      color = _hover ? const Color(0x99FFFFFF) : const Color(0x66FFFFFF); // white/60 : white/40
    }
    return MouseRegion(
      cursor: clickable ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: clickable ? (_) => setState(() => _hover = true) : null,
      onExit: clickable ? (_) => setState(() => _hover = false) : null,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Text(
          widget.text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: widget.title ? 14 : 12,
            fontWeight: widget.title ? FontWeight.w500 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

/// Кнопка очистки истории: hover → red-400 (легаси `Clear history`).
class HistoryClearButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const HistoryClearButton({super.key, required this.label, required this.onTap});

  @override
  State<HistoryClearButton> createState() => _HistoryClearButtonState();
}

class _HistoryClearButtonState extends State<HistoryClearButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Text(
          widget.label,
          style: TextStyle(
            color: _hover ? const Color(0xFFF87171) : const Color(0x4DFFFFFF), // red-400 : white/30
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

String? _timeLabel(String playedAt) {
  final d = DateTime.tryParse(playedAt)?.toLocal();
  if (d == null) return null;
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}
