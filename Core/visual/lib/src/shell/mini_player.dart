import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../glass.dart';
import '../image_proxy.dart';
import '../perf.dart';
import '../theme.dart';
import '../tokens.dart';
import 'now_bar_data.dart';

/// Снимок состояния для мини-плеера трея (1:1 с легаси `tray/state.ts`). Окно-
/// поповер своего плеер-состояния не держит — главный процесс шлёт его по сокету.
class ScMiniPlayerData {
  final bool hasTrack;
  final String title;
  final String artist;
  final String? artworkUrl;
  final bool playing;

  /// Живая позиция (сек) — тикает в отдельный listenable, чтобы не дёргать весь
  /// док каждый тик (перерисовывается только дорожка/время).
  final ValueListenable<double> position;
  final double durationSecs;
  final bool shuffle;
  final NowBarRepeat repeat;
  final bool liked;
  final bool disliked;

  /// Громкость 0..1.
  final double volume;
  final bool muted;

  const ScMiniPlayerData({
    required this.hasTrack,
    required this.title,
    required this.artist,
    required this.position,
    this.artworkUrl,
    this.playing = false,
    this.durationSecs = 0,
    this.shuffle = false,
    this.repeat = NowBarRepeat.off,
    this.liked = false,
    this.disliked = false,
    this.volume = 1,
    this.muted = false,
  });
}

class ScMiniPlayerCallbacks {
  final VoidCallback onPlayPause;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onShuffle;
  final VoidCallback onRepeat;
  final VoidCallback onLike;
  final VoidCallback onDislike;
  final VoidCallback onOpenApp;
  final VoidCallback onClose;
  final ValueChanged<double> onSeek;
  final ValueChanged<double> onVolume;

  const ScMiniPlayerCallbacks({
    required this.onPlayPause,
    required this.onPrev,
    required this.onNext,
    required this.onShuffle,
    required this.onRepeat,
    required this.onLike,
    required this.onDislike,
    required this.onOpenApp,
    required this.onClose,
    required this.onSeek,
    required this.onVolume,
  });
}

/// Стеклянный мини-плеер трея (легаси `tray/MiniPlayer.tsx`): аура обложки за
/// фростом, шапка (арт+мета+развернуть+закрыть), скраббер, транспорт, реакции +
/// громкость. Якорное окно процесса `--miniplayer`.
class ScMiniPlayer extends StatelessWidget {
  final ScMiniPlayerData data;
  final ScMiniPlayerCallbacks callbacks;

  const ScMiniPlayer({super.key, required this.data, required this.callbacks});

  @override
  Widget build(BuildContext context) {
    final perf = PerfProfile.of(context);
    return Padding(
      padding: const EdgeInsets.all(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ScTokens.rCard),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (perf.bloom && data.artworkUrl != null && data.artworkUrl!.isNotEmpty)
              Positioned.fill(child: _Aura(url: data.artworkUrl!)),
            GlassPanel(
              variant: GlassVariant.nowBar,
              radius: ScTokens.rCard,
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _head(context),
                  _MiniScrubber(data: data, onSeek: callbacks.onSeek),
                  _transport(context),
                  _foot(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _head(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: callbacks.onOpenApp,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 46,
              height: 46,
              child: data.artworkUrl != null && data.artworkUrl!.isNotEmpty
                  ? Image(
                      image: ScImageProxy.sized(data.artworkUrl!, 120),
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      errorBuilder: (_, __, ___) => const _ArtFallback(),
                    )
                  : const _ArtFallback(),
            ),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                data.hasTrack ? data.title : 'Ничего не играет',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xF2FFFFFF),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              if (data.hasTrack)
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    data.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0x8CFFFFFF), fontSize: 11.5),
                  ),
                ),
            ],
          ),
        ),
        _IconBtn(icon: LucideIcons.maximize2, size: 15, onTap: callbacks.onOpenApp),
        _IconBtn(icon: LucideIcons.x, size: 16, onTap: callbacks.onClose),
      ],
    );
  }

  Widget _transport(BuildContext context) {
    final palette = ScTheme.paletteOf(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _IconBtn(
          icon: LucideIcons.shuffle,
          size: 16,
          active: data.shuffle,
          onTap: callbacks.onShuffle,
        ),
        _IconBtn(icon: LucideIcons.skipBack, size: 19, onTap: callbacks.onPrev),
        GestureDetector(
          onTap: callbacks.onPlayPause,
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: palette.accent,
              boxShadow: PerfProfile.of(context).glow
                  ? [BoxShadow(color: palette.accentGlow, blurRadius: 18)]
                  : null,
            ),
            child: Icon(
              data.playing ? LucideIcons.pause : LucideIcons.play,
              size: 20,
              color: palette.accentContrast,
            ),
          ),
        ),
        _IconBtn(icon: LucideIcons.skipForward, size: 19, onTap: callbacks.onNext),
        _IconBtn(
          icon: data.repeat == NowBarRepeat.one ? LucideIcons.repeat1 : LucideIcons.repeat,
          size: 16,
          active: data.repeat != NowBarRepeat.off,
          onTap: callbacks.onRepeat,
        ),
      ],
    );
  }

  Widget _foot(BuildContext context) {
    return Row(
      children: [
        _IconBtn(
          icon: LucideIcons.heart,
          size: 16,
          active: data.liked,
          activeColor: const Color(0xFFFF4D6D),
          filled: data.liked,
          onTap: callbacks.onLike,
        ),
        _IconBtn(
          icon: LucideIcons.thumbsDown,
          size: 16,
          active: data.disliked,
          filled: data.disliked,
          onTap: callbacks.onDislike,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _Volume(
            volume: data.muted ? 0 : data.volume,
            onVolume: callbacks.onVolume,
          ),
        ),
      ],
    );
  }
}

/// Размытая обложка-аура за фростом (тёплый фон вместо плоского постера).
class _Aura extends StatelessWidget {
  final String url;
  const _Aura({required this.url});

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
      child: Opacity(
        opacity: 0.5,
        child: Image(
          image: ScImageProxy.sized(url, 160),
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class _ArtFallback extends StatelessWidget {
  const _ArtFallback();
  @override
  Widget build(BuildContext context) => const ColoredBox(
        color: Color(0x14FFFFFF),
        child: Icon(LucideIcons.music, size: 18, color: Color(0x59FFFFFF)),
      );
}

/// Кнопка-иконка дока: приглушённая, акцент/цвет при активности.
class _IconBtn extends StatelessWidget {
  final IconData icon;
  final double size;
  final bool active;
  final bool filled;
  final Color? activeColor;
  final VoidCallback onTap;

  const _IconBtn({
    required this.icon,
    required this.size,
    required this.onTap,
    this.active = false,
    this.filled = false,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ScTheme.paletteOf(context);
    final color = active
        ? (activeColor ?? palette.accent)
        : const Color(0x99FFFFFF);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(icon, size: size, color: color),
        ),
      ),
    );
  }
}

/// Дорожка прогресса: заливка слушает live-позицию (только она перерисовывается);
/// тап/драг по дорожке → seek.
class _MiniScrubber extends StatefulWidget {
  final ScMiniPlayerData data;
  final ValueChanged<double> onSeek;
  const _MiniScrubber({required this.data, required this.onSeek});

  @override
  State<_MiniScrubber> createState() => _MiniScrubberState();
}

class _MiniScrubberState extends State<_MiniScrubber> {
  double? _dragFrac;

  double _fracFor(double dx, double width) =>
      width <= 0 ? 0 : (dx / width).clamp(0.0, 1.0);

  void _commit(double frac) {
    final d = widget.data.durationSecs;
    if (d > 0) widget.onSeek(frac * d);
  }

  @override
  Widget build(BuildContext context) {
    final palette = ScTheme.paletteOf(context);
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, c) {
            final width = c.maxWidth;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (e) => setState(() => _dragFrac = _fracFor(e.localPosition.dx, width)),
              onTapUp: (e) {
                final f = _fracFor(e.localPosition.dx, width);
                _commit(f);
                setState(() => _dragFrac = null);
              },
              onHorizontalDragUpdate: (e) =>
                  setState(() => _dragFrac = _fracFor(e.localPosition.dx, width)),
              onHorizontalDragEnd: (_) {
                final f = _dragFrac;
                if (f != null) _commit(f);
                setState(() => _dragFrac = null);
              },
              child: SizedBox(
                height: 14,
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: SizedBox(
                      height: 4,
                      width: width,
                      child: Stack(
                        children: [
                          const Positioned.fill(child: ColoredBox(color: Color(0x1AFFFFFF))),
                          ValueListenableBuilder<double>(
                            valueListenable: widget.data.position,
                            builder: (context, pos, _) {
                              final d = widget.data.durationSecs;
                              final frac = _dragFrac ??
                                  (d > 0 ? (pos / d).clamp(0.0, 1.0) : 0.0);
                              return Positioned(
                                left: 0,
                                top: 0,
                                bottom: 0,
                                width: (frac * width).clamp(0.0, width),
                                child: ColoredBox(color: palette.accent),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        _TimeRow(data: widget.data),
      ],
    );
  }
}

class _TimeRow extends StatelessWidget {
  final ScMiniPlayerData data;
  const _TimeRow({required this.data});

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(color: Color(0x73FFFFFF), fontSize: 10.5);
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ValueListenableBuilder<double>(
            valueListenable: data.position,
            builder: (_, pos, __) => Text(_fmt(pos), style: style),
          ),
          Text(_fmt(data.durationSecs), style: style),
        ],
      ),
    );
  }
}

/// Громкость: иконка-мьют + горизонтальная дорожка (драг).
class _Volume extends StatelessWidget {
  final double volume; // 0..1
  final ValueChanged<double> onVolume;
  const _Volume({required this.volume, required this.onVolume});

  @override
  Widget build(BuildContext context) {
    final palette = ScTheme.paletteOf(context);
    final icon = volume == 0
        ? LucideIcons.volumeX
        : volume < 0.5
            ? LucideIcons.volume1
            : LucideIcons.volume2;
    return Row(
      children: [
        _IconBtn(
          icon: icon,
          size: 15,
          onTap: () => onVolume(volume > 0 ? 0 : 0.5),
        ),
        const SizedBox(width: 2),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              final width = c.maxWidth;
              void set(double dx) =>
                  onVolume((dx / width).clamp(0.0, 1.0));
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (e) => set(e.localPosition.dx),
                onHorizontalDragUpdate: (e) => set(e.localPosition.dx),
                child: SizedBox(
                  height: 14,
                  child: Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: SizedBox(
                        height: 4,
                        width: width,
                        child: Stack(
                          children: [
                            const Positioned.fill(
                                child: ColoredBox(color: Color(0x1AFFFFFF))),
                            Positioned(
                              left: 0,
                              top: 0,
                              bottom: 0,
                              width: (volume.clamp(0.0, 1.0)) * width,
                              child: ColoredBox(color: palette.accent),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

String _fmt(double secs) {
  final s = secs.isFinite && secs > 0 ? secs.round() : 0;
  final m = s ~/ 60;
  final r = s % 60;
  return '$m:${r.toString().padLeft(2, '0')}';
}
