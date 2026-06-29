import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:sc_visual/sc_visual.dart';

/// Вторичный вход (легаси `OfflineEntryCard`): градиент-бордер-стекло с Globe +
/// изумрудным Download-бейджем → офлайн-библиотека без входа. Hover поднимает
/// яркость рамки и сдвигает шеврон.
class OfflineEntryCard extends StatefulWidget {
  final VoidCallback onTap;

  const OfflineEntryCard({super.key, required this.onTap});

  @override
  State<OfflineEntryCard> createState() => _OfflineEntryCardState();
}

class _OfflineEntryCardState extends State<OfflineEntryCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final blur = PerfProfile.of(context).blur(40);
    final radius = BorderRadius.circular(22);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: ScTokens.dSidebar,
          curve: ScTokens.easeApple,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: _hover ? const Color(0x2EFFFFFF) : const Color(0x1AFFFFFF)),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0x1AFFFFFF), Color(0x05FFFFFF), Color(0x0FFFFFFF)],
              stops: [0.0, 0.55, 1.0],
            ),
            boxShadow: [
              const BoxShadow(color: Color(0x59000000), blurRadius: 50, offset: Offset(0, 18)),
              if (_hover) const BoxShadow(color: Color(0x1A38BDF8), blurRadius: 60),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: _frosted(blur),
          ),
        ),
      ),
    );
  }

  Widget _frosted(double blur) {
    final inner = Container(
      decoration: const BoxDecoration(color: Color(0x59000000)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          _iconBadge(),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Продолжить офлайн',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: Color(0xEBFFFFFF),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Слушай скачанную библиотеку без входа',
                  style: TextStyle(fontSize: 11.5, height: 1.3, color: Color(0x73FFFFFF)),
                ),
              ],
            ),
          ),
          AnimatedSlide(
            duration: ScTokens.dSidebar,
            offset: Offset(_hover ? 0.12 : 0, 0),
            child: Icon(
              LucideIcons.chevronRight,
              size: 18,
              color: _hover ? const Color(0xB3FFFFFF) : const Color(0x4DFFFFFF),
            ),
          ),
        ],
      ),
    );
    if (blur <= 0) return inner;
    return BackdropFilter(filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur), child: inner);
  }

  Widget _iconBadge() {
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x29FFFFFF)),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x29FFFFFF), Color(0x0AFFFFFF)],
              ),
            ),
            child: const Icon(LucideIcons.globe, size: 18, color: Color(0xF2E0F2FE)),
          ),
          Positioned(
            right: -4,
            bottom: -4,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xE634D399),
                border: Border.all(color: const Color(0x2EFFFFFF)),
              ),
              child: const Icon(LucideIcons.download, size: 11, color: Color(0xFF064E3B)),
            ),
          ),
        ],
      ),
    );
  }
}
