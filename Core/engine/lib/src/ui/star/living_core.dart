import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:sc_visual/sc_visual.dart';

/// Вертикальная позиция ядра в своей области (центр тёмного «колодца»).
const double coreCenterY = 0.46;

/// «Живое ядро» — sound-reactive диафрагма (легаси `LivingCore`, canvas → здесь
/// `CustomPainter` + тикер). Энергия живёт в спектральном кольце + светящемся
/// ободе; центр — тёмный колодец, держащий читаемость наложенного readout.
/// Тёплое ядро (accent юзера) против фиксированной холодно-фиолетовой каймы.
/// Перф-гейт: light рисует один статичный кадр; тикер паузится при скрытом окне.
class LivingCore extends StatefulWidget {
  /// Яркость тарифа 0..1 — гонит спектр-гейн + блум + размер.
  final double charge;

  /// Крутить быстрее + пульсировать в ожидании оплаты.
  final bool waiting;

  /// Ярче устойчивое ядро, когда членство активно.
  final bool lit;

  /// Инкремент → вспышка-зажигание + ударная волна.
  final int igniteKey;

  const LivingCore({
    super.key,
    required this.charge,
    required this.waiting,
    required this.lit,
    required this.igniteKey,
  });

  @override
  State<LivingCore> createState() => _LivingCoreState();
}

class _LivingCoreState extends State<LivingCore>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker = createTicker(_onTick);
  final _state = _CoreSim();
  // phase[i] = random — единственная mount-time RNG (легаси).
  late final List<double> _phase =
      List.generate(130, (_) => math.Random().nextDouble() * 6.283);
  final List<_Spark> _sparks = [];
  final math.Random _rng = math.Random();

  double _t = 0;
  int _prevIgnite = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _prevIgnite = widget.igniteKey;
    _syncTargets();
    // Тикер стартуем в didChangeDependencies — perf берётся из InheritedWidget,
    // в initState к нему обращаться нельзя.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final idle = PerfProfile.of(context).idleAnim;
    if (idle && !_ticker.isActive) {
      _ticker.start();
    } else if (!idle && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void didUpdateWidget(covariant LivingCore old) {
    super.didUpdateWidget(old);
    _syncTargets();
    if (widget.igniteKey != _prevIgnite) {
      _prevIgnite = widget.igniteKey;
      _state.shock = 0;
    }
    // Статичный режим: один кадр при смене входов.
    if (!PerfProfile.of(context).idleAnim) {
      _state.settle(widget.charge);
      setState(() {});
    }
  }

  void _syncTargets() {
    _state.charge = widget.charge;
    _state.coreTarget = widget.lit
        ? 1.18
        : widget.waiting
            ? 0.92
            : 1.0;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final hidden = state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused;
    if (hidden && _ticker.isActive) {
      _ticker.stop();
    } else if (!hidden && PerfProfile.of(context).idleAnim && !_ticker.isActive) {
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    // Лочим шаг на легаси 0.016/кадр для идентичной скорости спектра.
    _t += 0.016;
    _state.advance(0.07, 0.06);
    _spawnSparks();
    setState(() {});
  }

  void _spawnSparks() {
    final ch = _state.chargeEased;
    if (_rng.nextDouble() < 0.22 + ch * 0.3) {
      _sparks.add(_Spark(
        a: _rng.nextDouble() * 6.283,
        life: 1,
        sp: 0.5 + _rng.nextDouble() * 0.9,
      ));
    }
    for (var i = _sparks.length - 1; i >= 0; i--) {
      final sp = _sparks[i];
      sp.life -= 0.012;
      if (sp.life <= 0) _sparks.removeAt(i);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = ScTheme.paletteOf(context).accent;
    final perf = PerfProfile.of(context);
    return Positioned.fill(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _CorePainter(
            accent: accent,
            t: _t,
            sim: _state,
            phase: _phase,
            sparks: _sparks,
            useGlow: perf.glow,
            staticFrame: !perf.idleAnim,
          ),
        ),
      ),
    );
  }
}

/// Хот-стейт симуляции (легаси `p.current`): сглаженные charge/core + shock.
class _CoreSim {
  double charge = 0.5;
  double chargeEased = 0.5;
  double core = 1;
  double coreTarget = 1;
  double shock = -1;

  void advance(double chargeK, double coreK) {
    chargeEased += (charge - chargeEased) * chargeK;
    core += (coreTarget - core) * coreK;
  }

  void settle(double c) {
    charge = c;
    chargeEased = c;
    core = coreTarget;
  }
}

class _Spark {
  final double a;
  double life;
  final double sp;
  _Spark({required this.a, required this.life, required this.sp});
}

/// Порт легаси `draw()` 1:1 в слоях: блум → спектр-кольцо → обод → тики → колодец
/// → угли → ударная волна.
class _CorePainter extends CustomPainter {
  final Color accent;
  final double t;
  final _CoreSim sim;
  final List<double> phase;
  final List<_Spark> sparks;
  final bool useGlow;
  final bool staticFrame;

  _CorePainter({
    required this.accent,
    required this.t,
    required this.sim,
    required this.phase,
    required this.sparks,
    required this.useGlow,
    required this.staticFrame,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final ar = (accent.r * 255).round();
    final ag = (accent.g * 255).round();
    final ab = (accent.b * 255).round();

    final ch = sim.chargeEased;
    final cx = w / 2;
    final cy = h * coreCenterY;
    final scale = 0.78 + ch * 0.34;
    final innerR = math.min(w, h) * 0.135 * scale;
    final bass = staticFrame
        ? 0.6
        : 0.5 + 0.5 * math.sin(t * 2.1) + 0.2 * math.sin(t * 3.6);
    final gain = (0.4 + ch * 0.6) * sim.core;
    final blurSigma = useGlow ? 4.5 : 0.0; // CSS shadowBlur 9 ≈ sigma 4.5
    const N = 130;

    Color rgba(int r, int g, int b, double a) =>
        Color.fromRGBO(r, g, b, a.clamp(0, 1));

    // bloom: тёплое ядро → холодная фиолетовая кайма
    final a = 0.09 + ch * 0.13;
    final bloomR = math.min(w, h) * 0.52;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          colors: [
            rgba(ar, ag, ab, a),
            rgba(ar, ag, ab, a * 0.5),
            rgba(125, 108, 255, a * 0.22),
            const Color(0x00000000),
          ],
          stops: const [0, 0.45, 0.8, 1],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: bloomR)),
    );

    // спектр-кольцо (вращается). waiting (s.waiting) распознаём по coreTarget=0.92.
    final rot = t * (sim.coreTarget == 0.92 ? 0.16 : 0.04 + ch * 0.05);
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(rot);
    final barPaint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2;
    final glow = blurSigma > 0
        ? MaskFilter.blur(BlurStyle.normal, blurSigma)
        : null;
    for (var i = 0; i < N; i++) {
      final ang = (i / N) * 6.283;
      var v = (math.sin(t * 1.4 + phase[i]) * 0.5 +
              math.sin(t * 2.6 + phase[i] * 1.6) * 0.32 +
              math.sin(t * 0.8 + ang * 3) * 0.4)
          .abs();
      v = v * (0.5 + 0.5 * bass) * gain;
      final len = innerR * 0.2 + v * innerR * 1.3;
      final c1 = math.cos(ang);
      final s1 = math.sin(ang);
      final tip = math.min(1.0, v * 1.3);
      final gg = math.max(80, (ag - 60 * tip).round());
      final bb = math.min(255, (ab + 210 * tip).round());
      barPaint
        ..color = rgba(ar, gg, bb, 0.5 + v * 0.5)
        ..maskFilter = glow;
      canvas.drawLine(
        Offset(c1 * innerR, s1 * innerR),
        Offset(c1 * (innerR + len), s1 * (innerR + len)),
        barPaint,
      );
    }
    canvas.restore();

    // светящийся обод диафрагмы (тёплое полное кольцо + холодная дуга)
    final rimGlow = useGlow ? const MaskFilter.blur(BlurStyle.normal, 10) : null;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: innerR * 0.98),
      0,
      6.283,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..maskFilter = rimGlow
        ..color = rgba(math.min(255, ar + 40), math.min(255, ag + 90),
            math.min(255, ab + 90), 0.5 + ch * 0.4),
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: innerR * 0.98),
      math.pi * 1.02,
      math.pi * (1.7 - 1.02),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..maskFilter = rimGlow
        ..color = const Color(0x73B4AAFF), // rgba(180,170,255,0.45)
    );

    // тонкие тики диафрагмы
    final tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x1AFFFFFF); // rgba(255,255,255,0.10)
    for (var i = 0; i < 48; i++) {
      final ang = (i / 48) * 6.283;
      final r0 = innerR * 0.86;
      final r1 = innerR * 0.92;
      canvas.drawLine(
        Offset(cx + math.cos(ang) * r0, cy + math.sin(ang) * r0),
        Offset(cx + math.cos(ang) * r1, cy + math.sin(ang) * r1),
        tickPaint,
      );
    }

    // тёмный колодец — мягкая виньетка (длинное перо, без жёсткого края диска)
    canvas.drawCircle(
      Offset(cx, cy),
      innerR * 0.98,
      Paint()
        ..shader = RadialGradient(
          colors: const [
            Color(0xF006060A), // rgba(6,6,10,0.94)
            Color(0xC706060A), // 0.78
            Color(0x5206060A), // 0.32
            Color(0x0006060A),
          ],
          stops: const [0, 0.5, 0.82, 1],
        ).createShader(
            Rect.fromCircle(center: Offset(cx, cy), radius: innerR * 0.98)),
    );

    // угли (живой кадр)
    if (!staticFrame) {
      final emberPaint = Paint();
      for (final sp in sparks) {
        final r = innerR * 1.1 + (1 - sp.life) * sp.sp * 60;
        final x = cx + math.cos(sp.a) * r;
        final y = cy + math.sin(sp.a) * r - (1 - sp.life) * 12;
        emberPaint.color =
            rgba(255, 180 + (sp.life * 55).round(), 120, sp.life * 0.7);
        canvas.drawCircle(Offset(x, y), 1.2, emberPaint);
      }
    }

    // ударная волна на зажигании
    if (sim.shock >= 0) {
      sim.shock += staticFrame ? 0 : 0.02;
      final sr = sim.shock * math.min(w, h) * 0.75;
      canvas.drawCircle(
        Offset(cx, cy),
        sr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * (1 - sim.shock)
          ..color = rgba(math.min(255, ar + 40), math.min(255, ag + 80), 90,
              math.max(0, 0.7 - sim.shock)),
      );
      if (sim.shock >= 1) sim.shock = -1;
    }
  }

  @override
  bool shouldRepaint(_CorePainter old) => true;
}
