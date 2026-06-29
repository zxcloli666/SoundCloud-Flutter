import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:sc_visual/sc_visual.dart';

import 'forge_belt.dart';
import 'forge_sparks.dart';
import 'offline_model.dart';
import 'offline_pulse.dart';

/// Левый модуль hero-деки: живой конвейер А→Б (сырьё → горн → чистые m4a).
class ForgeModule extends StatelessWidget {
  final ForgeStatus status;
  final String? forgingTitle;

  const ForgeModule({super.key, required this.status, this.forgingTitle});

  @override
  Widget build(BuildContext context) {
    final transcoding = status.transcoding;
    final incoming = status.incoming;
    final ffmpeg = status.ffmpeg;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text.rich(
                  TextSpan(
                    text: 'КУЗНИЦА',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                      color: Color(0x59FFFFFF),
                    ),
                    children: [
                      TextSpan(
                        text: '  · конвейер А→Б',
                        style: TextStyle(
                          letterSpacing: 0.8,
                          color: Color(0x8CFFFFFF),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _FfmpegChip(state: ffmpeg),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Center(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _Station(label: 'СЫРЬЁ · A', value: incoming, sub: 'в очереди'),
                  Expanded(
                    child: ForgeBelt(
                      active: incoming > 0 && ffmpeg == FfmpegState.ready,
                      warm: false,
                    ),
                  ),
                  _Station(
                    label: 'ГОРН',
                    value: transcoding,
                    sub: transcoding > 0 ? 'плавится' : 'ожидание',
                    hot: true,
                  ),
                  Expanded(
                    child: ForgeBelt(active: transcoding > 0, warm: true),
                  ),
                  _Station(label: 'ГОТОВО · M4A', value: status.clean, sub: 'чистые'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _LogLine(status: status, forgingTitle: forgingTitle),
        ],
      ),
    );
  }
}

class _FfmpegChip extends StatelessWidget {
  final FfmpegState state;

  const _FfmpegChip({required this.state});

  @override
  Widget build(BuildContext context) {
    final (color, bg, label, pulse) = switch (state) {
      FfmpegState.ready =>
        (const Color(0xE6A7F3D0), const Color(0x147EE7B0), 'готов', false),
      FfmpegState.preparing =>
        (const Color(0xE6FDE68A), const Color(0x14FBBF24), 'прогрев', true),
      FfmpegState.unavailable =>
        (const Color(0xE6FECDD3), const Color(0x14FB7185), 'недоступен', false),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: bg),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OfflinePulse(
            active: pulse,
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'ffmpeg · $label',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.6,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _Station extends StatelessWidget {
  final String label;
  final int value;
  final String sub;
  final bool hot;

  const _Station({
    required this.label,
    required this.value,
    required this.sub,
    this.hot = false,
  });

  @override
  Widget build(BuildContext context) {
    final perf = PerfProfile.of(context);
    final palette = ScTheme.paletteOf(context);
    final burning = hot && value > 0;
    return SizedBox(
      width: 96,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (burning && perf.bloom)
            Positioned(
              left: -24,
              top: -8,
              child: ImageFiltered(
                imageFilter:
                    ImageFilter.blur(sigmaX: perf.sigma(16), sigmaY: perf.sigma(16)),
                child: Container(
                  width: 150,
                  height: 96,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-0.2, 0.2),
                      colors: [palette.accentGlow, const Color(0x00000000)],
                    ),
                  ),
                ),
              ),
            ),
          if (burning && perf.idleAnim) const Positioned(top: -2, left: 48, child: ForgeSparks()),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.visible,
                softWrap: false,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.6,
                  color: Color(0x59FFFFFF),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '$value',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 44,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -1.3,
                  height: 1,
                  color: burning ? palette.accentHover : const Color(0xEBFFFFFF),
                  shadows: burning && perf.glow
                      ? [
                          Shadow(color: palette.accentGlow, blurRadius: 26),
                          Shadow(color: palette.accentGlow, blurRadius: 64),
                        ]
                      : null,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                sub,
                maxLines: 1,
                softWrap: false,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.1,
                  color: Color(0x73FFFFFF),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LogLine extends StatelessWidget {
  final ForgeStatus status;
  final String? forgingTitle;

  const _LogLine({required this.status, required this.forgingTitle});

  @override
  Widget build(BuildContext context) {
    final palette = ScTheme.paletteOf(context);
    final transcoding = status.transcoding;
    final incoming = status.incoming;
    final log = transcoding > 0 && forgingTitle != null
        ? 'плавлю $forgingTitle'
        : incoming > 0 && status.ffmpeg != FfmpegState.ready
            ? 'жду горн'
            : incoming > 0
                ? 'в очереди: $incoming'
                : 'простой';

    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0x0FFFFFFF))),
      ),
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Text('›',
              style: TextStyle(
                  fontFamily: 'monospace', fontSize: 11, color: palette.accent)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              log,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: Color(0x73FFFFFF),
              ),
            ),
          ),
          if (transcoding > 0)
            OfflinePulse(
              active: true,
              period: const Duration(milliseconds: 1100),
              minOpacity: 0.2,
              child: Container(width: 6, height: 11, color: palette.accentGlow),
            ),
        ],
      ),
    );
  }
}
