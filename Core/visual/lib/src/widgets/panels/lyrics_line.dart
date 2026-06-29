import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';

import '../../tokens.dart';
import 'lyrics_playhead.dart';

/// Одна строка синхронной лирики. В beauty/medium активная строка светится
/// по-символьно (sweep слева направо); light — целиком белая, без per-char.
/// Перерисовывается по [playhead], не дёргая родительский список.
class LyricsLine extends StatelessWidget {
  final String text;
  final int index;
  final ValueListenable<LyricsPlayhead> playhead;
  final bool perChar;
  final VoidCallback? onTap;

  const LyricsLine({
    super.key,
    required this.text,
    required this.index,
    required this.playhead,
    this.perChar = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: ValueListenableBuilder<LyricsPlayhead>(
            valueListenable: playhead,
            builder: (_, head, __) {
              final state = head.stateFor(index);
              final progress = state == LyricLineState.active ? head.lineProgress : 0.0;
              return _line(state, progress);
            },
          ),
        ),
      ),
    );
  }

  Widget _line(LyricLineState state, double progress) {
    final visual = _LineVisual.of(state);
    final content = perChar && state == LyricLineState.active
        ? _PerCharText(text: text, progress: progress)
        : Text(text, style: _baseStyle.copyWith(color: visual.color));

    Widget out = AnimatedOpacity(
      duration: _dur,
      curve: ScTokens.easeApple,
      opacity: visual.opacity,
      child: content,
    );
    if (visual.glow != null) {
      out = _Glow(color: visual.glow!, blur: visual.glowBlur, child: out);
    }
    // transform-origin: left center → scale + translateX вокруг левого края.
    out = AnimatedScale(
      duration: _dur,
      curve: ScTokens.easeApple,
      alignment: Alignment.centerLeft,
      scale: visual.scale,
      child: out,
    );
    return Align(
      alignment: Alignment.centerLeft,
      child: TweenAnimationBuilder<double>(
        duration: _dur,
        curve: ScTokens.easeApple,
        tween: Tween(end: visual.shiftPx),
        builder: (_, dx, child) =>
            Transform.translate(offset: Offset(dx, 0), child: child),
        child: out,
      ),
    );
  }
}

/// transition 0.45s в легаси (`.lyric-line`); 0.9·dGlass = 450ms.
final _dur = ScTokens.dGlass.scaled(0.9);

const _baseStyle = TextStyle(
  fontSize: 28,
  fontWeight: FontWeight.w700,
  height: 1.32,
  letterSpacing: -0.02 * 28,
  color: Color(0x42FFFFFF), // rgba(255,255,255,0.26)
);

/// Таблица состояний строки (легаси `.lyric-line[data-state]`, index.css).
/// [shiftPx] — точный translateX в логических px (как в CSS translate3d).
class _LineVisual {
  final Color color;
  final double opacity;
  final double scale;
  final double shiftPx;
  final Color? glow;
  final double glowBlur;

  const _LineVisual({
    required this.color,
    required this.opacity,
    required this.scale,
    required this.shiftPx,
    this.glow,
    this.glowBlur = 0,
  });

  static _LineVisual of(LyricLineState state) => switch (state) {
        LyricLineState.active => const _LineVisual(
            color: Color(0xFFFFFFFF),
            opacity: 1,
            scale: 1.02,
            shiftPx: 0,
            glow: Color(0x61FFFFFF), // rgba(255,255,255,0.38)
            glowBlur: 18,
          ),
        LyricLineState.pastNear => const _LineVisual(
            color: Color(0xC7FFFFFF), // 0.78
            opacity: 0.78,
            scale: 0.992,
            shiftPx: -4,
          ),
        LyricLineState.past => const _LineVisual(
            color: Color(0x6BFFFFFF), // 0.42
            opacity: 0.48,
            scale: 0.98,
            shiftPx: -8,
          ),
        LyricLineState.nextNear => const _LineVisual(
            color: Color(0x8CFFFFFF), // 0.55
            opacity: 0.66,
            scale: 0.988,
            shiftPx: 6,
          ),
        LyricLineState.next => const _LineVisual(
            color: Color(0x52FFFFFF), // 0.32
            opacity: 0.28,
            scale: 0.968,
            shiftPx: 12,
          ),
      };
}

/// Per-char караоке-светимость: «голова» (= progress·N) едет слева направо,
/// у каждого символа local = clamp01((head − i + 0.6)/1.4), smoothstep →
/// цвет/тень/подъём (легаси `.lyric-char`).
class _PerCharText extends StatelessWidget {
  static const _softLead = 0.6;
  static const _softTail = 1.4;

  final String text;
  final double progress;

  const _PerCharText({required this.text, required this.progress});

  @override
  Widget build(BuildContext context) {
    final chars = text.characters.toList();
    final animated = chars.where((c) => c.trim().isNotEmpty).length;
    final head = progress * animated;

    var animIdx = 0;
    final spans = <InlineSpan>[];
    for (final ch in chars) {
      if (ch.trim().isEmpty) {
        spans.add(TextSpan(text: ch, style: _baseStyle));
        continue;
      }
      final local = ((head - animIdx + _softLead) / _softTail).clamp(0.0, 1.0);
      final p = local * local * (3 - 2 * local); // smoothstep
      animIdx++;
      spans.add(TextSpan(text: ch, style: _charStyle(p)));
    }
    return Text.rich(TextSpan(children: spans));
  }

  TextStyle _charStyle(double p) {
    final shadows = p <= 0
        ? const <Shadow>[]
        : [
            Shadow(color: const Color(0xFFFFFFFF).withValues(alpha: 0.18 * p), blurRadius: 10 * p),
            Shadow(color: const Color(0xFFFFFFFF).withValues(alpha: 0.1 * p), blurRadius: 24 * p),
          ];
    return _baseStyle.copyWith(
      color: const Color(0xFFFFFFFF).withValues(alpha: 0.26 + 0.74 * p),
      shadows: shadows,
    );
  }
}

class _Glow extends StatelessWidget {
  final Color color;
  final double blur;
  final Widget child;

  const _Glow({required this.color, required this.blur, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(boxShadow: [BoxShadow(color: color, blurRadius: blur)]),
      child: child,
    );
  }
}

extension on Duration {
  Duration scaled(double factor) =>
      Duration(microseconds: (inMicroseconds * factor).round());
}
