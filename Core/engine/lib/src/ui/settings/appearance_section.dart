import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:sc_visual/sc_visual.dart';

import 'settings_primitives.dart';
import 'wallpaper_card.dart';

/// Вид: акцент (ThemeCard) + режим производительности (PerformanceCard, легаси
/// §3.13). [accent]/[onAccent] проводятся через `settingsProvider.accent` — акцент
/// per-user, из него выводится вся дизайн-система (§1.2), поэтому он кормит и
/// `ScTheme(palette:)` в оболочке. [selected]/[onSelected] правят `perfMode` →
/// глобальный [ScPerf], масштабируя тяжесть визуала всего приложения.
class AppearanceSection extends StatelessWidget {
  final int? accent;
  final ValueChanged<int?> onAccent;
  final PerfMode selected;
  final ValueChanged<PerfMode> onSelected;

  const AppearanceSection({
    super.key,
    required this.accent,
    required this.onAccent,
    required this.selected,
    required this.onSelected,
  });

  static const _cards = <_PerfCardSpec>[
    _PerfCardSpec(PerfMode.light, 'Лёгкий', 'Плоско и быстро', 0, 0),
    _PerfCardSpec(PerfMode.medium, 'Средний', 'Баланс эффектов', 9, 2),
    _PerfCardSpec(PerfMode.beauty, 'Красота', 'Полный эффект', 18, 4),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ThemeCard(accent: accent, onAccent: onAccent),
        const SizedBox(height: 20),
        SettingsCard(
          title: 'Производительность',
          icon: LucideIcons.zap,
          description:
              'Насколько тяжёлым делать визуал. «Красота» — как задумано.',
          child: GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.92,
            children: [
              for (final c in _cards)
                _PerfCard(
                  spec: c,
                  active: c.mode == selected,
                  onTap: () => onSelected(c.mode),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const WallpaperCard(),
      ],
    );
  }
}

/// Акцентная палитра (легаси `ThemeCard`): 10 пресет-сватчей + кастомный цвет.
/// Выбранный ARGB пишется в `settings.accent`; вся дизайн-система выводит из него
/// hover/glow/selection (§1.2). Без конического колеса — пресеты + HSV-лист.
const _presetAccents = <int>[
  0xFFFF5500,
  0xFFFF3366,
  0xFF7C3AED,
  0xFF3B82F6,
  0xFF06B6D4,
  0xFF10B981,
  0xFFEAB308,
  0xFFEF4444,
  0xFFF97316,
  0xFF8B5CF6,
];

class ThemeCard extends StatelessWidget {
  final int? accent;
  final ValueChanged<int?> onAccent;

  const ThemeCard({super.key, required this.accent, required this.onAccent});

  @override
  Widget build(BuildContext context) {
    final palette = ScTheme.paletteOf(context);
    // Эффективный акцент: кастомный из настроек или текущий темы (дефолт #ff5500).
    final current = accent ?? palette.accent.toARGB32();
    final isPreset = _presetAccents.contains(current);
    return SettingsCard(
      title: 'Акцент',
      icon: Icons.palette_rounded,
      description: 'Цвет, из которого выводится вся подсветка интерфейса.',
      child: GridView.count(
        crossAxisCount: 6,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1,
        children: [
          for (final c in _presetAccents)
            _Swatch(
              color: Color(c),
              active: current == c,
              onTap: () => onAccent(c),
            ),
          _CustomSwatch(
            color: isPreset ? null : Color(current),
            active: !isPreset,
            onTap: () => _openPicker(context, current),
          ),
        ],
      ),
    );
  }

  Future<void> _openPicker(BuildContext context, int start) async {
    final picked = await showDialog<int>(
      context: context,
      builder: (_) => _ColorPickerDialog(initial: start),
    );
    if (picked != null) onAccent(picked);
  }
}

/// Квадрат-сватч пресета: заливка цветом, активный — белая рамка + glow.
class _Swatch extends StatelessWidget {
  final Color color;
  final bool active;
  final VoidCallback onTap;

  const _Swatch({required this.color, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: ScTokens.dFast,
          curve: ScTokens.easeApple,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? Colors.white : const Color(0x14FFFFFF),
              width: active ? 2 : 1,
            ),
            boxShadow: active
                ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 16)]
                : null,
          ),
          child: active
              ? const Icon(LucideIcons.check, size: 16, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}

/// Кастомный сватч (легаси dashed Custom): пунктирная рамка + пипетка; активен,
/// когда выбранный цвет вне пресетов — тогда показывает сам цвет.
class _CustomSwatch extends StatelessWidget {
  final Color? color;
  final bool active;
  final VoidCallback onTap;

  const _CustomSwatch({
    required this.color,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: CustomPaint(
          painter: _DashedBorderPainter(
            color: active ? Colors.white : const Color(0x40FFFFFF),
          ),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.colorize_rounded,
              size: 16,
              color: color != null ? Colors.white : const Color(0x73FFFFFF),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;

  const _DashedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(12),
    );
    final path = Path()..addRRect(rrect);
    const dash = 4.0;
    const gap = 3.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dash),
          paint,
        );
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.color != color;
}

class _PerfCardSpec {
  final PerfMode mode;
  final String label;
  final String desc;
  final double orbBlur;
  final int motes;

  const _PerfCardSpec(this.mode, this.label, this.desc, this.orbBlur, this.motes);
}

class _PerfCard extends StatefulWidget {
  final _PerfCardSpec spec;
  final bool active;
  final VoidCallback onTap;

  const _PerfCard({required this.spec, required this.active, required this.onTap});

  @override
  State<_PerfCard> createState() => _PerfCardState();
}

class _PerfCardState extends State<_PerfCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    final borderColor = active
        ? const Color(0x4DFFFFFF)
        : _hover
            ? const Color(0x26FFFFFF)
            : const Color(0x0FFFFFFF);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hover ? 1.03 : 1,
          duration: ScTokens.dFast,
          curve: ScTokens.easeApple,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: borderColor,
                  width: active ? 1.5 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PerfPreview(orbBlur: widget.spec.orbBlur, motes: widget.spec.motes),
                  Container(
                    color: const Color(0x08FFFFFF),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.spec.label,
                          style: TextStyle(
                            color: active ? const Color(0xE6FFFFFF) : const Color(0x8CFFFFFF),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.spec.desc,
                          style: const TextStyle(
                            color: Color(0x59FFFFFF),
                            fontSize: 10,
                            height: 1.2,
                          ),
                        ),
                      ],
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

/// Мини-сцена: акцентный орб с блюром по режиму + точки-частицы + контур карточки
/// (легаси `PerfPreview`).
class _PerfPreview extends StatelessWidget {
  final double orbBlur;
  final int motes;

  const _PerfPreview({required this.orbBlur, required this.motes});

  @override
  Widget build(BuildContext context) {
    final palette = ScTheme.paletteOf(context);
    return SizedBox(
      height: 64,
      child: ColoredBox(
        color: const Color(0xFF0C0C10),
        child: Stack(
          children: [
            if (orbBlur > 0)
              Positioned(
                top: -12,
                left: -8,
                child: ImageFilteredBox(
                  blur: orbBlur / 2,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [palette.accentGlow, const Color(0x00000000)],
                        stops: const [0, 0.7],
                      ),
                    ),
                  ),
                ),
              ),
            for (var i = 0; i < motes; i++)
              Positioned(
                left: 64 * (0.18 + i * 0.22),
                top: 64 * (0.28 + ((i * 37) % 42) / 100),
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.accent,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: palette.accentGlow, blurRadius: 4)],
                  ),
                ),
              ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Container(
                height: 12,
                decoration: BoxDecoration(
                  color: orbBlur > 0 ? const Color(0x0DFFFFFF) : const Color(0x06FFFFFF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0x14FFFFFF)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Локальная обёртка `BackdropFilter`-free блюра орба превью (без backdrop —
/// блюрим сам слой, не фон).
class ImageFilteredBox extends StatelessWidget {
  final double blur;
  final Widget child;

  const ImageFilteredBox({super.key, required this.blur, required this.child});

  @override
  Widget build(BuildContext context) {
    if (blur <= 0) return child;
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
      child: child,
    );
  }
}

/// Кастомный цвет — замена `<input type=color>` (без конического колеса):
/// saturation/value-плоскость + hue-полоса. Возвращает ARGB через `pop`.
class _ColorPickerDialog extends StatefulWidget {
  final int initial;

  const _ColorPickerDialog({required this.initial});

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late HSVColor _hsv = HSVColor.fromColor(Color(widget.initial));

  Color get _color => _hsv.toColor();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: GlassPanel(
          radius: 24,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Свой цвет',
                style: TextStyle(
                  color: Color(0xD9FFFFFF),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              AspectRatio(
                aspectRatio: 1.6,
                child: _SatValField(
                  hsv: _hsv,
                  onChanged: (h) => setState(() => _hsv = h),
                ),
              ),
              const SizedBox(height: 14),
              _HueStrip(
                hue: _hsv.hue,
                onChanged: (h) => setState(() => _hsv = _hsv.withHue(h)),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _color,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0x24FFFFFF)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '#${_color.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
                      style: const TextStyle(
                        color: Color(0xB3FFFFFF),
                        fontFamily: 'monospace',
                        fontSize: 13,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  GlassButton(
                    onTap: () => Navigator.of(context).pop(_color.toARGB32()),
                    child: const Text(
                      'Готово',
                      style: TextStyle(
                        color: Color(0xE6FFFFFF),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Плоскость saturation×value под текущий hue; drag = выбор.
class _SatValField extends StatelessWidget {
  final HSVColor hsv;
  final ValueChanged<HSVColor> onChanged;

  const _SatValField({required this.hsv, required this.onChanged});

  void _update(Offset local, Size size) {
    final s = (local.dx / size.width).clamp(0.0, 1.0);
    final v = (1 - local.dy / size.height).clamp(0.0, 1.0);
    onChanged(hsv.withSaturation(s).withValue(v));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        return GestureDetector(
          onPanDown: (d) => _update(d.localPosition, size),
          onPanUpdate: (d) => _update(d.localPosition, size),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor(),
                    ),
                  ),
                ),
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.white, Color(0x00FFFFFF)],
                      ),
                    ),
                  ),
                ),
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x00000000), Color(0xFF000000)],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: hsv.saturation * size.width - 7,
                  top: (1 - hsv.value) * size.height - 7,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [
                        BoxShadow(color: Color(0x80000000), blurRadius: 4),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Горизонтальная hue-полоса (0..360); drag = выбор тона.
class _HueStrip extends StatelessWidget {
  final double hue;
  final ValueChanged<double> onChanged;

  const _HueStrip({required this.hue, required this.onChanged});

  void _update(double dx, double width) =>
      onChanged((dx / width).clamp(0.0, 1.0) * 360);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final width = c.maxWidth;
        return GestureDetector(
          onPanDown: (d) => _update(d.localPosition.dx, width),
          onPanUpdate: (d) => _update(d.localPosition.dx, width),
          child: SizedBox(
            height: 16,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFFFF0000),
                          Color(0xFFFFFF00),
                          Color(0xFF00FF00),
                          Color(0xFF00FFFF),
                          Color(0xFF0000FF),
                          Color(0xFFFF00FF),
                          Color(0xFFFF0000),
                        ],
                      ),
                    ),
                    child: SizedBox.expand(),
                  ),
                ),
                Positioned(
                  left: (hue / 360) * width - 7,
                  top: -1,
                  child: Container(
                    width: 14,
                    height: 18,
                    decoration: BoxDecoration(
                      color: HSVColor.fromAHSV(1, hue, 1, 1).toColor(),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [
                        BoxShadow(color: Color(0x80000000), blurRadius: 4),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
