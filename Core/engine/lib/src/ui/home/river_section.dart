import 'package:flutter/material.dart';

/// Тон рамки участка реки (легаси `RiverSection.tone`): open — без рамки,
/// panel — лёгкая стеклянная, deep — притоплённая тёмная.
enum RiverSectionTone { open, panel, deep }

/// Рамка участка реки: заголовок + «почему это здесь». Узлы и нити рисует
/// RiverBraid по якорю-обёртке — здесь только заголовок и контент.
class RiverSection extends StatelessWidget {
  final String title;
  final String why;
  final RiverSectionTone tone;
  final Widget child;

  const RiverSection({
    super.key,
    required this.title,
    required this.why,
    this.tone = RiverSectionTone.open,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final head = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xEBFFFFFF),
            fontSize: 21,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          why,
          style: const TextStyle(color: Color(0x80FFFFFF), fontSize: 13, height: 1.3),
        ),
      ],
    );

    final content = tone == RiverSectionTone.open
        ? child
        : Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: tone == RiverSectionTone.deep
                  ? const Color(0x8C05050A)
                  : const Color(0x06FFFFFF),
              border: Border.all(
                color: tone == RiverSectionTone.deep
                    ? const Color(0x0DFFFFFF)
                    : const Color(0x12FFFFFF),
              ),
            ),
            child: child,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        head,
        const SizedBox(height: 16),
        content,
      ],
    );
  }
}
