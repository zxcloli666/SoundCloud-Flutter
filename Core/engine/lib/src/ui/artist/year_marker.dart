import 'package:flutter/material.dart';

import 'artist_aura.dart';

/// Год-маркер + контент (легаси `YearBlock`/`YearGroup`): на широких — крупная
/// gradient-clip цифра года в липкой колонке слева (200px), контент справа; на
/// узких — год сверху строкой. Цифра тинтуется аурой.
class YearMarkerRow extends StatelessWidget {
  final int? year;
  final String sublabel;
  final ArtistAura aura;
  final List<Widget> children;

  const YearMarkerRow({
    super.key,
    required this.year,
    required this.sublabel,
    required this.aura,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 768;
    final marker = _marker(context, alignEnd: wide);
    final content = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);

    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [marker, const SizedBox(height: 12), content],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 200, child: marker),
        const SizedBox(width: 32),
        Expanded(child: content),
      ],
    );
  }

  Widget _marker(BuildContext context, {required bool alignEnd}) {
    final width = MediaQuery.sizeOf(context).width;
    final fontSize = (width * 0.07).clamp(48.0, 80.0);
    final number = Text(
      year != null ? '$year' : '∞',
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        height: 1,
        letterSpacing: -1,
        color: Colors.white,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    final clipped = ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [aura.rgba(0.95), aura.rgba(0.4)],
      ).createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: number,
    );
    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        clipped,
        const SizedBox(height: 4),
        Text(
          sublabel.toUpperCase(),
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          style: const TextStyle(
            color: Color(0x4DFFFFFF),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.2,
          ),
        ),
      ],
    );
  }
}
