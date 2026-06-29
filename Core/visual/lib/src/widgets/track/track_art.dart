import 'package:flutter/widgets.dart';

import '../../image_proxy.dart';
import '../../theme.dart';

/// Контекст обложки → размер SC-варианта (§5.2 legacy).
enum ArtSize {
  hero('t500x500'),
  card('t300x300'),
  row('t200x200'),
  avatar('t120x120');

  final String token;
  const ArtSize(this.token);
}

/// Апскейл обложки по правилу легаси: заменить ПЕРВОЕ вхождение литерала
/// `-large` на `-{size}`. SC отдаёт `...-large.jpg`; для hi-res тайлов нужен
/// квадрат. Не трогаем уже-нормализованные/нестандартные url.
String artUrl(String? url, ArtSize size) {
  if (url == null || url.isEmpty) return '';
  final i = url.indexOf('-large');
  if (i < 0) return url;
  return url.replaceFirst('-large', '-${size.token}');
}

/// Обложка с фолбэком на акцентный градиент (легаси `linear-gradient(140deg,
/// accent, #3a2bd0)`). Размер/zoom задаёт вызывающий через [BoxFit].
class TrackArtwork extends StatelessWidget {
  final String? url;
  final ArtSize size;
  final BoxFit fit;

  const TrackArtwork({
    super.key,
    required this.url,
    this.size = ArtSize.card,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final resolved = artUrl(url, size);
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: const Alignment(-0.7, -1),
          end: const Alignment(0.7, 1),
          colors: [ScTheme.paletteOf(context).accent, const Color(0xFF3A2BD0)],
        ),
      ),
    );
    if (resolved.isEmpty) return fallback;

    // PERF: декодируем в логический размер бокса×DPR, а не в полный ARGB
    // оригинала. SC отдаёт квадраты до 500px (~1MB ARGB); на стене поиска и в
    // виртуальных списках/гридах это доминанта памяти/декода. Визуал идентичен.
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final cacheW = _cacheWidth(constraints.maxWidth, dpr);
        return Image(
          image: cacheW == null
              ? ScImageProxy.provider(resolved)
              : ResizeImage(ScImageProxy.provider(resolved), width: cacheW),
          fit: fit,
          errorBuilder: (_, __, ___) => fallback,
        );
      },
    );
  }

  /// Целевая ширина декода в пикселях устройства. `null` (без даунскейла), если
  /// бокс безразмерный — тогда decode идёт в натуральный размер, как раньше.
  static int? _cacheWidth(double boxWidth, double dpr) {
    if (!boxWidth.isFinite || boxWidth <= 0) return null;
    return (boxWidth * dpr).round();
  }
}
