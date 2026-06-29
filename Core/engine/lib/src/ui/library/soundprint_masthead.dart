import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:sc_visual/sc_visual.dart';

import 'artwork_mosaic.dart';
import 'avatar_orb.dart';

/// «Sound Print» — коллекция как живой портрет вкуса (легаси `SoundPrintMasthead`).
/// Скруглённая плита: фрост над атмосферой страницы, мозаика лайкнутых обложек,
/// аватар-орб, приветствие по времени суток и акцентный CTA «играть свой звук»
/// (перемешать лайки). Spectrum-бары вкуса требуют жанровых данных, которых
/// бэкенд пока не отдаёт — здесь их нет.
class SoundPrintMasthead extends StatelessWidget {
  final String username;
  final String? avatarUrl;
  final List<String?> likedCovers;
  final bool shuffleEnabled;
  final bool shuffleBusy;
  final VoidCallback? onShuffle;

  const SoundPrintMasthead({
    super.key,
    required this.username,
    required this.avatarUrl,
    required this.likedCovers,
    this.shuffleEnabled = false,
    this.shuffleBusy = false,
    this.onShuffle,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ScTheme.paletteOf(context);
    final accent = palette.accent;
    final glow = accent.withValues(alpha: 0.32);
    final perf = ScPerf.of(context);
    final blur = perf == PerfMode.beauty
        ? ScTokens.blurBeautyNormal
        : perf == PerfMode.medium
            ? ScTokens.blurMediumNormal
            : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 640;
        final radius = BorderRadius.circular(36); // rounded-[2.25rem]
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: const Color(0x1AFFFFFF), width: 0.5),
            boxShadow: [
              const BoxShadow(color: Color(0x6B000000), blurRadius: 80, offset: Offset(0, 30)),
              BoxShadow(color: glow, blurRadius: 70),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              children: [
                _frost(blur, accent),
                ArtworkMosaic(covers: likedCovers),
                _hueWash(accent),
                Padding(
                  padding: EdgeInsets.all(narrow ? 24 : 32),
                  child: _body(context, palette, narrow),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Фрост — размывает атмосферу страницы за плитой; в light — плоская заливка.
  Widget _frost(double blur, Color accent) {
    if (blur <= 0) {
      return const Positioned.fill(child: ColoredBox(color: Color(0xEB0E0D12)));
    }
    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: const Alignment(-0.6, -1),
              end: const Alignment(0.6, 1),
              colors: [accent.withValues(alpha: 0.1), const Color(0x8C0C0B10)],
            ),
          ),
        ),
      ),
    );
  }

  /// Доминантный размыв из верхнего левого угла.
  Widget _hueWash(Color accent) {
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.9, -1.2),
              radius: 1.3,
              colors: [accent.withValues(alpha: 0.22), Colors.transparent],
              stops: const [0, 0.58],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, ScPalette palette, bool narrow) {
    final greeting = _greeting(username);
    final cta = (shuffleEnabled || shuffleBusy)
        ? _ShuffleButton(
            label: 'Включить свой звук',
            busy: shuffleBusy,
            onTap: onShuffle,
            palette: palette,
            compact: narrow,
          )
        : null;

    final head = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AvatarOrb(avatarUrl: avatarUrl, size: narrow ? 84 : 100),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'БИБЛИОТЕКА',
                style: const TextStyle(
                  color: Color(0x66FFFFFF),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3.0,
                ),
              ),
              const SizedBox(height: 6),
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [const Color(0xFFFFFFFF), palette.accentHover],
                ).createShader(bounds),
                child: Text(
                  greeting,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: narrow ? 26 : 34,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (cta != null && !narrow) ...[const SizedBox(width: 16), cta],
      ],
    );

    if (cta == null || !narrow) return head;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [head, const SizedBox(height: 20), cta],
    );
  }

  static String _greeting(String name) {
    final h = DateTime.now().hour;
    final part = h < 5
        ? 'Доброй ночи'
        : h < 12
            ? 'Доброе утро'
            : h < 18
                ? 'Добрый день'
                : 'Добрый вечер';
    return '$part, $name';
  }
}

/// Акцентный pill <<играть свой звук>>: радиальная поверхность как у play-орба.
class _ShuffleButton extends StatefulWidget {
  final String label;
  final bool busy;
  final VoidCallback? onTap;
  final ScPalette palette;
  final bool compact;

  const _ShuffleButton({
    required this.label,
    required this.busy,
    required this.onTap,
    required this.palette,
    required this.compact,
  });

  @override
  State<_ShuffleButton> createState() => _ShuffleButtonState();
}

class _ShuffleButtonState extends State<_ShuffleButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final disabled = widget.busy || widget.onTap == null;
    return MouseRegion(
      cursor: disabled ? MouseCursor.defer : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: disabled ? null : widget.onTap,
        child: AnimatedScale(
          scale: _hover && !disabled ? 1.04 : 1.0,
          duration: ScTokens.dSidebar,
          curve: ScTokens.easeApple,
          child: Opacity(
            opacity: disabled ? 0.6 : 1,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: widget.compact ? 16 : 20,
                vertical: widget.compact ? 12 : 13,
              ),
              decoration: BoxDecoration(
                gradient: p.playGradient,
                borderRadius: BorderRadius.circular(9999),
                border: Border.all(color: const Color(0x38FFFFFF)),
                boxShadow: [
                  BoxShadow(color: p.accentGlow, blurRadius: 30, offset: const Offset(0, 12)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  widget.busy
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(p.accentContrast),
                          ),
                        )
                      : Icon(LucideIcons.shuffle, size: 18, color: p.accentContrast),
                  const SizedBox(width: 10),
                  Text(
                    widget.label,
                    style: TextStyle(
                      color: p.accentContrast,
                      fontSize: widget.compact ? 13 : 14,
                      fontWeight: FontWeight.w700,
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
