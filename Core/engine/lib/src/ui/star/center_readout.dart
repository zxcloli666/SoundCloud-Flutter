import 'package:flutter/material.dart';
import 'package:sc_visual/sc_visual.dart';

import 'console.dart' show starDisplay, starMono;
import 'star_data.dart';

/// Контент внутри тёмного «колодца» живого ядра (легаси `CenterReadout`). Одна
/// анатомия на каждое состояние: accent-Eyebrow → большой Hero → muted Caption.
class CenterReadout extends StatelessWidget {
  final StarStep step;
  final PayPhase phase;
  final String handle;
  final StarPlan? plan;
  final int endsAt;
  final String serialSeed;

  const CenterReadout({
    super.key,
    required this.step,
    required this.phase,
    required this.handle,
    required this.plan,
    required this.endsAt,
    required this.serialSeed,
  });

  // Слоистая тень: тугое тёмное гало держит глифы поверх блума ядра.
  static const List<Shadow> _shadow = [
    Shadow(color: Color(0xF2000000), blurRadius: 1),
    Shadow(color: Color(0xEB000000), blurRadius: 3, offset: Offset(0, 1)),
    Shadow(color: Color(0xCC000000), blurRadius: 26, offset: Offset(0, 3)),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = ScTheme.paletteOf(context);
    final accent = palette.accent;

    final children = <Widget>[];
    switch (step) {
      case StarStep.success:
      case StarStep.manage:
        children.addAll([
          _eyebrow(accent),
          _hero(handle, size: 30),
          const SizedBox(height: 6),
          Text(
            passSerial(serialSeed),
            style: TextStyle(
              fontFamily: starDisplay,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: 14 * 0.08,
              color: accent,
              shadows: _shadow,
            ),
          ),
          _caption(
            context,
            spans: [
              TextSpan(text: 'до ${passDate(endsAt)} · '),
              TextSpan(
                text: daysLeftLabel(daysUntil(endsAt)),
                style: TextStyle(color: accent, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ]);
      case StarStep.pay:
        children.addAll([
          _eyebrow(accent),
          _hero('${plan?.priceRub ?? ''}', size: 48, unit: '₽'),
          _caption(context, child: _payStatus(context, accent)),
        ]);
      case StarStep.redeem:
        children.addAll([
          _eyebrow(accent),
          _caption(context, spans: const [TextSpan(text: 'Введи код активации')]),
        ]);
      case StarStep.overview:
      case StarStep.method:
        final p = plan;
        children.addAll([
          _eyebrow(accent),
          _hero(p != null ? '${p.priceRub}' : '—', size: 60, unit: '₽'),
          _caption(
            context,
            spans: p == null
                ? const [TextSpan(text: 'Загрузка тарифов…')]
                : [
                    TextSpan(text: '${p.termLabel} · ${p.perMonthRub} ₽/мес'),
                    if (p.savingsPct > 0)
                      TextSpan(
                        text: ' · −${p.savingsPct}%',
                        style: TextStyle(color: accent, fontWeight: FontWeight.w600),
                      ),
                  ],
          ),
        ]);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  Widget _eyebrow(Color accent) => Text(
        '✦',
        style: TextStyle(fontSize: 17, height: 1, color: accent, shadows: _shadow),
      );

  Widget _hero(String value, {required double size, String? unit}) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: starDisplay,
                fontSize: size,
                fontWeight: FontWeight.w700,
                height: 0.95,
                letterSpacing: size * -0.03,
                color: Colors.white,
                shadows: _shadow,
              ),
            ),
          ),
          if (unit != null) ...[
            const SizedBox(width: 8),
            Text(
              unit,
              style: TextStyle(
                fontFamily: starMono,
                fontSize: (size * 0.4).roundToDouble(),
                color: const Color(0x80FFFFFF),
                shadows: _shadow,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _caption(BuildContext context,
      {List<InlineSpan>? spans, Widget? child}) {
    const base = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      letterSpacing: 13 * 0.01,
      color: Color(0xBFFFFFFF), // white/75
      shadows: _shadow,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: child ??
          Text.rich(
            TextSpan(style: base, children: spans),
            textAlign: TextAlign.center,
          ),
    );
  }

  Widget _payStatus(BuildContext context, Color accent) {
    final palette = ScTheme.paletteOf(context);
    if (phase == PayPhase.granted) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            child: Icon(LucideIcons.check, size: 11, color: palette.accentContrast),
          ),
          const SizedBox(width: 8),
          const Text('Оплачено',
              style: TextStyle(fontSize: 13, color: Color(0xBFFFFFFF), shadows: _shadow)),
        ],
      );
    }
    if (phase == PayPhase.failed) {
      return const Text('Платёж не прошёл',
          style: TextStyle(fontSize: 13, color: Color(0xE6FCA5A5), shadows: _shadow));
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 15,
          height: 15,
          child: CircularProgressIndicator(strokeWidth: 2, color: accent),
        ),
        const SizedBox(width: 8),
        const Text('Ожидаем оплату',
            style: TextStyle(fontSize: 13, color: Color(0xBFFFFFFF), shadows: _shadow)),
      ],
    );
  }
}
