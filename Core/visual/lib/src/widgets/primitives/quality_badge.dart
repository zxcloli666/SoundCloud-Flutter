import 'package:flutter/widgets.dart';

import 'sc_tooltip.dart';

/// Бейдж качества/состояния трека из `_scd_meta` (легаси `TrackStatusBadges`).
/// Чистая презентация: вердикт-tier считается по `storage_state`/`index_state`
/// (см. [ScdTier.of]), цвет — по [ScdBadgeVariant].

/// Поля `_scd_meta`, влияющие на бейдж (остальные не консьюмятся).
class ScdMeta {
  final String? storageState; // ok | failed | missing | too_long | ...
  final String? storageQuality; // sq | hq | ...
  final String? indexState; // indexed | pending | too_long | failed | ...

  const ScdMeta({this.storageState, this.storageQuality, this.indexState});
}

enum ScdBadgeVariant { inline, overlay }

/// Tier бейджа. Порядок проверок — first-match-wins (как `tierOf` в легаси).
enum ScdTier {
  tooLong,
  failed,
  analyzed,
  cached,
  pending;

  /// Вердикт по мете. `null` ⇒ бейдж не рисуется.
  /// [showIndex] = учитывать индекс (различает analyzed/cached и включает pending).
  static ScdTier? of(ScdMeta meta, {bool showIndex = true}) {
    final s = meta.storageState;
    final i = meta.indexState;
    if (s == 'too_long' || i == 'too_long') return ScdTier.tooLong;
    if (s == 'failed' || s == 'missing' || i == 'failed') return ScdTier.failed;
    if (s == 'ok') return (showIndex && i == 'indexed') ? ScdTier.analyzed : ScdTier.cached;
    return showIndex ? ScdTier.pending : null;
  }
}

/// 18×18 бейдж: буква tier + (для analyzed/cached) точка HQ при `storage_quality=='hq'`.
class QualityBadge extends StatelessWidget {
  final ScdMeta meta;
  final ScdBadgeVariant variant;
  final bool showIndex;

  /// Подпись (i18n) под tier+Hq — резолвит потребитель; null ⇒ без тултипа.
  final String? Function(ScdTier tier, bool hq)? titleFor;

  const QualityBadge({
    super.key,
    required this.meta,
    this.variant = ScdBadgeVariant.inline,
    this.showIndex = true,
    this.titleFor,
  });

  @override
  Widget build(BuildContext context) {
    final tier = ScdTier.of(meta, showIndex: showIndex);
    if (tier == null) return const SizedBox.shrink();

    final tone = _ToneTable.of(tier, variant);
    final hq = (tier == ScdTier.analyzed || tier == ScdTier.cached) &&
        meta.storageQuality == 'hq';

    Widget box = SizedBox(
      width: 18,
      height: 18,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: tone.bg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: tone.ring), // ring-1 ring-inset
            ),
            child: Center(
              child: Text(
                _letter(tier),
                style: TextStyle(
                  color: tone.text,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ),
          ),
          if (hq)
            Positioned(
              top: -1,
              right: -1,
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: tone.text, // bg-current
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0x33000000), width: 0.5),
                ),
              ),
            ),
        ],
      ),
    );

    final title = titleFor?.call(tier, hq);
    return title == null ? box : ScTooltip(message: title, child: box);
  }
}

String _letter(ScdTier tier) => switch (tier) {
      ScdTier.tooLong => 'F',
      ScdTier.failed => '!',
      ScdTier.analyzed => 'A',
      ScdTier.cached => 'C',
      ScdTier.pending => '·',
    };

class _Tone {
  final Color bg;
  final Color text;
  final Color ring;
  const _Tone(this.bg, this.text, this.ring);
}

/// Таблица цветов tier × variant — 1:1 из §5.4.
abstract final class _ToneTable {
  static _Tone of(ScdTier tier, ScdBadgeVariant v) {
    final overlay = v == ScdBadgeVariant.overlay;
    return switch (tier) {
      ScdTier.tooLong => overlay
          ? const _Tone(Color(0xD9000000), Color(0xCCFFFFFF), Color(0x26FFFFFF))
          : const _Tone(Color(0x99000000), Color(0xB3FFFFFF), Color(0x26FFFFFF)),
      ScdTier.failed => overlay
          ? const _Tone(Color(0xE6FB7185), Color(0xFF000000), Color(0x0D000000))
          : const _Tone(Color(0x26F43F5E), Color(0xFFFDA4AF), Color(0x40FB7185)),
      ScdTier.analyzed => overlay
          ? const _Tone(Color(0xE634D399), Color(0xFF000000), Color(0x0D000000))
          : const _Tone(Color(0x2610B981), Color(0xFF6EE7B7), Color(0x4034D399)),
      ScdTier.cached => overlay
          ? const _Tone(Color(0xE6FBBF24), Color(0xFF000000), Color(0x0D000000))
          : const _Tone(Color(0x26F59E0B), Color(0xFFFCD34D), Color(0x40FBBF24)),
      ScdTier.pending => overlay
          ? const _Tone(Color(0xBFFFFFFF), Color(0x99000000), Color(0x0D000000))
          : const _Tone(Color(0x0FFFFFFF), Color(0x66FFFFFF), Color(0x1AFFFFFF)),
    };
  }
}
