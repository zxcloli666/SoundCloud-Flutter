import 'package:flutter/material.dart';

import '../../glass.dart';
import '../../tokens.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Полоса эквалайзера: частота + усиление в дБ.
class EqualizerBand {
  final String label;
  final double gain;

  const EqualizerBand({required this.label, required this.gain});
}

/// Пресет эквалайзера: имя кнопки + 10 значений усиления.
class EqualizerPreset {
  final String id;
  final String label;
  final List<double> gains;

  const EqualizerPreset({required this.id, required this.label, required this.gains});
}

/// Сетка эквалайзера 1:1 с легаси (`lib/equalizer.ts`): 10 полос, ±12 дБ,
/// частотные подписи и встроенные пресеты (русские лейблы). Каталог общий —
/// хост его потребляет, чтобы band-индексы и пресеты сходились с движком.
const int eqBandCount = 10;
const List<String> eqBandLabels = ['32', '64', '125', '250', '500', '1K', '2K', '4K', '8K', '16K'];
const List<double> eqFlatGains = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0];

const List<EqualizerPreset> eqPresets = [
  EqualizerPreset(id: 'flat', label: 'Ровный', gains: eqFlatGains),
  EqualizerPreset(id: 'bassBoost', label: 'Бас+', gains: [6, 5, 4, 2, 0, 0, 0, 0, 0, 0]),
  EqualizerPreset(id: 'bassDestroyer', label: 'Сабвуфер', gains: [12, 12, 10, 7, 3, 0, -2, -4, -4, -5]),
  EqualizerPreset(id: 'trebleBoost', label: 'Верха+', gains: [0, 0, 0, 0, 0, 0, 2, 4, 5, 6]),
  EqualizerPreset(id: 'vocal', label: 'Вокал', gains: [-2, -1, 0, 2, 4, 4, 3, 1, 0, -1]),
  EqualizerPreset(id: 'rock', label: 'Рок', gains: [4, 3, 1, 0, -1, 0, 2, 3, 4, 4]),
  EqualizerPreset(id: 'electronic', label: 'Электроника', gains: [5, 4, 2, 0, -1, 0, 1, 3, 4, 5]),
  EqualizerPreset(id: 'classical', label: 'Классика', gains: [0, 0, 0, 0, 0, 0, -2, -3, -3, -4]),
  EqualizerPreset(id: 'loudness', label: 'Громкость', gains: [5, 4, 1, 0, -1, 0, -1, 0, 3, 4]),
  EqualizerPreset(id: 'vShape', label: 'V-образный', gains: [5, 3, 1, -1, -3, -3, -1, 1, 3, 5]),
  EqualizerPreset(id: 'nightMode', label: 'Ночной', gains: [-3, -2, 0, 2, 3, 3, 2, 0, -2, -4]),
];

/// Эквалайзер (легаси `EqualizerPanel` — содержимое Modal md). 10 вертикальных
/// band-слайдеров −12..+12 дБ (positive emerald, negative blue), power-toggle,
/// reset, пресеты. Презентационный: значения и события — через конструктор.
class EqualizerPanel extends StatelessWidget {
  static const double minGain = -12;
  static const double maxGain = 12;

  final String title;
  final List<EqualizerBand> bands;
  final List<EqualizerPreset> presets;
  final String? activePresetId;
  final bool enabled;

  final String presetLabel;

  /// (bandIndex, gain) — gain уже квантован шагом 0.5 и зажат в диапазон.
  final void Function(int index, double gain)? onBandChange;
  final void Function(String presetId)? onPreset;
  final VoidCallback? onToggleEnabled;
  final VoidCallback? onReset;
  final VoidCallback? onClose;

  const EqualizerPanel({
    super.key,
    required this.title,
    required this.bands,
    required this.presets,
    this.activePresetId,
    this.enabled = true,
    this.presetLabel = 'Preset',
    this.onBandChange,
    this.onPreset,
    this.onToggleEnabled,
    this.onReset,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      variant: GlassVariant.featured,
      radius: 24,
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: enabled ? 1 : 0.3,
            child: IgnorePointer(
              ignoring: !enabled,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [_sliders(), _presets()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: ScTokens.glassTintHover,
              borderRadius: BorderRadius.circular(ScTokens.rButton),
            ),
            alignment: Alignment.center,
            child: const Icon(LucideIcons.audioLines, size: 18, color: ScTokens.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xE6FFFFFF),
                letterSpacing: -0.3,
              ),
            ),
          ),
          _PowerButton(enabled: enabled, onTap: onToggleEnabled),
          const SizedBox(width: 8),
          _GhostIconButton(icon: Icons.rotate_left_rounded, onTap: onReset),
          const SizedBox(width: 8),
          _GhostIconButton(icon: LucideIcons.x, iconSize: 15, onTap: onClose),
        ],
      ),
    );
  }

  Widget _sliders() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Padding(
            padding: EdgeInsets.only(right: 8, bottom: 24),
            child: SizedBox(
              height: 140,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _DbTick('+12'),
                  _DbTick('0'),
                  _DbTick('-12'),
                ],
              ),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < bands.length; i++)
                  _BandSlider(
                    gain: bands[i].gain,
                    label: bands[i].label,
                    onChange: (g) => onBandChange?.call(i, g),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _presets() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              presetLabel,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: ScTokens.textTertiary,
              ),
            ),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final preset in presets)
                _PresetButton(
                  label: preset.label,
                  active: preset.id == activePresetId,
                  onTap: () => onPreset?.call(preset.id),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DbTick extends StatelessWidget {
  final String text;

  const _DbTick(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 9,
        color: Color(0x33FFFFFF),
        fontFeatures: [FontFeature.tabularFigures()],
      ),
    );
  }
}

/// Один band: значение сверху, drag-дорожка 28×140, лейбл частоты снизу.
class _BandSlider extends StatelessWidget {
  static const _positive = Color(0xFF34D399); // emerald-400
  static const _negative = Color(0xFF60A5FA); // blue-400
  static const _railH = 140.0;

  final double gain;
  final String label;
  final ValueChanged<double> onChange;

  const _BandSlider({required this.gain, required this.label, required this.onChange});

  double get _pct =>
      (gain - EqualizerPanel.minGain) / (EqualizerPanel.maxGain - EqualizerPanel.minGain);

  void _emit(double localY) {
    final ratio = 1 - (localY / _railH).clamp(0.0, 1.0);
    final raw = ratio * (EqualizerPanel.maxGain - EqualizerPanel.minGain) + EqualizerPanel.minGain;
    onChange((raw * 2).round() / 2);
  }

  @override
  Widget build(BuildContext context) {
    final positive = gain > 0;
    final negative = gain < 0;
    final valueColor = positive
        ? _positive
        : negative
            ? _negative
            : const Color(0x4DFFFFFF);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 16,
          child: Text(
            '${gain > 0 ? '+' : ''}${gain.toStringAsFixed(1)}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: valueColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (d) => _emit(d.localPosition.dy),
          onPanUpdate: (d) => _emit(d.localPosition.dy),
          child: SizedBox(
            width: 28,
            height: _railH,
            child: CustomPaint(
              painter: _BandPainter(
                pct: _pct,
                fillColor: positive ? _positive : (negative ? _negative : null),
                fillFromTop: positive,
                thumbColor: positive ? _positive : (negative ? _negative : const Color(0x80FFFFFF)),
                glow: gain != 0,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w500,
            color: Color(0x4DFFFFFF),
          ),
        ),
      ],
    );
  }
}

class _BandPainter extends CustomPainter {
  final double pct;
  final Color? fillColor;
  final bool fillFromTop;
  final Color thumbColor;
  final bool glow;

  _BandPainter({
    required this.pct,
    required this.fillColor,
    required this.fillFromTop,
    required this.thumbColor,
    required this.glow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final railRect = RRect.fromLTRBR(cx - 1.5, 0, cx + 1.5, size.height, const Radius.circular(2));
    canvas.drawRRect(railRect, Paint()..color = const Color(0x0FFFFFFF));

    // Центральная риска (0 дБ).
    canvas.drawRect(
      Rect.fromLTWH(cx - 4, size.height / 2 - 0.5, 8, 1),
      Paint()..color = const Color(0x1AFFFFFF),
    );

    final thumbY = size.height * (1 - pct);
    if (fillColor != null) {
      final mid = size.height / 2;
      final top = fillFromTop ? thumbY : mid;
      final bottom = fillFromTop ? mid : thumbY;
      final fill = RRect.fromLTRBR(cx - 1.5, top, cx + 1.5, bottom, const Radius.circular(2));
      canvas.drawRRect(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: fillFromTop ? Alignment.bottomCenter : Alignment.topCenter,
            end: fillFromTop ? Alignment.topCenter : Alignment.bottomCenter,
            colors: [fillColor!.withValues(alpha: 0.6), fillColor!.withValues(alpha: 0.2)],
          ).createShader(fill.outerRect),
      );
    }

    if (glow) {
      canvas.drawCircle(
        Offset(cx, thumbY),
        9,
        Paint()
          ..color = thumbColor.withValues(alpha: 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
    canvas.drawCircle(Offset(cx, thumbY), 8, Paint()..color = thumbColor);
  }

  @override
  bool shouldRepaint(_BandPainter old) =>
      old.pct != pct ||
      old.fillColor != fillColor ||
      old.fillFromTop != fillFromTop ||
      old.thumbColor != thumbColor ||
      old.glow != glow;
}

class _PresetButton extends StatefulWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _PresetButton({required this.label, required this.active, required this.onTap});

  @override
  State<_PresetButton> createState() => _PresetButtonState();
}

class _PresetButtonState extends State<_PresetButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    final bg = active
        ? const Color(0x1AFFFFFF)
        : (_hover ? const Color(0x0FFFFFFF) : const Color(0x05FFFFFF));
    final fg = active
        ? const Color(0xE6FFFFFF)
        : (_hover ? const Color(0x99FFFFFF) : const Color(0x59FFFFFF));
    final border = active ? const Color(0x1FFFFFFF) : const Color(0x0AFFFFFF);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: ScTokens.dFast,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border),
          ),
          child: Text(
            widget.label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
          ),
        ),
      ),
    );
  }
}

class _PowerButton extends StatelessWidget {
  static const _emerald = Color(0xFF34D399);

  final bool enabled;
  final VoidCallback? onTap;

  const _PowerButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: enabled ? _emerald.withValues(alpha: 0.15) : const Color(0x0AFFFFFF),
            borderRadius: BorderRadius.circular(ScTokens.rButton),
            border: Border.all(
              color: enabled ? _emerald.withValues(alpha: 0.2) : ScTokens.glassBorder,
            ),
            boxShadow: enabled
                ? [BoxShadow(color: _emerald.withValues(alpha: 0.15), blurRadius: 12)]
                : null,
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.power_settings_new_rounded,
            size: 15,
            color: enabled ? _emerald : const Color(0x40FFFFFF),
          ),
        ),
      ),
    );
  }
}

class _GhostIconButton extends StatefulWidget {
  final IconData icon;
  final double iconSize;
  final VoidCallback? onTap;

  const _GhostIconButton({required this.icon, this.iconSize = 14, this.onTap});

  @override
  State<_GhostIconButton> createState() => _GhostIconButtonState();
}

class _GhostIconButtonState extends State<_GhostIconButton> {
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
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0x0AFFFFFF),
            borderRadius: BorderRadius.circular(ScTokens.rButton),
            border: Border.all(color: ScTokens.glassBorder),
          ),
          alignment: Alignment.center,
          child: Icon(
            widget.icon,
            size: widget.iconSize,
            color: _hover ? const Color(0x80FFFFFF) : const Color(0x40FFFFFF),
          ),
        ),
      ),
    );
  }
}
