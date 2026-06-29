import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../config.dart';
import '../../providers.dart';

/// Карточка relay call-сети (легаси `CallProxySection`): живая mesh-сеть пиров на
/// фоне, статус ноды и премиум-гейтнутый тумблер. Состояние тянет из
/// `ScCallControls` (порт оболочки → desktop-bridge FFI); статус пуллится, пока
/// агент включён. Премиум-гейт ведёт на STAR. `call==null` — карточки нет.
class CallCard extends ConsumerStatefulWidget {
  const CallCard({super.key});

  @override
  ConsumerState<CallCard> createState() => _CallCardState();
}

class _CallCardState extends ConsumerState<CallCard> {
  static const _pollMs = 5000;

  bool? _enabled;
  int _status = 0; // 0 выкл · 1 подключение · 2 регистрация · 3 активен · 4 ошибка
  bool _busy = false;
  Timer? _poll;
  bool _clockSubscribed = false;

  ScCallControls? get _call => ref.read(scConfigProvider).call;

  @override
  void initState() {
    super.initState();
    final call = _call;
    if (call == null) return;
    _enabled = call.isEnabled();
    _status = call.status();
    _syncPolling();
    _syncClock();
  }

  @override
  void dispose() {
    _poll?.cancel();
    if (_clockSubscribed) AmbientClock.instance.unsubscribe();
    super.dispose();
  }

  /// Пуллим статус, пока нода включена (как Tauri STATUS_POLL_MS).
  void _syncPolling() {
    _poll?.cancel();
    if (_enabled != true) return;
    _poll = Timer.periodic(const Duration(milliseconds: _pollMs), (_) {
      final s = _call?.status();
      if (s != null && mounted) {
        setState(() => _status = s);
        _syncClock();
      }
    });
  }

  /// Тикер mesh-анимации крутим только когда есть что анимировать (подключение/
  /// активна) и режим не «лёгкий» — единый AmbientClock, не свой контроллер.
  void _syncClock() {
    final animate = _animate;
    if (animate && !_clockSubscribed) {
      AmbientClock.instance.subscribe();
      _clockSubscribed = true;
    } else if (!animate && _clockSubscribed) {
      AmbientClock.instance.unsubscribe();
      _clockSubscribed = false;
    }
  }

  bool get _live => _status == 3;
  bool get _working => _status == 1 || _status == 2;
  bool get _animate => _live || _working;

  Future<void> _toggle() async {
    final call = _call;
    if (_busy || _enabled == null || call == null) return;
    final premium = ref.read(meSubscriptionProvider).value ?? false;
    // Включена, но без премиума — ведём оформлять STAR (как легаси).
    if (_enabled == true && !premium) {
      ref.read(routerProvider.notifier).selectTab(const StarRoute());
      return;
    }
    setState(() => _busy = true);
    final next = !(_enabled ?? false);
    call.setEnabled(next);
    // Дать агенту тик подняться/погаснуть, затем перечитать статус.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    setState(() {
      _enabled = next;
      _status = call.status();
      _busy = false;
    });
    _syncPolling();
    _syncClock();
  }

  @override
  Widget build(BuildContext context) {
    if (_call == null || _enabled == null) return const SizedBox.shrink();
    final perf = PerfProfile.of(context);
    final palette = ScTheme.paletteOf(context);
    final premium = ref.watch(meSubscriptionProvider).value ?? false;
    final net = _statusColor(_status);
    final locked = _enabled == true && !premium;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment(0.4, -1),
          end: Alignment(-0.4, 1),
          colors: [Color(0x0DFFFFFF), Color(0x04FFFFFF), Color(0x08FFFFFF)],
          stops: [0, 0.6, 1],
        ),
        border: Border.all(color: const Color(0x1AFFFFFF), width: 0.5),
        boxShadow: [
          const BoxShadow(color: Color(0x66000000), blurRadius: 50, offset: Offset(0, 18)),
          if (_live && perf.glow) BoxShadow(color: net.withValues(alpha: 0.2), blurRadius: 56),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          height: 172,
          child: Stack(
            children: [
              // Живая mesh-сеть пиров (статичная в light; иначе пакеты+дыхание узлов).
              Positioned.fill(
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: _animate && perf.atmosphere
                        ? AnimatedBuilder(
                            animation: AmbientClock.instance.tick,
                            builder: (_, __) => _mesh(net, perf,
                                AmbientClock.instance.tick.value),
                          )
                        : _mesh(net, perf, 0),
                  ),
                ),
              ),
              // Скрим читаемости нижней строки.
              const Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x00000000), Color(0x800A0A0E), Color(0xB30A0A0E)],
                        stops: [0.34, 0.72, 1],
                      ),
                    ),
                  ),
                ),
              ),
              const Positioned(
                left: 24,
                right: 24,
                top: 0,
                child: SpecularHairline.subtle(),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _infoRow(context, palette, net, locked),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(
      BuildContext context, ScPalette palette, Color net, bool locked) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 16, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [net.withValues(alpha: 0.15), const Color(0x0AFFFFFF)],
              ),
              border: Border.all(color: net.withValues(alpha: 0.25), width: 0.5),
            ),
            child: Icon(LucideIcons.users, size: 18, color: net),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  ref.tr('call.title'),
                  style: const TextStyle(
                    color: Color(0xE6FFFFFF),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: net,
                          shape: BoxShape.circle,
                          boxShadow: PerfProfile.of(context).glow
                              ? [BoxShadow(color: net, blurRadius: 8)]
                              : null,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        ref.tr('call.status.${_statusKey(_status)}'),
                        style: const TextStyle(color: Color(0x80FFFFFF), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _toggleButton(palette, net, locked),
        ],
      ),
    );
  }

  Widget _toggleButton(ScPalette palette, Color net, bool locked) {
    final on = _enabled == true;
    final label = on ? ref.tr('call.disable') : ref.tr('call.enable');
    return MouseRegion(
      cursor: _busy ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _busy ? null : _toggle,
        child: Opacity(
          opacity: _busy ? 0.6 : 1,
          child: Container(
            height: 44,
            padding: const EdgeInsets.fromLTRB(14, 0, 20, 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9999),
              gradient: on
                  ? null
                  : LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [palette.accent, palette.accentHover],
                    ),
              color: on ? const Color(0x14FFFFFF) : null,
              border: on
                  ? Border.all(color: const Color(0x29FFFFFF), width: 0.5)
                  : null,
              boxShadow: on
                  ? null
                  : [BoxShadow(color: palette.accentGlow, blurRadius: 28, offset: const Offset(0, 10))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: on ? net.withValues(alpha: 0.18) : const Color(0xEBFFFFFF),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 13,
                          height: 13,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Icon(
                          locked
                              ? LucideIcons.lock
                              : LucideIcons.power,
                          size: 13,
                          color: on ? net : const Color(0xFF0A0A0C),
                        ),
                ),
                const SizedBox(width: 9),
                Text(
                  label,
                  style: TextStyle(
                    color: on ? Colors.white : palette.accentContrast,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _mesh(Color net, PerfProfile perf, double phase) {
    return CustomPaint(
      painter: _MeshPainter(
        net: net,
        phase: phase,
        animate: _animate && perf.atmosphere,
        glow: perf.glow,
        lit: _live || _working,
        meshOpacity: _live
            ? 1
            : _working
                ? 0.85
                : _status == 4
                    ? 0.7
                    : 0.55,
      ),
    );
  }

  static Color _statusColor(int status) => switch (status) {
        3 => const Color(0xFF34D399),
        1 || 2 => const Color(0xFFFBBF24),
        4 => const Color(0xFFEF4444),
        _ => const Color(0xFF6B7280),
      };

  static String _statusKey(int status) => switch (status) {
        1 => 'connecting',
        2 => 'provisioning',
        3 => 'active',
        4 => 'failed',
        _ => 'disabled',
      };
}

/// Mesh-сеть пиров (легаси SVG viewBox 360×120): спицы от ядра к пирам + пир-пир
/// связи + узлы; в анимации — бегущие пакеты по спицам и дыхание узлов. Лит под
/// цвет статуса.
class _MeshPainter extends CustomPainter {
  final Color net;
  final double phase;
  final bool animate;
  final bool glow;
  final bool lit;
  final double meshOpacity;

  _MeshPainter({
    required this.net,
    required this.phase,
    required this.animate,
    required this.glow,
    required this.lit,
    required this.meshOpacity,
  });

  static const _core = Offset(180, 46);
  static const _peers = [
    Offset(28, 26), Offset(86, 92), Offset(150, 20), Offset(214, 96),
    Offset(268, 30), Offset(330, 84), Offset(300, 108), Offset(60, 104),
    Offset(120, 60), Offset(240, 58), Offset(345, 40),
  ];
  static const _links = [
    [Offset(28, 26), Offset(60, 104)],
    [Offset(268, 30), Offset(330, 84)],
    [Offset(214, 96), Offset(300, 108)],
    [Offset(150, 20), Offset(268, 30)],
    [Offset(120, 60), Offset(240, 58)],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 360, size.height / 120);
    canvas.saveLayer(
      const Rect.fromLTWH(0, 0, 360, 120),
      Paint()..color = Color.fromRGBO(0, 0, 0, meseClamp(meshOpacity)),
    );

    final line = Paint()
      ..color = net.withValues(alpha: 0.3)
      ..strokeWidth = 1;
    for (final p in _peers) {
      canvas.drawLine(_core, p, line);
    }
    final link = Paint()
      ..color = net.withValues(alpha: 0.16)
      ..strokeWidth = 1;
    for (final l in _links) {
      canvas.drawLine(l[0], l[1], link);
    }

    // Бегущие пакеты по спицам (только в анимации).
    if (animate) {
      final pkt = Paint()..color = net.withValues(alpha: 0.95);
      for (var i = 0; i < _peers.length; i++) {
        final speed = 0.18 + (i % 3) * 0.06;
        final frac = ((phase * speed) + i * 0.13) % 1.0;
        final pos = Offset.lerp(_core, _peers[i], frac)!;
        canvas.drawCircle(pos, 1.6, pkt);
      }
    }

    // Узлы (дыхание в анимации).
    for (var i = 0; i < _peers.length; i++) {
      final breathe = animate
          ? 0.5 + 0.4 * (0.5 + 0.5 * math.sin(phase * 1.3 + i * 0.6))
          : (lit ? 0.7 : 0.45);
      final node = Paint()..color = net.withValues(alpha: breathe.clamp(0.0, 1.0));
      canvas.drawCircle(_peers[i], 2.6, node);
    }

    // Ядро «ты»: гало + точка + белый центр.
    canvas.drawCircle(_core, 18, Paint()..color = net.withValues(alpha: 0.18));
    canvas.drawCircle(_core, 6, Paint()..color = net);
    canvas.drawCircle(_core, 2.4, Paint()..color = const Color(0xEBFFFFFF));

    canvas.restore();
    canvas.restore();
  }

  static double meseClamp(double v) => v.clamp(0.0, 1.0);

  @override
  bool shouldRepaint(_MeshPainter old) =>
      old.phase != phase ||
      old.net != net ||
      old.meshOpacity != meshOpacity ||
      old.animate != animate;
}
