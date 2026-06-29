import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:sc_visual/sc_visual.dart';

/// Vibe-портал (легаси `VibePortal`): «дверь» в поиск-по-вайбу, прорезанная в
/// стекле. Глубина из слоёв света — акцентная аврора со «дна», сигила-глиф,
/// AI-бейдж и шеренга марширующих шевронов, тянущих взгляд в поиск.
class VibePortal extends StatefulWidget {
  final String title;
  final String subtitle;
  final String badge;
  final VoidCallback onTap;

  const VibePortal({
    super.key,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.onTap,
  });

  @override
  State<VibePortal> createState() => _VibePortalState();
}

class _VibePortalState extends State<VibePortal>
    with TickerProviderStateMixin {
  bool _hover = false;

  /// Позиция курсора в локальных координатах портала (для specular-линзы под
  /// стеклом). ValueNotifier — чтобы pointer-move перерисовывал ТОЛЬКО линзу, а
  /// не весь портал (без setState на каждый move).
  final ValueNotifier<Offset?> _cursor = ValueNotifier<Offset?>(null);

  // Hover-прогресс (сигила/кольцо/подтяжка мошек) и ОДНОКРАТНЫЙ проблеск —
  // выделенные контроллеры (60fps, плавно), а не общие 10fps-часы (лагало).
  late final AnimationController _hoverCtrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
  late final AnimationController _gleamCtrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1050));

  // Марш шевронов — от общих 20fps амбиент-часов (idle-анимация).
  bool _marching = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMarch();
  }

  void _syncMarch() {
    final idle = ScPerf.of(context) != PerfMode.light;
    if (idle && !_marching) {
      _marching = true;
      AmbientClock.instance.subscribe();
    } else if (!idle && _marching) {
      _marching = false;
      AmbientClock.instance.unsubscribe();
    }
  }

  void _enter() {
    setState(() => _hover = true);
    _hoverCtrl.forward();
    _gleamCtrl.forward(from: 0); // проблеск — один раз за наведение
  }

  void _exit() {
    setState(() => _hover = false);
    _hoverCtrl.reverse();
    _cursor.value = null;
  }

  @override
  void dispose() {
    if (_marching) AmbientClock.instance.unsubscribe();
    _hoverCtrl.dispose();
    _gleamCtrl.dispose();
    _cursor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ScTheme.paletteOf(context);
    final perf = PerfProfile.of(context);
    final accent = palette.accent;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _enter(),
      onExit: (_) => _exit(),
      onHover: (e) => _cursor.value = e.localPosition,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hover ? 1.012 : 1,
          duration: ScTokens.dFast,
          curve: ScTokens.easeApple,
          child: Container(
            height: 76,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                begin: Alignment(-0.5, -1),
                end: Alignment(0.5, 1),
                colors: [Color(0x13FFFFFF), Color(0x06FFFFFF), Color(0x0DFFFFFF)],
                stops: [0, 0.58, 1],
              ),
              border: Border.all(color: const Color(0x24FFFFFF), width: 0.5),
              boxShadow: [
                const BoxShadow(
                  color: Color(0x57000000),
                  blurRadius: 26,
                  offset: Offset(0, 8),
                ),
                if (perf.glow)
                  BoxShadow(color: accent.withValues(alpha: 0.18), blurRadius: 30),
              ],
            ),
            child: Stack(
              children: [
                if (perf.bloom) _aurora(accent, perf),
                // Дрейфующие акцентные мошки (perf-gated: число/анимация/glow).
                if (perf.particles(7) > 0)
                  Positioned.fill(child: _motes(accent, perf)),
                // Курсор-specular линза под стеклом (только на hover).
                Positioned.fill(child: _lensLayer()),
                // Контент на всю высоту портала → Row центрирует его вертикально
                // (иначе непозиционированный child Stack прижимается к верху).
                Positioned.fill(child: _content(accent, perf)),
                // Верхний specular-блик (тонкая линия) и hover-проблеск (1 раз).
                _sheen(),
                Positioned.fill(child: _gleam()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Аврора со дна двери — акцентное свечение, размытое в отдельном слое.
  Widget _aurora(Color accent, PerfProfile perf) {
    final sigma = perf.sigma(26);
    final glow = RadialGradient(
      center: const Alignment(0, 1),
      radius: 1.0,
      colors: [accent.withValues(alpha: _hover ? 0.34 : 0.24), Colors.transparent],
      stops: const [0, 0.72],
    );
    final field = Positioned(
      left: -32,
      right: -32,
      bottom: -48,
      height: 112,
      child: IgnorePointer(
        child: DecoratedBox(decoration: BoxDecoration(gradient: glow)),
      ),
    );
    if (sigma <= 0) return field;
    return Positioned.fill(
      child: IgnorePointer(
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: Stack(children: [field]),
        ),
      ),
    );
  }

  Widget _content(Color accent, PerfProfile perf) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _sigil(accent, perf),
          const SizedBox(width: 14),
          Expanded(child: _text(accent)),
          _chevrons(accent),
        ],
      ),
    );
  }

  /// Сигила — акцентная грань с аудио-глифом, в которую «заглядываешь». На hover
  /// приподнимается (scale 1.06) и вокруг расходится тонкое кольцо (легаси
  /// `vp-sigil`/`vp-sigil-ring`).
  Widget _sigil(Color accent, PerfProfile perf) {
    final core = Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: RadialGradient(
          center: const Alignment(-0.36, -0.44),
          radius: 1.0,
          colors: [ScTheme.paletteOf(context).accentHover, accent],
          stops: const [0, 0.7],
        ),
        border: Border.all(color: const Color(0x47FFFFFF), width: 0.5),
        boxShadow: [
          if (perf.glow)
            BoxShadow(color: accent.withValues(alpha: 0.2), blurRadius: 18, offset: const Offset(0, 6)),
        ],
      ),
      child: Icon(
        LucideIcons.audioLines,
        size: 18,
        color: ScTheme.paletteOf(context).accentContrast,
      ),
    );
    return SizedBox(
      width: 44,
      height: 44,
      child: AnimatedBuilder(
        animation: _hoverCtrl,
        builder: (context, child) {
          final t = ScTokens.easeApple.transform(_hoverCtrl.value.clamp(0.0, 1.0));
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Transform.scale(
                  scale: 1 + 0.22 * t,
                  child: Opacity(
                    opacity: 0.5 * t,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: accent, width: 1),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Transform.scale(scale: 1 + 0.06 * t, child: child),
              ),
            ],
          );
        },
        child: core,
      ),
    );
  }

  Widget _text(Color accent) {
    final contrast = ScTheme.paletteOf(context).accentContrast;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xF2FFFFFF),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _aiBadge(accent, contrast),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          widget.subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0x80FFFFFF), fontSize: 12),
        ),
      ],
    );
  }

  Widget _aiBadge(Color accent, Color contrast) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.sparkles, size: 9, color: contrast),
          const SizedBox(width: 3),
          Text(
            widget.badge.toUpperCase(),
            style: TextStyle(
              color: contrast,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  /// Три шеврона внахлёст с нарастающей яркостью; дышат вправо (0→3px), на hover
  /// ускоряются (легаси `vp-chev` 1.9s → 0.85s).
  Widget _chevrons(Color accent) {
    return AnimatedBuilder(
      animation: AmbientClock.instance.tick,
      builder: (context, _) {
        final period = _hover ? 0.85 : 1.9;
        final s = AmbientClock.instance.seconds;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Transform.translate(
                offset: Offset(-10.0 * i + _chevShift(s, period, i), 0),
                child: Icon(
                  LucideIcons.chevronRight,
                  size: 20,
                  color: accent.withValues(alpha: (0.28 + i * 0.26).clamp(0.0, 1.0)),
                ),
              ),
          ],
        );
      },
    );
  }

  // Плавный сдвиг шеврона 0→3px со сдвигом фазы по индексу.
  double _chevShift(double s, double period, int i) {
    final t = (s / period + i * 0.16) % 1.0;
    return (math.sin(t * 2 * math.pi) * 0.5 + 0.5) * 3;
  }

  // Мошки: (left%, top%, size) — сид как в легаси, смещены влево/центр.
  static const _moteDefs = <(double, double, double)>[
    (10, 22, 2), (51, 21, 3), (28, 20, 2), (5, 19, 3),
    (46, 18, 2), (23, 17, 3), (0, 16, 2),
  ];

  /// Дрейфующие акцентные мошки; на hover их «затягивает» к стрелке-колодцу и
  /// они гаснут (легаси `vp-mote`: drift → translate to well + scale .4 + opacity 0).
  Widget _motes(Color accent, PerfProfile perf) {
    final count = perf.particles(_moteDefs.length);
    final idle = perf.idleAnim;
    final glow = perf.glow;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: Listenable.merge([AmbientClock.instance.tick, _hoverCtrl]),
        builder: (context, _) {
          final s = AmbientClock.instance.seconds;
          final pull = ScTokens.easeApple.transform(_hoverCtrl.value.clamp(0.0, 1.0));
          return LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth, h = c.maxHeight;
              return Stack(
                children: [
                  for (var i = 0; i < count; i++)
                    _mote(_moteDefs[i], i, accent, w, h, s, pull, idle, glow),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _mote((double, double, double) m, int i, Color accent, double w,
      double h, double s, double pull, bool idle, bool glow) {
    final rest = 1 - pull;
    final dx = idle ? math.sin((s + i * 0.9) * 0.8) * 6 * rest : 0.0;
    final dy = idle ? math.cos((s + i * 1.3) * 0.7) * 5 * rest : 0.0;
    final base = Offset(m.$1 / 100 * w, m.$2 / 100 * h + h * 0.34);
    final pos = Offset.lerp(base, Offset(w * 0.9, h * 0.5), pull)!;
    final size = m.$3 * (1 - 0.6 * pull); // 1 → 0.4
    final alpha = 0.85 * rest; // гаснут к колодцу
    return Positioned(
      left: pos.dx + dx,
      top: pos.dy + dy,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: alpha),
          shape: BoxShape.circle,
          boxShadow: glow && alpha > 0.05
              ? [BoxShadow(color: accent.withValues(alpha: 0.6 * rest), blurRadius: 6)]
              : null,
        ),
      ),
    );
  }

  /// Курсор-линза: белый radial-блик под стеклом, едет за курсором (fade на hover).
  Widget _lensLayer() {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: _hover ? 1 : 0,
        duration: const Duration(milliseconds: 400),
        curve: ScTokens.easeApple,
        child: AnimatedBuilder(
          animation: _cursor,
          builder: (context, _) => CustomPaint(painter: _LensPainter(_cursor.value)),
        ),
      ),
    );
  }

  /// Верхний specular-блик — тонкая светлая линия по краю двери.
  Widget _sheen() {
    return const Positioned(
      left: 20,
      right: 20,
      top: 0,
      height: 1,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0x00FFFFFF), Color(0x73FFFFFF), Color(0x00FFFFFF)],
            ),
          ),
        ),
      ),
    );
  }

  /// Косой проблеск — проносится по двери ОДИН раз за наведение (легаси `vp-gleam`
  /// 1.05s, без повтора). Гоним выделенным контроллером (плавно, не лагает).
  Widget _gleam() {
    return ClipRect(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _gleamCtrl,
          builder: (context, _) {
            final v = _gleamCtrl.value;
            if (v <= 0 || v >= 1) return const SizedBox.shrink();
            final t = ScTokens.easeApple.transform(v);
            return LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth;
                final bandW = w * 0.3;
                final x = -bandW + t * (w + bandW * 2);
                return Stack(
                  children: [
                    Positioned(
                      left: x,
                      top: -8,
                      bottom: -8,
                      width: bandW,
                      child: Transform(
                        transform: Matrix4.skewX(-0.32),
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0x00FFFFFF),
                                Color(0x38FFFFFF),
                                Color(0x00FFFFFF),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Курсор-specular линза: белый радиальный блик (140×90) в точке [c].
class _LensPainter extends CustomPainter {
  final Offset? c;

  _LensPainter(this.c);

  @override
  void paint(Canvas canvas, Size size) {
    final p = c;
    if (p == null) return;
    final rect = Rect.fromCenter(center: p, width: 280, height: 180);
    final paint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0x29FFFFFF), Color(0x00FFFFFF)],
        stops: [0, 0.6],
      ).createShader(rect);
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(_LensPainter old) => old.c != c;
}
