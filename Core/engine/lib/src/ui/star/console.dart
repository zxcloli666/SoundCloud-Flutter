import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:sc_visual/sc_visual.dart';

/// Общая оболочка + словарь кнопок STAR-консоли (легаси `StarConsole.tsx`).
/// Один визуальный язык на все панели поверх живого ядра.

/// Парящая стеклянная консоль, держащая пер-стейт панели (легаси `Console`).
class StarConsole extends StatelessWidget {
  final Widget child;
  const StarConsole({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final perf = PerfProfile.of(context);
    final sigma = perf.sigma(26); // blur(26) saturate(1.5)
    final pad = MediaQuery.of(context).size.width >= 768 ? 22.0 : 20.0;

    final surface = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x1AFFFFFF)), // white/[0.10]
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x0DFFFFFF), Color(0x03FFFFFF), Color(0xB80C0B10)],
          stops: [0, 0.6, 1.0],
        ),
        boxShadow: const [
          BoxShadow(color: Color(0xE6000000), blurRadius: 90, spreadRadius: -30, offset: Offset(0, 30)),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(pad),
        child: child,
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        children: [
          if (sigma > 0)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                child: const SizedBox.expand(),
              ),
            ),
          surface,
          // верхняя specular-волосинка (inset-x-6 top-0 h-px)
          const Positioned(
            left: 24,
            right: 24,
            top: 0,
            height: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0x00FFFFFF), Color(0x66FFFFFF), Color(0x00FFFFFF)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Акцентная primary-кнопка (легаси `PrimaryBtn`): accent-градиент, glow, hover lift.
class PrimaryBtn extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;
  final bool disabled;
  const PrimaryBtn({
    super.key,
    required this.child,
    required this.onPressed,
    this.disabled = false,
  });

  @override
  State<PrimaryBtn> createState() => _PrimaryBtnState();
}

class _PrimaryBtnState extends State<PrimaryBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final palette = ScTheme.paletteOf(context);
    final enabled = !widget.disabled;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: enabled ? widget.onPressed : null,
        child: AnimatedContainer(
          duration: ScTokens.dFast,
          curve: ScTokens.easeApple,
          transform: Matrix4.translationValues(0, enabled && _hover ? -1 : 0, 0),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [palette.accentHover, palette.accent],
            ),
            boxShadow: [
              BoxShadow(color: palette.accentGlow, blurRadius: 36, spreadRadius: -8),
            ],
          ),
          child: Opacity(
            opacity: enabled ? 1 : 0.5,
            child: DefaultTextStyle.merge(
              style: TextStyle(
                color: palette.accentContrast,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
              child: IconTheme.merge(
                data: IconThemeData(color: palette.accentContrast, size: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [widget.child],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Призрачная стеклянная кнопка (легаси `GhostBtn`).
class GhostBtn extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;
  const GhostBtn({super.key, required this.child, required this.onPressed});

  @override
  State<GhostBtn> createState() => _GhostBtnState();
}

class _GhostBtnState extends State<GhostBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: ScTokens.dFast,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: const Color(0x1AFFFFFF)),
            color: _hover ? const Color(0x17FFFFFF) : const Color(0x0DFFFFFF),
          ),
          child: DefaultTextStyle.merge(
            style: TextStyle(
              color: _hover ? Colors.white : const Color(0xCCFFFFFF),
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
            child: IconTheme.merge(
              data: IconThemeData(
                  color: _hover ? Colors.white : const Color(0xCCFFFFFF), size: 16),
              child: Row(mainAxisSize: MainAxisSize.min, children: [widget.child]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Текст-ссылка mono (легаси `LinkBtn`).
class LinkBtn extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  const LinkBtn({super.key, required this.label, required this.onPressed});

  @override
  State<LinkBtn> createState() => _LinkBtnState();
}

class _LinkBtnState extends State<LinkBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Text(
          widget.label.toUpperCase(),
          style: TextStyle(
            fontFamily: starMono,
            fontSize: 11,
            letterSpacing: 11 * 0.12,
            color: _hover ? const Color(0xCCFFFFFF) : const Color(0x66FFFFFF),
          ),
        ),
      ),
    );
  }
}

/// Mono-заголовок панели (легаси `Ttl`).
class Ttl extends StatelessWidget {
  final String text;
  const Ttl(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontFamily: starMono,
          fontSize: 10.5,
          letterSpacing: 10.5 * 0.2,
          color: Color(0x66FFFFFF),
        ),
      ),
    );
  }
}

/// Display (Unbounded) — большие цифры цены/хэндл. Шрифты ещё не вшиты в пакет
/// (§1.3 TODO) — имена запрашиваем, system-fallback как в текущем `theme.dart`.
const String starDisplay = 'Unbounded';

/// Console mono (Geist Mono) — ₽-юнит/серийники/лейблы.
const String starMono = 'Geist Mono';
