import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

import '../../perf.dart';
import '../../theme.dart';
import '../../tokens.dart';

/// Пустое состояние — приглашающая плашка, никогда не серое «нет результатов».
///
/// По умолчанию (только [icon] + [title]) — минимальная форма из GLASS_UI_GUIDE
/// §5.13: стеклянный круг 64×64 + приглушённая иконка + одна строка.
/// Если задан [body] (и опц. [cta]/[onAction]) — крупная стеклянная плашка из
/// поиска (landing/dive/text/vibe), с акцентным CTA-шиммером.
class EmptyState extends StatelessWidget {
  final Widget icon;
  final String title;
  final String? body;
  final String? cta;
  final Widget? ctaIcon;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.cta,
    this.ctaIcon,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return body == null ? _minimal(context) : _plaque(context);
  }

  Widget _minimal(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 56),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _iconCircle(context, glow: false),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ScTokens.textTertiary, // white/25..30
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _plaque(BuildContext context) {
    final blur = _blur(ScPerf.of(context));
    Widget panel = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: blur > 0
              ? const LinearGradient(
                  begin: Alignment(-0.5, -1),
                  end: Alignment(0.5, 1),
                  colors: [Color(0x0FFFFFFF), Color(0x05FFFFFF)],
                )
              : null,
          color: blur > 0 ? null : const Color(0xD9121216), // rgba(18,18,22,0.85)
          borderRadius: BorderRadius.circular(36), // rounded-[2.25rem]
          border: Border.all(color: const Color(0x1AFFFFFF)), // white/0.1
          boxShadow: const [
            BoxShadow(color: Color(0x66000000), blurRadius: 80, offset: Offset(0, 30)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _iconCircle(context, glow: true),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xE6FFFFFF),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0x73FFFFFF), // white/45
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              if (cta != null && onAction != null) ...[
                const SizedBox(height: 20),
                _CtaButton(label: cta!, icon: ctaIcon, onTap: onAction!),
              ],
            ],
          ),
        ),
      ),
    );

    if (blur > 0) {
      panel = ClipRRect(
        borderRadius: BorderRadius.circular(36),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: panel,
        ),
      );
    }
    return Center(child: Padding(padding: const EdgeInsets.all(16), child: panel));
  }

  Widget _iconCircle(BuildContext context, {required bool glow}) {
    final accent = ScTheme.paletteOf(context).accent;
    // Минимальный вариант (§4.5): стеклянный КРУГ white/3 + 0.5px white/6.
    // Плашка-вариант (поиск): акцентная rounded-square плитка со свечением.
    return Container(
      width: 64,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: glow ? const Color(0x0AFFFFFF) : const Color(0x08FFFFFF), // white/4 : white/3
        shape: glow ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: glow ? BorderRadius.circular(ScTokens.rCard) : null,
        border: Border.all(
          color: glow ? const Color(0x14FFFFFF) : const Color(0x0FFFFFFF), // white/8 : white/6
          width: glow ? 1 : 0.5,
        ),
        boxShadow: glow && ScPerf.of(context) == PerfMode.beauty
            ? [BoxShadow(color: accent.withValues(alpha: 0.2), blurRadius: 30)]
            : null,
      ),
      child: IconTheme.merge(
        data: IconThemeData(
          color: glow ? accent : const Color(0x26FFFFFF), // accent / white/15
          size: 24,
        ),
        child: icon,
      ),
    );
  }
}

double _blur(PerfMode mode) => switch (mode) {
      PerfMode.beauty => ScTokens.blurBeautyNormal,
      PerfMode.medium => ScTokens.blurMediumNormal,
      PerfMode.light => 0,
    };

/// Акцентный pill с шиммером (легаси CTA `EmptyState`).
class _CtaButton extends StatefulWidget {
  final String label;
  final Widget? icon;
  final VoidCallback onTap;

  const _CtaButton({required this.label, required this.onTap, this.icon});

  @override
  State<_CtaButton> createState() => _CtaButtonState();
}

class _CtaButtonState extends State<_CtaButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final palette = ScTheme.paletteOf(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hover ? 1.03 : 1.0,
          duration: ScTokens.dGlass,
          curve: ScTokens.easeApple,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [palette.accent, palette.accentHover],
              ),
              borderRadius: BorderRadius.circular(9999),
              boxShadow: [
                BoxShadow(
                  color: palette.accentGlow,
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[
                  IconTheme.merge(
                    data: IconThemeData(color: palette.accentContrast, size: 16),
                    child: widget.icon!,
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  widget.label,
                  style: TextStyle(
                    color: palette.accentContrast,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
