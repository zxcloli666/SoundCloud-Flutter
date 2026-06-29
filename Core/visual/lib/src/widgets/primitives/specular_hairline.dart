import 'package:flutter/widgets.dart';

/// Зеркальный волосок по верхней кромке стекла (легаси reusable specular hairline):
/// 1px `linear-gradient(90deg, transparent, rgba(255,255,255,α), transparent)`.
///
/// Появляется на GlassHeroPanel, Modal, ErrorScreen, Titlebar и прочих стеклянных
/// панелях (блюпринт §1.6/§4.3). Спек-альфа — 0.35 для геро/модалок (дефолт),
/// 0.30 для остальных карточек.
class SpecularHairline extends StatelessWidget {
  final double alpha;

  const SpecularHairline({super.key, this.alpha = 0.35});

  /// Тихий вариант для не-геро карточек (спек 0.30).
  const SpecularHairline.subtle({super.key}) : alpha = 0.30;

  @override
  Widget build(BuildContext context) {
    final tint = const Color(0xFFFFFFFF).withValues(alpha: alpha);
    return SizedBox(
      height: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0x00FFFFFF), tint, const Color(0x00FFFFFF)],
          ),
        ),
      ),
    );
  }
}
