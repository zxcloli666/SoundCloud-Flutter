import 'package:flutter/material.dart';

import '../../image_proxy.dart';
import '../../tokens.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Круглый аватар (легаси `Avatar`). Источник апскейлится до `t200x200`;
/// при отсутствии src (или `default_avatar`) — стеклянный круг с силуэтом.
class Avatar extends StatelessWidget {
  final String? src;
  final String alt;
  final double size;

  const Avatar({super.key, this.src, this.alt = '', this.size = 32});

  @override
  Widget build(BuildContext context) {
    final url = _resolved(src);
    if (url == null) return _fallback();
    // PERF: src апскейлится до t200x200, но рендерится 28-80px — декодируем в
    // размер виджета×DPR, а не полный ~160KB ARGB (см. TrackArtwork).
    final cacheW = (size * MediaQuery.devicePixelRatioOf(context)).round();
    return ClipOval(
      child: Image(
        image: ResizeImage(ScImageProxy.provider(url), width: cacheW),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: ScTokens.glassTintActive,
        shape: BoxShape.circle,
      ),
      child: Icon(LucideIcons.user, size: size * 0.6, color: ScTokens.textTertiary),
    );
  }
}

/// Легаси-правило апскейла: заменить первое вхождение `-large` на `-{size}`.
String? _resolved(String? src) {
  if (src == null || src.isEmpty || src.contains('default_avatar')) return null;
  return src.replaceFirst('-large', '-t200x200');
}
