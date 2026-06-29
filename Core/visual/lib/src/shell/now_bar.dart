import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../glass.dart';
import '../palette.dart';
import '../perf.dart';
import '../theme.dart';
import '../tokens.dart';
import 'now_bar_artwork.dart';
import 'now_bar_controls.dart';
import 'now_bar_data.dart';
import 'now_bar_lane.dart';
import 'now_bar_loading_ring.dart';
import 'now_bar_react.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

export 'now_bar_data.dart';

/// Парящая «жидкая» стеклянная пилюля плеера — реплика легаси `.npb` (§2.4):
/// accent-underglow → док с двойной тенью + loading-ring → изолированный
/// стеклослой (тёмная база + белый градиент + accent-corner-tint + specular) →
/// контент (мета+cues | реакция | sep | транспорт | sep | тулы) → прогресс-дорожка.
///
/// Оверлей `.npb` парит снизу-по-центру с паддингом `11/16/15`; вход — `npb-rise`
/// (opacity + translateY 20→0, 0.7s). Док = `width:max-content`, не растягивается.
///
/// Данные — [NowBarData]; управление — [NowBarCallbacks]. Прямые
/// `onPlayPause/onPrev/onNext/onSeek` оставлены для обратной совместимости и
/// перекрывают одноимённые поля [callbacks].
class NowBar extends StatefulWidget {
  final NowBarData data;
  final NowBarCallbacks callbacks;
  final VoidCallback? onPlayPause;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final ValueChanged<double>? onSeek;

  const NowBar({
    super.key,
    required this.data,
    this.callbacks = const NowBarCallbacks(),
    this.onPlayPause,
    this.onPrev,
    this.onNext,
    this.onSeek,
  });

  @override
  State<NowBar> createState() => _NowBarState();
}

class _NowBarState extends State<NowBar> with SingleTickerProviderStateMixin {
  bool _hover = false;

  // Вход `npb-rise` (0.7s ease-apple): прозрачность + подъём translateY 20→0.
  late final AnimationController _rise = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void initState() {
    super.initState();
    _rise.forward();
  }

  @override
  void dispose() {
    _rise.dispose();
    super.dispose();
  }

  NowBarData get data => widget.data;
  NowBarCallbacks get callbacks => widget.callbacks;
  VoidCallback? get _playPause => widget.onPlayPause ?? callbacks.onPlayPause;
  VoidCallback? get _prev => widget.onPrev ?? callbacks.onPrev;
  VoidCallback? get _next => widget.onNext ?? callbacks.onNext;
  ValueChanged<double>? get _seek => widget.onSeek ?? callbacks.onSeek;

  @override
  Widget build(BuildContext context) {
    final perf = ScPerf.of(context);
    final palette = ScTheme.paletteOf(context);

    final pill = MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          if (perf != PerfMode.light) _underglow(palette),
          _dock(context, perf, palette),
        ],
      ),
    );

    return AnimatedBuilder(
      animation: _rise,
      builder: (context, child) {
        final t = ScTokens.easeApple.transform(_rise.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, 20 * (1 - t)), child: child),
        );
      },
      child: pill,
    );
  }

  Widget _underglow(ScPalette palette) {
    final glow = data.isLoading ? palette.accentGlow.withValues(alpha: 0.32) : palette.accentGlow;
    // Свечение во всю ширину дока (Stack размером с док), с лёгким выносом за края.
    return Positioned(
      left: -12,
      right: -12,
      bottom: 0,
      height: 64,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: _hover ? 1.0 : 0.85,
          duration: const Duration(milliseconds: 400),
          curve: ScTokens.easeApple,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.bottomCenter,
                  radius: 0.9,
                  colors: [glow, palette.accent.withValues(alpha: 0)],
                  stops: const [0.0, 0.72],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dock(BuildContext context, PerfMode perf, ScPalette palette) {
    final radius = BorderRadius.circular(ScTokens.rNowBar);
    final glowSpread = data.isLoading ? -10.0 : -18.0;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          const BoxShadow(color: Color(0xC7000000), blurRadius: 70, spreadRadius: -22, offset: Offset(0, 30)),
          BoxShadow(color: palette.accentGlow, blurRadius: data.isLoading ? 90 : 64, spreadRadius: glowSpread),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            Positioned.fill(child: _glass(perf, palette)),
            Container(
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(color: const Color(0x1CFFFFFF)), // white .11
              ),
              // Док = ширина контента (легаси `.npb { width: max-content }`):
              // ширину диктует верхний ряд, дорожка тянется под неё. IntrinsicWidth
              // требует поддеревья без LayoutBuilder (см. NowBarLane/volume).
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
                child: IntrinsicWidth(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _row(context),
                      const SizedBox(height: 7),
                      NowBarLane(
                        positionSecs: data.positionSecs,
                        positionListenable: data.positionListenable,
                        durationSecs: data.durationSecs,
                        abLoopA: data.abLoopA,
                        abLoopB: data.abLoopB,
                        onSeek: _seek,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // .npb-glass inset shadows: верхний specular hairline (white .2)
            // и нижняя внутренняя тень (`0 -10px 26px -18px black .7 inset`).
            const Positioned(
              left: 1,
              right: 1,
              top: 0,
              child: SizedBox(height: 1, child: ColoredBox(color: Color(0x33FFFFFF))),
            ),
            Positioned(
              left: 1,
              right: 1,
              bottom: 1,
              child: IgnorePointer(
                child: Container(
                  height: 26,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(ScTokens.rNowBar - 1),
                      bottomRight: Radius.circular(ScTokens.rNowBar - 1),
                    ),
                    gradient: const LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Color(0x59000000), Color(0x00000000)], // black ~.35 → 0
                    ),
                  ),
                ),
              ),
            ),
            if (data.isLoading)
              Positioned.fill(
                child: NowBarLoadingRing(loadPercent: data.loadPercent, radius: ScTokens.rNowBar),
              ),
          ],
        ),
      ),
    );
  }

  Widget _glass(PerfMode perf, ScPalette palette) {
    final spec = GlassSpec.of(GlassVariant.nowBar, perf);
    final base = spec.tintColor;

    Widget layers = Stack(
      children: [
        Positioned.fill(child: ColoredBox(color: base)),
        if (spec.overlayGradient != null)
          Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: spec.overlayGradient))),
        // `.npb-glass::before` — accent-tint в левом-верхнем углу
        // (radial 120% 180% at 6% 0%, glow→transparent 42%), opacity 0.5.
        if (perf != PerfMode.light)
          Positioned.fill(
            child: Opacity(
              opacity: 0.5,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.88, -1),
                    radius: 1.5,
                    colors: [palette.accentGlow, palette.accent.withValues(alpha: 0)],
                    stops: const [0.0, 0.42],
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    if (spec.blur > 0) {
      layers = BackdropFilter(filter: ImageFilter.blur(sigmaX: spec.blur, sigmaY: spec.blur), child: layers);
    }
    return layers;
  }

  Widget _row(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 1040;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _meta(compact),
        const SizedBox(width: 8),
        NowBarReactCluster(
          liked: data.liked,
          disliked: data.disliked,
          quality: data.quality,
          source: data.source,
          onLike: callbacks.onLike,
          onDislike: callbacks.onDislike,
        ),
        const _Sep(),
        _transport(),
        const _Sep(),
        _tools(compact),
      ],
    );
  }

  Widget _meta(bool compact) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: compact ? 112 + 60 : 150 + 60),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          NowBarArtwork(
            artworkUrl: data.artworkUrl,
            playing: data.playing,
            loading: data.isLoading,
            loadPercent: data.loadPercent,
            onTap: callbacks.onArtworkTap,
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: callbacks.onTitleTap,
                  child: MouseRegion(
                    cursor: callbacks.onTitleTap == null ? MouseCursor.defer : SystemMouseCursors.click,
                    child: Text(
                      data.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xF2FFFFFF),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  data.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0x80FFFFFF),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _transport() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        NowBarIconButton(
          icon: LucideIcons.shuffle,
          active: data.shuffle,
          onTap: callbacks.onShuffle,
          tooltip: 'Shuffle',
        ),
        NowBarIconButton(
          icon: LucideIcons.skipBack,
          size: 36,
          iconSize: 20,
          onTap: _prev,
          tooltip: 'Previous',
        ),
        NowBarPlayOrb(playing: data.playing, onTap: _playPause),
        NowBarIconButton(
          icon: LucideIcons.skipForward,
          size: 36,
          iconSize: 20,
          onTap: _next,
          tooltip: 'Next',
        ),
        NowBarIconButton(
          icon: data.repeat == NowBarRepeat.one ? LucideIcons.repeat1 : LucideIcons.repeat,
          active: data.repeat != NowBarRepeat.off,
          onTap: callbacks.onRepeat,
          tooltip: 'Repeat',
        ),
        NowBarIconButton(
          icon: Icons.sync_alt_rounded,
          active: data.abLoopActive,
          onTap: callbacks.onAbLoop,
          tooltip: 'A-B loop',
          showDot: data.abLoopAwaitingB,
          dotPulse: data.abLoopAwaitingB,
        ),
      ],
    );
  }

  Widget _tools(bool compact) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        NowBarIconButton(icon: LucideIcons.sliders, onTap: callbacks.onTuning, tooltip: 'Tuning'),
        NowBarIconButton(icon: LucideIcons.audioLines, onTap: callbacks.onEqualizer, tooltip: 'Equalizer'),
        NowBarIconButton(icon: LucideIcons.mic, onTap: callbacks.onLyrics, tooltip: 'Lyrics'),
        NowBarIconButton(icon: LucideIcons.listMusic, onTap: callbacks.onQueue, tooltip: 'Queue'),
        NowBarIconButton(
          icon: _volumeIcon(),
          active: data.muted,
          onTap: callbacks.onMuteToggle,
          tooltip: 'Volume',
        ),
        if (!compact) _volumeSlider(),
      ],
    );
  }

  IconData _volumeIcon() {
    if (data.muted || data.volume <= 0) return LucideIcons.volumeX;
    if (data.volume < 1.0) return LucideIcons.volume1;
    return LucideIcons.volume2;
  }

  Widget _volumeSlider() {
    return _NowBarVolume(volume: data.muted ? 0 : data.volume, onChanged: callbacks.onVolume);
  }
}

/// Компактный волюм-слайдер 72px (`.npb-vol-slider`, скрыт под 1040px). Диапазон
/// 0..200% (буст за 100% — янтарный), как в Tauri: трек растёт на ховере, ползунок
/// проявляется на ховере, по центру — риска 100%. [volume] — доля 0..2 (1.0=100%).
class _NowBarVolume extends StatefulWidget {
  final double volume;
  final ValueChanged<double>? onChanged;

  const _NowBarVolume({required this.volume, this.onChanged});

  @override
  State<_NowBarVolume> createState() => _NowBarVolumeState();
}

class _NowBarVolumeState extends State<_NowBarVolume> {
  static const double _width = 72.0;
  static const double _max = 2.0; // 200%
  static const Color _amber = Color(0xFFFBBF24); // amber-400 (буст >100%)

  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final fraction = (widget.volume / _max).clamp(0.0, 1.0);
    final boosted = widget.volume > 1.0;
    final fill = boosted ? _amber.withValues(alpha: 0.8) : const Color(0x99FFFFFF);
    final trackHeight = _hover ? 4.0 : 3.0;

    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _set(d.localPosition.dx),
          onHorizontalDragUpdate: (d) => _set(d.localPosition.dx),
          child: SizedBox(
            width: _width,
            height: 20,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Трек + заполнение.
                SizedBox(
                  width: _width,
                  height: trackHeight,
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0x14FFFFFF),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: fraction,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: fill,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Риска 100% по центру (max=200).
                const Positioned(
                  left: _width / 2,
                  child: SizedBox(
                    width: 1,
                    height: 4,
                    child: ColoredBox(color: Color(0x33FFFFFF)),
                  ),
                ),
                // Ползунок — проявляется на ховере.
                Positioned(
                  left: (fraction * _width - 5).clamp(0.0, _width - 10),
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 150),
                    scale: _hover ? 1.0 : 0.0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: boosted ? _amber : Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _set(double dx) {
    final onChanged = widget.onChanged;
    if (onChanged == null) return;
    onChanged((dx / _width).clamp(0.0, 1.0) * _max);
  }
}

/// Вертикальный разделитель `.npb-sep` (1px, градиент-волосок).
class _Sep extends StatelessWidget {
  const _Sep();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 30,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00FFFFFF), Color(0x29FFFFFF), Color(0x00FFFFFF)],
        ),
      ),
    );
  }
}
