import 'package:flutter/material.dart';
import 'package:sc_visual/sc_visual.dart';

import '../search/genre_palette.dart';

/// «Звуковой отпечаток» — топ-жанры коллекции колонками света (легаси
/// `SoundprintBars`). Высота столбика — доля жанра, цвет — сам жанр. Это и
/// переключатель: тап по столбику ретинтит страницу в его цвет и фильтрует,
/// повторный тап — сброс. Пустой спектр не рисуется.
class SoundprintBars extends StatefulWidget {
  final List<GenreShare> spectrum;
  final String? selected;
  final ValueChanged<String?> onSelect;

  /// Подпись над спектром (i18n `library.soundprint`).
  final String label;

  const SoundprintBars({
    super.key,
    required this.spectrum,
    required this.selected,
    required this.onSelect,
    required this.label,
  });

  @override
  State<SoundprintBars> createState() => _SoundprintBarsState();
}

class _SoundprintBarsState extends State<SoundprintBars>
    with SingleTickerProviderStateMixin {
  // Появление: столбики «вырастают» снизу со сдвигом по индексу (легаси `sp-rise`).
  late final AnimationController _rise = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void dispose() {
    _rise.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spectrum = widget.spectrum;
    if (spectrum.isEmpty) return const SizedBox.shrink();

    final accent = ScTheme.paletteOf(context).accent;
    final maxShare = spectrum.first.share <= 0 ? 1.0 : spectrum.first.share;
    final hasSel = widget.selected != null;
    final glow = ScPerf.of(context) != PerfMode.light;
    final headColor = genreColor(spectrum.first.genre, accent);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.audioLines, size: 13, color: headColor),
            const SizedBox(width: 8),
            Text(
              widget.label.toUpperCase(),
              style: const TextStyle(
                color: Color(0x73FFFFFF),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 88,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < spectrum.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _Bar(
                    share: spectrum[i],
                    color: genreColor(spectrum[i].genre, accent),
                    fillFactor: (0.32 + (spectrum[i].share / maxShare) * 0.68)
                        .clamp(0.0, 1.0),
                    selected: widget.selected == spectrum[i].genre,
                    dimmed: hasSel && widget.selected != spectrum[i].genre,
                    glow: glow,
                    rise: CurvedAnimation(
                      parent: _rise,
                      curve: Interval(
                        (i * 0.07).clamp(0.0, 0.9),
                        1,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                    onTap: () => widget.onSelect(
                      widget.selected == spectrum[i].genre
                          ? null
                          : spectrum[i].genre,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Один столбик жанра: цвет-градиент по высоте доли, подпись и процент.
class _Bar extends StatefulWidget {
  final GenreShare share;
  final Color color;
  final double fillFactor;
  final bool selected;
  final bool dimmed;
  final bool glow;
  final Animation<double> rise;
  final VoidCallback onTap;

  const _Bar({
    required this.share,
    required this.color,
    required this.fillFactor,
    required this.selected,
    required this.dimmed,
    required this.glow,
    required this.rise,
    required this.onTap,
  });

  @override
  State<_Bar> createState() => _BarState();
}

class _BarState extends State<_Bar> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.color;
    final pct = (widget.share.share * 100).round();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedOpacity(
          duration: ScTokens.dFast,
          opacity: widget.dimmed ? 0.45 : 1,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: AnimatedBuilder(
                    animation: widget.rise,
                    builder: (context, _) => FractionallySizedBox(
                      // На hover столбик слегка подрастает (живой отклик).
                      heightFactor: (widget.fillFactor *
                              widget.rise.value *
                              (_hover ? 1.06 : 1.0))
                          .clamp(0.0, 1.0),
                      widthFactor: 1,
                      child: _column(c),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.share.genre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.5,
                  color: widget.selected
                      ? Colors.white
                      : (_hover ? const Color(0xF2FFFFFF) : const Color(0x8CFFFFFF)),
                ),
              ),
              Text(
                '$pct%',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 9,
                  color: Color(0x4DFFFFFF),
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _column(Color c) {
    final selected = widget.selected;
    final lit = selected || _hover; // hover светит как лёгкий «выбор»
    final boxShadow = <BoxShadow>[
      // inset 0 1px 0 — верхний хайлайт; Flutter inset нет, эмулируем тонкой
      // верхней подсветкой через градиент (ниже), а тенью — внешнее свечение.
      if (selected)
        BoxShadow(color: c.withValues(alpha: 0.6), blurRadius: 26)
      else if (_hover && widget.glow)
        BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 22)
      else if (widget.glow)
        BoxShadow(color: c.withValues(alpha: 0.33), blurRadius: 18),
    ];
    return AnimatedContainer(
      duration: ScTokens.dFast,
      curve: ScTokens.easeApple,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            lit ? _boost(c) : c,
            c.withValues(alpha: 0.12),
          ],
        ),
        border: Border(
          top: BorderSide(color: c.withValues(alpha: 0.85), width: 1),
        ),
        boxShadow: boxShadow,
      ),
    );
  }

  // Выбранный столбик чуть ярче (легаси `saturate(1.2) brightness(1.08)`).
  Color _boost(Color c) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withSaturation((hsl.saturation * 1.2).clamp(0.0, 1.0))
        .withLightness((hsl.lightness * 1.08).clamp(0.0, 1.0))
        .toColor();
  }
}
