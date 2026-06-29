import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../providers.dart';
import '../../rust/api.dart';
import 'album_aura.dart';

/// Строка трека альбома (легаси `AlbumTrackRow`). Активная — аура-градиент слева
/// + аура-обводка; ховер — лёгкий tint. Ячейка номера↔play `40×40` (36px
/// аура-круг, контрастная иконка); обложка 40; заголовок/артист; бейдж; лайк;
/// длительность.
class AlbumTrackRow extends ConsumerStatefulWidget {
  final TrackDto track;
  final int position;
  final List<TrackDto> queue;
  final AlbumAura aura;

  const AlbumTrackRow({
    super.key,
    required this.track,
    required this.position,
    required this.queue,
    required this.aura,
  });

  @override
  ConsumerState<AlbumTrackRow> createState() => _AlbumTrackRowState();
}

class _AlbumTrackRowState extends ConsumerState<AlbumTrackRow> {
  bool _hover = false;
  bool _liked = false;
  bool _likedInit = false;

  bool get _isThis => ref.watch(playerProvider)?.urn == widget.track.urn;

  Future<void> _togglePlay() async {
    final notifier = ref.read(playerProvider.notifier);
    try {
      if (_isThis) {
        await notifier.togglePause();
      } else {
        // Контекст очереди = доступные треки альбома (queue-continuation).
        await notifier.play(widget.track, queue: widget.queue);
      }
    } catch (error) {
      if (mounted) {
        ToastScope.of(context).show('Не удалось воспроизвести: $error', kind: ToastKind.error);
      }
    }
  }

  /// Оптимистичный тоггл лайка через [socialControllerProvider] (откат при
  /// ошибке) — мгновенный отклик, без перечитки альбома.
  Future<void> _toggleLike(bool next) async {
    final messenger = ToastScope.maybeOf(context);
    setState(() => _liked = next);
    final social = ref.read(socialControllerProvider);
    try {
      if (next) {
        await social.likeTrack(widget.track.urn);
      } else {
        await social.unlikeTrack(widget.track.urn);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _liked = !next);
      messenger?.show('Не удалось обновить лайк: $e', kind: ToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final aura = widget.aura;
    final t = widget.track;
    if (!_likedInit) {
      _liked = t.userFavorite ?? false;
      _likedInit = true;
    }
    final isThis = _isThis;
    final light = aura.isLight;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: ScTokens.easeLabel,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ScTokens.rCard),
          gradient: isThis
              ? LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [aura.rgba(0.16), aura.rgba(0.04), const Color(0x00000000)],
                  stops: const [0.0, 0.7, 1.0],
                )
              : null,
          color: isThis ? null : (_hover ? const Color(0x0AFFFFFF) : null),
          border: isThis ? Border.all(color: aura.rgba(0.35)) : null,
        ),
        child: Row(
          children: [
            _IndexPlay(
              position: widget.position,
              isThis: isThis,
              hover: _hover,
              aura: aura,
              light: light,
              onTap: _togglePlay,
            ),
            const SizedBox(width: 16),
            _Cover(url: t.artworkUrl, hover: _hover),
            const SizedBox(width: 16),
            Expanded(child: _TitleArtist(track: t, highlight: isThis)),
            const SizedBox(width: 12),
            TrackStatusBadge(
              meta: TrackStatusMeta(
                storageState: t.storageState,
                storageQuality: t.storageQuality,
                indexState: t.indexState,
              ),
            ),
            const SizedBox(width: 8),
            LikeButton(
              liked: _liked,
              size: 32,
              iconSize: 14,
              onToggle: _toggleLike,
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 48,
              child: Text(
                formatDuration(t.durationMs.toInt()),
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: ScTokens.textTertiary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ячейка номера: при наведении/проигрывании — аура-круг с иконкой.
class _IndexPlay extends StatelessWidget {
  final int position;
  final bool isThis;
  final bool hover;
  final AlbumAura aura;
  final bool light;
  final VoidCallback onTap;

  const _IndexPlay({
    required this.position,
    required this.isThis,
    required this.hover,
    required this.aura,
    required this.light,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final showCircle = isThis || hover;
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: showCircle
                ? Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isThis ? aura.rgb : (light ? aura.rgba(0.85) : const Color(0x1FFFFFFF)),
                      border: Border.all(color: aura.rgba(0.3)),
                      boxShadow: isThis
                          ? [BoxShadow(color: aura.rgba(0.5), blurRadius: 24)]
                          : null,
                    ),
                    child: Icon(
                      isThis ? LucideIcons.pause : LucideIcons.play,
                      size: 16,
                      color: aura.contrast,
                    ),
                  )
                : Text(
                    '$position',
                    style: const TextStyle(
                      color: ScTokens.textTertiary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  final String? url;
  final bool hover;

  const _Cover({required this.url, required this.hover});

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: hover ? 1.05 : 1.0,
      duration: ScTokens.dGlass,
      curve: ScTokens.easeApple,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0x14FFFFFF)),
        ),
        clipBehavior: Clip.antiAlias,
        child: TrackArtwork(url: url, size: ArtSize.row),
      ),
    );
  }
}

class _TitleArtist extends StatelessWidget {
  final TrackDto track;
  final bool highlight;

  const _TitleArtist({required this.track, required this.highlight});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          track.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: highlight ? ScTokens.textPrimary : const Color(0xE6FFFFFF),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          track.artistName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: ScTokens.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}
