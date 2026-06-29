import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../perf.dart';
import '../../tokens.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

enum ToastKind { neutral, success, error }

/// Одиночный фрост-тост (легаси sonner): тёмная стеклянная карточка с текстом.
/// bg rgba(30,30,34,0.9) + blur(20), border white/0.08, 13px white/0.85.
class Toast extends StatelessWidget {
  final String message;
  final ToastKind kind;
  final IconData? icon;

  const Toast({
    super.key,
    required this.message,
    this.kind = ToastKind.neutral,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final perf = ScPerf.of(context);
    final radius = BorderRadius.circular(ScTokens.rButton);
    final blur = PerfProfile(perf).sigma(20); // toast blur(20)
    final accent = switch (kind) {
      ToastKind.success => const Color(0xFF34D399),
      ToastKind.error => const Color(0xFFFB7185),
      ToastKind.neutral => null,
    };

    Widget body = Container(
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xE61E1E22), // rgba(30,30,34,0.9)
        borderRadius: radius,
        border: Border.all(color: const Color(0x14FFFFFF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: accent ?? const Color(0xD9FFFFFF)),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xD9FFFFFF), fontSize: 13),
            ),
          ),
        ],
      ),
    );

    if (blur > 0) {
      body = ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: body,
        ),
      );
    } else {
      body = ClipRRect(borderRadius: radius, child: body);
    }
    return body;
  }
}

/// Новостная карточка (легаси NewsToast): bottom-left, пульсирующая accent-точка,
/// title 13 / desc 12 line-clamp-2, на тап — открыть подробности.
class NewsToast extends StatefulWidget {
  final String title;
  final String description;
  final Color accent;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  const NewsToast({
    super.key,
    required this.title,
    required this.description,
    this.accent = const Color(0xFFFF5500),
    this.onTap,
    this.onDismiss,
  });

  @override
  State<NewsToast> createState() => _NewsToastState();
}

class _NewsToastState extends State<NewsToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animated = ScPerf.of(context) != PerfMode.light;
    if (animated && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!animated && _pulse.isAnimating) {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final perf = ScPerf.of(context);
    final radius = BorderRadius.circular(ScTokens.rCard);
    final blur = PerfProfile(perf).sigma(24); // backdrop-blur-xl ≈ blur(24)

    Widget body = Container(
      width: 340,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xE61A1A1E), // #1a1a1e/90
        borderRadius: radius,
        border: Border.all(color: const Color(0x14FFFFFF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _dot(perf),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Color(0xEBFFFFFF),
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0x8CFFFFFF), fontSize: 12),
                ),
              ],
            ),
          ),
          if (widget.onDismiss != null)
            GestureDetector(
              onTap: widget.onDismiss,
              child: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(LucideIcons.x, size: 14, color: Color(0x59FFFFFF)),
              ),
            ),
        ],
      ),
    );

    if (blur > 0) {
      body = ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: body,
        ),
      );
    } else {
      body = ClipRRect(borderRadius: radius, child: body);
    }

    return MouseRegion(
      cursor: widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(onTap: widget.onTap, child: body),
    );
  }

  Widget _dot(PerfMode perf) {
    const size = 8.0;
    final dot = DecoratedBox(
      decoration: BoxDecoration(shape: BoxShape.circle, color: widget.accent),
    );
    if (perf == PerfMode.light) {
      return const SizedBox(
          width: size,
          height: size,
          child: DecoratedBox(
            decoration: BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFF5500)),
          ));
    }
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: SizedBox(
        width: size,
        height: size,
        child: FadeTransition(
          opacity: Tween(begin: 0.5, end: 1.0).animate(_pulse),
          child: dot,
        ),
      ),
    );
  }
}

/// Хост-очередь тостов поверх контента: тосты копятся top-right, авто-уходят
/// через [autoDismiss], въезжают/уезжают slide+fade. Потребитель держит [show]
/// через [ToastController] (DI: контроллер инъектируется, не глобал).
class ToastController extends ChangeNotifier {
  final List<_ToastEntry> _entries = [];
  List<_ToastEntry> get entries => List.unmodifiable(_entries);

  void show(
    String message, {
    ToastKind kind = ToastKind.neutral,
    IconData? icon,
    Duration autoDismiss = const Duration(seconds: 4),
  }) {
    final entry = _ToastEntry(message: message, kind: kind, icon: icon);
    _entries.add(entry);
    notifyListeners();
    entry.timer = Timer(autoDismiss, () => dismiss(entry));
  }

  void dismiss(_ToastEntry entry) {
    entry.timer?.cancel();
    if (_entries.remove(entry)) notifyListeners();
  }

  @override
  void dispose() {
    for (final e in _entries) {
      e.timer?.cancel();
    }
    super.dispose();
  }
}

class _ToastEntry {
  final String message;
  final ToastKind kind;
  final IconData? icon;
  Timer? timer;

  _ToastEntry({required this.message, required this.kind, this.icon});
}

/// Скоуп тостера: держит [ToastController], рисует очередь поверх [child] и даёт
/// потомкам единый путь уведомлений ([ToastScope.of]) — вместо разбросанных
/// `ScaffoldMessenger`. Не требует `Scaffold`. Монтировать внутри `ScPerf`/`ScTheme`
/// (тост-карточкам нужен перф-профиль).
class ToastScope extends StatefulWidget {
  final Widget child;

  const ToastScope({super.key, required this.child});

  static ToastController of(BuildContext context) {
    final scope =
        context.getInheritedWidgetOfExactType<_ToastScopeMarker>();
    assert(scope != null, 'ToastScope.of вызван вне ToastScope');
    return scope!.controller;
  }

  static ToastController? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_ToastScopeMarker>()?.controller;

  @override
  State<ToastScope> createState() => _ToastScopeState();
}

class _ToastScopeState extends State<ToastScope> {
  final ToastController _controller = ToastController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ToastScopeMarker(
      controller: _controller,
      child: ToastOverlay(controller: _controller, child: widget.child),
    );
  }
}

class _ToastScopeMarker extends InheritedWidget {
  final ToastController controller;

  const _ToastScopeMarker({required this.controller, required super.child});

  @override
  bool updateShouldNotify(_ToastScopeMarker oldWidget) =>
      controller != oldWidget.controller;
}

/// Накладывает очередь тостов на [child]. offset 48 от верха/правого края.
class ToastOverlay extends StatelessWidget {
  final ToastController controller;
  final Widget child;

  const ToastOverlay({super.key, required this.controller, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          top: 48,
          right: 48,
          child: AnimatedBuilder(
            animation: controller,
            builder: (_, __) => Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final e in controller.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey(e),
                      duration: ScTokens.dFast,
                      curve: ScTokens.easeApple,
                      tween: Tween(begin: 0, end: 1),
                      builder: (_, t, ch) => Opacity(
                        opacity: t,
                        child: Transform.translate(
                            offset: Offset((1 - t) * 24, 0), child: ch),
                      ),
                      child: Toast(message: e.message, kind: e.kind, icon: e.icon),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
