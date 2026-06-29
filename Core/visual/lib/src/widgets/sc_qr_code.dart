import 'package:flutter/widgets.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../perf.dart';
import '../theme.dart';

/// Стеклянный QR-артефакт логина (легаси `QrCode`): акцентная аура-обводка
/// вокруг светлой скруглённой карточки с тёмными модулями. Чисто презентация —
/// данные приходят строкой [data] (например `scd://link?...`).
///
/// Модули/глаза скруглены, error-correction H — под центральный лого-вырез и
/// читаемость на телефоне. Аура и glow гаснут в [PerfMode.light].
class ScQrCode extends StatelessWidget {
  final String data;
  final double size;

  const ScQrCode({super.key, required this.data, this.size = 220});

  static const _plateRadius = 24.0;
  static const _platePadding = 18.0;
  static const _moduleColor = Color(0xFF0B0B12);

  @override
  Widget build(BuildContext context) {
    final accent = ScTheme.paletteOf(context).accent;
    final perf = ScPerf.of(context);
    final glow = perf != PerfMode.light;

    final plate = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_plateRadius),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFBFBFE), Color(0xFFEDEDF4)],
        ),
        border: Border.all(color: const Color(0x33FFFFFF)),
        boxShadow: [
          const BoxShadow(
            color: Color(0x80000000),
            blurRadius: 40,
            offset: Offset(0, 18),
          ),
          if (glow)
            BoxShadow(
              color: accent.withValues(alpha: 0.30),
              blurRadius: 48,
              spreadRadius: -8,
            ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(_platePadding),
        child: QrImageView(
          data: data,
          size: size,
          gapless: false,
          backgroundColor: const Color(0x00000000),
          errorCorrectionLevel: QrErrorCorrectLevel.H,
          eyeStyle: const QrEyeStyle(
            eyeShape: QrEyeShape.circle,
            color: _moduleColor,
          ),
          dataModuleStyle: const QrDataModuleStyle(
            dataModuleShape: QrDataModuleShape.circle,
            color: _moduleColor,
          ),
        ),
      ),
    );

    final outer = size + _platePadding * 2;
    return SizedBox.square(
      dimension: outer,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (glow) _aurora(accent, outer),
          plate,
        ],
      ),
    );
  }

  /// Мягкая акцентная аура за карточкой (легаси `.qr-aurora`).
  Widget _aurora(Color accent, double outer) {
    return Positioned(
      left: -outer * 0.12,
      top: -outer * 0.12,
      right: -outer * 0.12,
      bottom: -outer * 0.12,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(outer),
            boxShadow: [
              BoxShadow(color: accent.withValues(alpha: 0.22), blurRadius: 60),
            ],
            gradient: RadialGradient(
              colors: [accent.withValues(alpha: 0.18), const Color(0x00000000)],
            ),
          ),
        ),
      ),
    );
  }
}
