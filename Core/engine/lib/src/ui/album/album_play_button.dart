import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../providers.dart';
import '../../rust/api.dart';
import 'album_aura.dart';

/// Большая «играть весь альбом» пилюля (легаси `AlbumPlayButton`). Аура-градиент,
/// контрастный текст/иконка по `aura.isLight`, внутренний 28px круг. Играет
/// только «доступные» треки; пустой набор — disabled.
class AlbumPlayButton extends ConsumerStatefulWidget {
  final List<TrackDto> playable;
  final AlbumAura aura;

  const AlbumPlayButton({super.key, required this.playable, required this.aura});

  @override
  ConsumerState<AlbumPlayButton> createState() => _AlbumPlayButtonState();
}

class _AlbumPlayButtonState extends ConsumerState<AlbumPlayButton> {
  bool _hover = false;
  bool _busy = false;

  bool get _empty => widget.playable.isEmpty;

  /// Текущий трек принадлежит этому альбому?
  bool _isPlayingFromAlbum() {
    final current = ref.read(playerProvider)?.urn;
    if (current == null) return false;
    return widget.playable.any((t) => t.urn == current);
  }

  Future<void> _onTap() async {
    if (_empty || _busy) return;
    final notifier = ref.read(playerProvider.notifier);
    setState(() => _busy = true);
    try {
      if (_isPlayingFromAlbum()) {
        await notifier.togglePause();
      } else {
        // Весь альбом как контекст очереди (queue-continuation): доигрываем
        // доступные треки по порядку, потом волна.
        await notifier.play(widget.playable.first, queue: widget.playable);
      }
    } catch (error) {
      if (mounted) {
        ToastScope.of(context).show('Не удалось воспроизвести: $error', kind: ToastKind.error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final aura = widget.aura;
    final light = aura.isLight;
    final fg = aura.contrast;
    // Слежение за плеером для иконки play/pause.
    ref.watch(playerProvider);
    final playing = _isPlayingFromAlbum();

    return MouseRegion(
      cursor: _empty ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: _onTap,
        child: AnimatedScale(
          scale: _empty ? 1.0 : (_hover ? 1.03 : 1.0),
          duration: ScTokens.dGlass,
          curve: ScTokens.easeApple,
          child: Opacity(
            opacity: _empty ? 0.5 : 1,
            child: Container(
              height: 44,
              padding: const EdgeInsets.only(left: 8, right: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [aura.rgba(0.85), aura.rgba(0.65)],
                ),
                border: Border.all(color: aura.rgba(0.55)),
                boxShadow: [BoxShadow(color: aura.rgba(0.45), blurRadius: 32, offset: const Offset(0, 12))],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: light ? const Color(0x2E000000) : const Color(0x2EFFFFFF),
                      border: Border.all(
                        color: light ? const Color(0x40000000) : const Color(0x40FFFFFF),
                      ),
                    ),
                    child: Icon(playing ? LucideIcons.pause : LucideIcons.play, size: 16, color: fg),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    playing ? 'Пауза' : 'Слушать альбом',
                    style: TextStyle(
                      color: fg,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
