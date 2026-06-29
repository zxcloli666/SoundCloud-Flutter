import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../providers.dart';
import '../../rust/dto.dart';
import '../library/soundprint_bars.dart';
import '../search/genre_palette.dart';
import 'vibe_portal.dart';

/// Шапка «Эфира»: позывные станции + приветствие (градиент-имя) и аватар в
/// акцентном кольце; ниже — спектр вкуса (soundprint) и vibe-портал. Лёгкая
/// поверхность без blur (легаси `RiverMasthead`). Выбор жанра в спектре
/// ретинтит имя/кольцо (страницу ретинтит [HomePage] через атмосферу).
class RiverMasthead extends ConsumerWidget {
  final MeDto? me;
  final List<GenreShare> spectrum;
  final String? selected;
  final ValueChanged<String?> onSelect;

  const RiverMasthead({
    super.key,
    required this.me,
    required this.spectrum,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ScTheme.paletteOf(context);
    final isPlaying = ref.watch(playerProvider) != null;
    final accent =
        selected == null ? palette.accent : genreColor(selected, palette.accent);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _greetBlock(ref, accent, isPlaying)),
            const SizedBox(width: 24),
            _avatar(accent),
          ],
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1024;
            final hasSpectrum = spectrum.isNotEmpty;
            final bars = hasSpectrum
                ? Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: ScTokens.glassTint,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: ScTokens.glassFeaturedBorder),
                    ),
                    child: SoundprintBars(
                      spectrum: spectrum,
                      selected: selected,
                      onSelect: onSelect,
                      label: ref.tr('library.soundprint'),
                    ),
                  )
                : null;
            final portal = VibePortal(
              title: ref.tr('soundwave.vibeCta.title'),
              subtitle: ref.tr('soundwave.vibeCta.subtitle'),
              badge: ref.tr('soundwave.vibeCta.badge'),
              onTap: () =>
                  ref.read(routerProvider.notifier).selectTab(const SearchRoute()),
            );

            if (wide) {
              return Row(
                // Блок портала прижат к низу строки (как в Tauri `justify-end`);
                // вертикальное центрирование контента — внутри самого портала.
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (bars != null) ...[
                    Expanded(child: bars),
                    const SizedBox(width: 16),
                    SizedBox(width: 360, child: portal),
                  ] else
                    Expanded(child: portal),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (bars != null) ...[bars, const SizedBox(height: 16)],
                portal,
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _greetBlock(WidgetRef ref, Color accent, bool isPlaying) {
    final name = me?.username ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _liveBadge(accent, isPlaying),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                ref.tr('soundwave.river.personal'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0x4DFFFFFF),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.3,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ShaderMask(
          shaderCallback: (bounds) => _nameGradient(accent).createShader(bounds),
          child: Text(
            ref.tr(_greetingKey(), {'name': name}),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              height: 1.05,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          ref.tr('soundwave.tagline'),
          style: const TextStyle(color: Color(0x80FFFFFF), fontSize: 13.5),
        ),
      ],
    );
  }

  Widget _liveBadge(Color accent, bool isPlaying) {
    return Consumer(
      builder: (context, ref, _) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0x08FFFFFF),
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(color: const Color(0x1FFFFFFF)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LivePulse(accent: accent, playing: isPlaying),
            const SizedBox(width: 6),
            Text(
              ref.tr('soundwave.river.live'),
              style: const TextStyle(
                color: Color(0xB3FFFFFF),
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatar(Color accent) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: accent.withValues(alpha: 0.4), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.32),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipOval(child: Avatar(src: me?.avatarUrl, size: 64)),
    );
  }

  String _greetingKey() {
    final h = DateTime.now().hour;
    if (h < 5) return 'library.greetNight';
    if (h < 12) return 'library.greetMorning';
    if (h < 18) return 'library.greetDay';
    return 'library.greetEvening';
  }

  LinearGradient _nameGradient(Color accent) {
    final hover = _lighten(accent);
    return LinearGradient(
      begin: const Alignment(-1, -0.3),
      end: const Alignment(1, 0.3),
      colors: [Colors.white, Colors.white, hover, accent, Colors.white, Colors.white],
      stops: const [0, 0.28, 0.45, 0.58, 0.75, 1],
    );
  }

  Color _lighten(Color c) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + 0.1).clamp(0.0, 1.0)).toColor();
  }
}

/// LIVE-точка: пульсирует только во время воспроизведения (легаси `riv-pulse`).
class _LivePulse extends StatefulWidget {
  final Color accent;
  final bool playing;

  const _LivePulse({required this.accent, required this.playing});

  @override
  State<_LivePulse> createState() => _LivePulseState();
}

class _LivePulseState extends State<_LivePulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_LivePulse old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final animate = widget.playing && ScPerf.of(context) != PerfMode.light;
    if (animate && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!animate && _c.isAnimating) {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glow = ScPerf.of(context) == PerfMode.beauty;
    return FadeTransition(
      opacity: Tween(begin: 1.0, end: 0.35).animate(_c),
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: widget.accent,
          shape: BoxShape.circle,
          boxShadow:
              glow ? [BoxShadow(color: widget.accent, blurRadius: 8)] : null,
        ),
      ),
    );
  }
}
