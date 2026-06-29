import 'package:flutter/widgets.dart';

/// Метаданные качества/состояния трека (`_scd_meta` легаси), питающие бейдж.
/// Только поля, которые читает [TrackStatusBadge] (§5.4).
class TrackStatusMeta {
  final String? storageState; // ok | failed | missing | too_long | ...
  final String? storageQuality; // sq | hq | ...
  final String? indexState; // indexed | pending | too_long | failed | ...

  const TrackStatusMeta({this.storageState, this.storageQuality, this.indexState});
}

enum BadgeVariant { inline, overlay }

/// Одна решённая ступень бейджа: буква + цвета под вариант.
class _Tier {
  final String letter;
  final Color bg;
  final Color text;
  final Color ring;
  const _Tier(this.letter, this.bg, this.text, this.ring);
}

/// `tierOf(meta, showIndex)` — первое совпадение выигрывает (§5.4).
/// `null` ⇒ ничего не рисуем. `enrich_state` не участвует.
_Tier? _tierOf(TrackStatusMeta meta, bool showIndex, BadgeVariant v) {
  final s = meta.storageState;
  final i = meta.indexState;
  final overlay = v == BadgeVariant.overlay;

  if (s == 'too_long' || i == 'too_long') {
    return overlay
        ? const _Tier('F', Color(0xD9000000), Color(0xCCFFFFFF), Color(0x26FFFFFF))
        : const _Tier('F', Color(0x99000000), Color(0xB3FFFFFF), Color(0x26FFFFFF));
  }
  if (s == 'failed' || s == 'missing' || i == 'failed') {
    return overlay
        ? const _Tier('!', Color(0xE6FB7185), Color(0xFF000000), Color(0x0D000000))
        : const _Tier('!', Color(0x26F43F5E), Color(0xFFFDA4AF), Color(0x40FB7185));
  }
  if (s == 'ok' && showIndex && i == 'indexed') {
    return overlay
        ? const _Tier('A', Color(0xE634D399), Color(0xFF000000), Color(0x0D000000))
        : const _Tier('A', Color(0x2610B981), Color(0xFF6EE7B7), Color(0x4034D399));
  }
  if (s == 'ok') {
    return overlay
        ? const _Tier('C', Color(0xE6FBBF24), Color(0xFF000000), Color(0x0D000000))
        : const _Tier('C', Color(0x26F59E0B), Color(0xFFFCD34D), Color(0x40FBBF24));
  }
  if (showIndex) {
    return overlay
        ? const _Tier('·', Color(0xBFFFFFFF), Color(0x99000000), Color(0x0D000000))
        : const _Tier('·', Color(0x0FFFFFFF), Color(0x66FFFFFF), Color(0x1AFFFFFF));
  }
  return null;
}

bool _hqApplies(String letter) => letter == 'A' || letter == 'C';

/// Бейдж состояния трека из `_scd_meta`: квадрат 18×18, буква-тир, HQ-точка
/// 5×5 при `storage_quality==='hq'` (только для A/C). Ничего не рисует, если
/// тир не определён (§5.4).
class TrackStatusBadge extends StatelessWidget {
  final TrackStatusMeta meta;
  final BadgeVariant variant;
  final bool showIndex;

  const TrackStatusBadge({
    super.key,
    required this.meta,
    this.variant = BadgeVariant.inline,
    this.showIndex = true,
  });

  @override
  Widget build(BuildContext context) {
    final tier = _tierOf(meta, showIndex, variant);
    if (tier == null) return const SizedBox.shrink();

    final hq = meta.storageQuality == 'hq' && _hqApplies(tier.letter);

    final box = Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tier.bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: tier.ring),
      ),
      child: Text(
        tier.letter,
        style: TextStyle(
          color: tier.text,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );

    if (!hq) return box;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        box,
        Positioned(
          top: -1,
          right: -1,
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: tier.text, shape: BoxShape.circle),
          ),
        ),
      ],
    );
  }
}
