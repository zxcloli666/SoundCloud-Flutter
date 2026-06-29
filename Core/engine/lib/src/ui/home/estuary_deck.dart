import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../providers.dart';
import '../../rust/api.dart';
import '../track_meta.dart';
import 'wave_controls.dart';

/// On-air дека — единственная тяжёлая blur-поверхность реки: LIVE-шапка, играющий
/// трек (обложка + имя), несущая частота (waveform во всю ширину) и пульт волны
/// (играть · обновить). Легаси `EstuaryDeck`.
///
/// Сама дека на провайдеры не подписана: позиция (~10Hz) и факт игры изолированы
/// в дочерних [_DeckWaveform]/[_LiveHeader] (см. blueprint §2.4), чтобы тик не
/// перерисовывал тяжёлое стекло (BackdropFilter sigma 24 + радиальное свечение).
class EstuaryDeck extends ConsumerWidget {
  final TrackDto? track;
  final bool isCurrent;
  final bool refreshing;
  final VoidCallback onRefresh;
  final VoidCallback? onPlayWave;

  const EstuaryDeck({
    super.key,
    required this.track,
    required this.isCurrent,
    required this.refreshing,
    required this.onRefresh,
    required this.onPlayWave,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ScTheme.paletteOf(context);
    final perf = ScPerf.profileOf(context);
    final sigma = perf.sigma(24);

    final body = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x1AFFFFFF)),
        gradient: sigma > 0
            ? const LinearGradient(
                begin: Alignment(-0.4, -1),
                end: Alignment(0.4, 1),
                colors: [Color(0x26FFFFFF), Color(0x0FFFFFFF), Color(0x1AFFFFFF)],
                stops: [0, 0.55, 1],
              )
            : null,
        color: sigma > 0 ? null : const Color(0xFF15151B),
        boxShadow: const [
          BoxShadow(color: Color(0x73000000), blurRadius: 60, offset: Offset(0, 24)),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.76, -1),
                    radius: 1.1,
                    colors: [palette.accentGlow, Colors.transparent],
                    stops: const [0, 0.6],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _LiveHeader(palette: palette),
                const SizedBox(height: 16),
                _trackRow(context, ref),
                const SizedBox(height: 16),
                _waveformWithReflection(context),
                const SizedBox(height: 16),
                const Divider(height: 1, thickness: 1, color: Color(0x0FFFFFFF)),
                const SizedBox(height: 16),
                _controls(ref, palette),
              ],
            ),
          ),
        ],
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: sigma > 0
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
              child: body,
            )
          : body,
    );
  }

  Widget _trackRow(BuildContext context, WidgetRef ref) {
    if (track == null) {
      return Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0x0AFFFFFF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x0FFFFFFF)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  ref.tr('soundwave.idleTitle'),
                  style: const TextStyle(
                    color: Color(0xE6FFFFFF),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  ref.tr('soundwave.idleSub'),
                  style: const TextStyle(color: Color(0x73FFFFFF), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      );
    }
    final t = track!;
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 56,
            height: 56,
            child: TrackArtwork(url: t.artworkUrl, size: ArtSize.row),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xF2FFFFFF),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                t.artistName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0x80FFFFFF), fontSize: 12),
              ),
            ],
          ),
        ),
        // Справа — рейтинг трека + время (как в легаси `WaveTrackHeader`), не лайк.
        TrackStatusBadge(meta: trackScdMeta(t)),
        const SizedBox(width: 10),
        _DeckTime(track: t, isCurrent: isCurrent),
      ],
    );
  }

  /// Несущая частота + её отражение снизу (легаси `WebkitBoxReflect: below 2px
  /// linear-gradient(transparent 62%, white .13)`, только beauty): перевёрнутая
  /// по вертикали тусклая копия волны, гаснущая вниз.
  Widget _waveformWithReflection(BuildContext context) {
    final wave = _DeckWaveform(track: track, isCurrent: isCurrent);
    if (ScPerf.of(context) != PerfMode.beauty) return wave;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        wave,
        const SizedBox(height: 2),
        SizedBox(
          height: 26,
          child: ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x30FFFFFF), Color(0x00FFFFFF)],
              stops: [0, 0.85],
            ).createShader(rect),
            blendMode: BlendMode.dstIn,
            child: Transform.flip(
              flipY: true,
              // Отражает ЖИВУЮ волну с цветом прогресса (accent), не серую копию.
              child: _DeckWaveform(
                track: track,
                isCurrent: isCurrent,
                height: 26,
                seekable: false,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _controls(WidgetRef ref, ScPalette palette) {
    final filters = ref.watch(waveFiltersProvider);
    final notifier = ref.read(settingsProvider.notifier);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _PlayWaveButton(
          label: ref.tr('soundwave.river.playWave'),
          accent: palette.accent,
          contrast: palette.accentContrast,
          glow: palette.accentGlow,
          enabled: onPlayWave != null,
          onTap: onPlayWave,
        ),
        Container(width: 1, height: 24, color: const Color(0x12FFFFFF)),
        WaveToggle(
          icon: LucideIcons.clock,
          label: ref.tr('soundwave.hideListenedLabel'),
          value: filters.hideListened,
          onChanged: notifier.setSoundwaveHideListened,
        ),
        WaveToggle(
          icon: LucideIcons.heart,
          label: ref.tr('soundwave.hideLikedLabel'),
          value: filters.hideLiked,
          onChanged: notifier.setSoundwaveHideLiked,
        ),
        const LanguageFilterButton(),
        _RefreshButton(
          tooltip: ref.tr('soundwave.refresh'),
          refreshing: refreshing,
          onTap: onRefresh,
        ),
      ],
    );
  }
}

/// Время трека в шапке деки: играющий — живой `прошло / всего` (прошло акцентом),
/// иначе — общая длительность. Свой 10Hz-подписчик (не дёргает стекло деки).
class _DeckTime extends ConsumerWidget {
  final TrackDto track;
  final bool isCurrent;

  const _DeckTime({required this.track, required this.isCurrent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = formatDuration(track.durationMs.toInt());
    const tab = [FontFeature.tabularFigures()];
    if (!isCurrent) {
      return Text(
        total,
        style: const TextStyle(
            color: Color(0x59FFFFFF), fontSize: 11, fontFeatures: tab),
      );
    }
    final accent = ScTheme.paletteOf(context).accent;
    final pos = ref.watch(positionStreamProvider).value ?? 0;
    final elapsed = formatDuration((pos * 1000).round());
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          elapsed,
          style: TextStyle(
              color: accent,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              fontFeatures: tab),
        ),
        const Text(' / ',
            style: TextStyle(color: Color(0x40FFFFFF), fontSize: 11)),
        Text(
          total,
          style: const TextStyle(
              color: Color(0x80FFFFFF), fontSize: 11, fontFeatures: tab),
        ),
      ],
    );
  }
}

/// LIVE-шапка деки. Подписана на `playerProvider` (факт игры → пульс точки)
/// локально, чтобы смена трека не перерисовывала тяжёлое стекло деки.
class _LiveHeader extends ConsumerWidget {
  final ScPalette palette;

  const _LiveHeader({required this.palette});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playing = ref.watch(playerProvider) != null;
    return Row(
      children: [
        _LiveDot(accent: palette.accent, playing: playing),
        const SizedBox(width: 10),
        Text(
          ref.tr('soundwave.river.live'),
          style: const TextStyle(
            color: Color(0xE6FFFFFF),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.3,
          ),
        ),
        const SizedBox(width: 8),
        if (playing) ...[
          _AdaptDots(accent: palette.accent),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Text(
            ref.tr('soundwave.river.adapts'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0x73FFFFFF), fontSize: 11.5),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          ref.tr('soundwave.river.queueInf'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0x59FFFFFF),
            fontSize: 11,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}

/// «Эфир подстраивается» — три живых eq-бара, только при воспроизведении
/// (легаси `AdaptDots`/`riv-eq`). Idle-gated.
class _AdaptDots extends StatefulWidget {
  final Color accent;

  const _AdaptDots({required this.accent});

  @override
  State<_AdaptDots> createState() => _AdaptDotsState();
}

class _AdaptDotsState extends State<_AdaptDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  static const _phases = [0.3, 0.7, 0.1];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final idle = ScPerf.of(context) != PerfMode.light;
    if (idle && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!idle && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (ScPerf.of(context) == PerfMode.light) return const SizedBox.shrink();
    return SizedBox(
      height: 10,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < _phases.length; i++) ...[
            if (i > 0) const SizedBox(width: 2.5),
            AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final t = ((_c.value + _phases[i]) % 1.0);
                final h = 3 + (t < 0.5 ? t * 2 : (1 - t) * 2) * 7;
                return Container(
                  width: 3,
                  height: h,
                  decoration: BoxDecoration(
                    color: widget.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// Несущая частота: единственный 10Hz-подписчик деки. Watch'ит
/// `positionStreamProvider` локально (как [TrackWaveform]), поэтому тик позиции
/// перерисовывает только waveform, а не blur-поверхность деки (blueprint §2.4).
///
/// Сэмплы — реальная огибающая из SC waveform JSON (`waveformProvider`); пока мост
/// не отдал (нет url / ещё грузится) — синтетическая форма по urn, чтобы дека не
/// была пустой.
class _DeckWaveform extends ConsumerWidget {
  final TrackDto? track;
  final bool isCurrent;
  final double height;

  /// Кликабельность (перемотка). Отражение — некликабельная копия.
  final bool seekable;

  const _DeckWaveform({
    required this.track,
    required this.isCurrent,
    this.height = 72,
    this.seekable = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = track?.waveformUrl ?? '';
    final real = url.isEmpty ? null : ref.watch(waveformProvider(url)).value;
    final samples = (real != null && real.isNotEmpty) ? real : _waveSamples();
    if (!isCurrent) {
      return LiveWaveform(samples: samples, progress: 0, height: height);
    }
    final pos = ref.watch(positionStreamProvider).value ?? 0;
    final durSecs = (track?.durationMs.toInt() ?? 0) / 1000.0;
    final progress = durSecs > 0 ? (pos / durSecs).clamp(0.0, 1.0) : 0.0;
    return LiveWaveform(
      samples: samples,
      progress: progress,
      height: height,
      playhead: true,
      seekable: seekable,
      onSeek: seekable
          ? (frac) {
              if (durSecs > 0) {
                ref.read(playerProvider.notifier).seekTo(frac * durSecs);
              }
            }
          : null,
    );
  }

  /// Фолбэк: псевдо-волна по urn, пока реальная огибающая не пришла.
  List<double> _waveSamples() {
    final seed = track?.urn.hashCode ?? 1;
    return [for (var i = 0; i < 80; i++) ((seed >> (i % 16)) & 7) / 7.0];
  }
}

class _PlayWaveButton extends StatefulWidget {
  final String label;
  final Color accent;
  final Color contrast;
  final Color glow;
  final bool enabled;
  final VoidCallback? onTap;

  const _PlayWaveButton({
    required this.label,
    required this.accent,
    required this.contrast,
    required this.glow,
    required this.enabled,
    required this.onTap,
  });

  @override
  State<_PlayWaveButton> createState() => _PlayWaveButtonState();
}

class _PlayWaveButtonState extends State<_PlayWaveButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedSlide(
          duration: ScTokens.dFast,
          offset: Offset(0, _hover && widget.enabled ? -0.04 : 0),
          child: Opacity(
            opacity: widget.enabled ? 1 : 0.4,
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: widget.accent,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: widget.glow, blurRadius: 24, offset: const Offset(0, 6))],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.play, size: 18, color: widget.contrast),
                  const SizedBox(width: 8),
                  Text(
                    widget.label,
                    style: TextStyle(
                      color: widget.contrast,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
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

class _RefreshButton extends StatefulWidget {
  final String tooltip;
  final bool refreshing;
  final VoidCallback onTap;

  const _RefreshButton({
    required this.tooltip,
    required this.refreshing,
    required this.onTap,
  });

  @override
  State<_RefreshButton> createState() => _RefreshButtonState();
}

class _RefreshButtonState extends State<_RefreshButton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );

  @override
  void didUpdateWidget(_RefreshButton old) {
    super.didUpdateWidget(old);
    if (widget.refreshing && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.refreshing && _c.isAnimating) {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScTooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.refreshing ? null : widget.onTap,
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0x0FFFFFFF),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0x14FFFFFF)),
            ),
            child: RotationTransition(
              turns: _c,
              child: const Icon(LucideIcons.rotateCw, size: 14, color: Color(0xB3FFFFFF)),
            ),
          ),
        ),
      ),
    );
  }
}

/// LIVE-точка деки (size 8) — пульс только при воспроизведении.
class _LiveDot extends StatefulWidget {
  final Color accent;
  final bool playing;

  const _LiveDot({required this.accent, required this.playing});

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_LiveDot old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final animate = widget.playing && ScPerf.of(context) != PerfMode.light;
    if (animate && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!animate && _c.isAnimating) {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glow = ScPerf.of(context) == PerfMode.beauty;
    return FadeTransition(
      opacity: Tween(begin: 1.0, end: 0.35).animate(_c),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: widget.accent,
          shape: BoxShape.circle,
          boxShadow: glow ? [BoxShadow(color: widget.accent, blurRadius: 8)] : null,
        ),
      ),
    );
  }
}
