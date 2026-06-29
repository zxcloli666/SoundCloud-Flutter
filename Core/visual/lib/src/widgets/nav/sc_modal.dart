import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../perf.dart';
import '../../theme.dart';
import '../../tokens.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

enum ScModalSize { sm, md, lg, xl }

double _maxWidth(ScModalSize size) => switch (size) {
      ScModalSize.sm => 420,
      ScModalSize.md => 520,
      ScModalSize.lg => 640,
      ScModalSize.xl => 760,
    };

/// Стеклянный каркас диалога (легаси `Modal`): карточка rounded-28, акцентный
/// wash сверху, specular-волосок, close-X. Контент произвольный; [title]/
/// [description] — типовая шапка. Открывать через [showScModal].
class ScModal extends StatelessWidget {
  final Widget child;
  final ScModalSize size;
  final String? title;
  final String? description;
  final VoidCallback? onClose;
  final EdgeInsetsGeometry padding;

  const ScModal({
    super.key,
    required this.child,
    this.size = ScModalSize.md,
    this.title,
    this.description,
    this.onClose,
    this.padding = const EdgeInsets.fromLTRB(28, 26, 28, 28),
  });

  @override
  Widget build(BuildContext context) {
    final accentGlow = ScTheme.paletteOf(context).accentGlow;
    final radius = BorderRadius.circular(28);
    final maxW = _maxWidth(size);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: [
                const BoxShadow(
                    color: Color(0x9E000000), blurRadius: 110, offset: Offset(0, 40)),
                BoxShadow(color: accentGlow, blurRadius: 80),
              ],
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: Stack(
                children: [
                  _surface(accentGlow, radius),
                  _content(),
                  Positioned(top: 0, left: 32, right: 32, child: _specularHairline()),
                  Positioned(top: 14, right: 14, child: _closeButton(context)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _surface(Color accentGlow, BorderRadius radius) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-0.4, -1),
            end: Alignment(0.4, 1),
            colors: [Color(0xF717161C), Color(0xFC0A090D)], // 168deg, 0.97 → 0.99
          ),
          border: Border.fromBorderSide(
              BorderSide(color: Color(0x1FFFFFFF), width: 0.5)),
        ),
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            height: 112,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.0,
                  colors: [accentGlow.withValues(alpha: accentGlow.a * 0.7), const Color(0x00000000)],
                  stops: const [0, 0.72],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content() {
    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(right: 28),
              child: Text(
                title!,
                style: const TextStyle(
                    color: Color(0xEBFFFFFF),
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
            ),
          if (description != null) ...[
            const SizedBox(height: 6),
            Text(
              description!,
              style: const TextStyle(color: Color(0x73FFFFFF), fontSize: 12.5),
            ),
          ],
          if (title != null || description != null) const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _specularHairline() {
    return const SizedBox(
      height: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0x00FFFFFF), Color(0x59FFFFFF), Color(0x00FFFFFF)],
          ),
        ),
      ),
    );
  }

  Widget _closeButton(BuildContext context) {
    return _CloseButton(onTap: onClose ?? () => Navigator.of(context).maybePop());
  }
}

class _CloseButton extends StatefulWidget {
  final VoidCallback onTap;

  const _CloseButton({required this.onTap});

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _hover ? const Color(0x14FFFFFF) : Colors.transparent,
          ),
          child: Icon(LucideIcons.x,
              size: 18,
              color: _hover ? const Color(0xEBFFFFFF) : const Color(0x73FFFFFF)),
        ),
      ),
    );
  }
}

/// Открывает [ScModal] с фрост-затемнением фона и scale(0.96→1)+fade входом.
/// [builder] получает контекст диалога; закрывать — `Navigator.pop(ctx, result)`.
Future<T?> showScModal<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool dismissible = true,
}) {
  final palette = ScTheme.paletteOf(context);
  final perf = ScPerf.of(context);
  final overlayBlur = perf == PerfMode.light ? 0.0 : 4.0;

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: 'modal',
    barrierColor: const Color(0x99000000), // black/60
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (ctx, _, __) => ScTheme(
      palette: palette,
      child: ScPerf(
        mode: perf,
        child: Material(
          type: MaterialType.transparency,
          child: Builder(builder: builder),
        ),
      ),
    ),
    transitionBuilder: (_, anim, __, child) {
      final curved = CurvedAnimation(parent: anim, curve: ScTokens.easeApple);
      Widget content = FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: 0.96, end: 1.0).animate(curved),
          child: child,
        ),
      );
      if (overlayBlur > 0) {
        content = BackdropFilter(
          filter: ImageFilter.blur(
              sigmaX: overlayBlur * anim.value, sigmaY: overlayBlur * anim.value),
          child: content,
        );
      }
      return content;
    },
  );
}
