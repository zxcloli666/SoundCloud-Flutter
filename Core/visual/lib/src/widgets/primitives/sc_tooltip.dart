import 'package:flutter/material.dart';

import '../../tokens.dart';

/// Стеклянный тултип (легаси нативный `title=""`). Тонкая обёртка над Flutter
/// [Tooltip] в тон дизайн-системы: тёмная морозная плашка, текст white/85 13px.
class ScTooltip extends StatelessWidget {
  final String message;
  final Widget child;
  final Duration waitDuration;

  const ScTooltip({
    super.key,
    required this.message,
    required this.child,
    this.waitDuration = const Duration(milliseconds: 400),
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: message,
      waitDuration: waitDuration,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xE61E1E22), // rgba(30,30,34,0.9)
        borderRadius: BorderRadius.circular(ScTokens.rButton),
        border: Border.all(color: const Color(0x14FFFFFF)), // white/8
        boxShadow: const [
          BoxShadow(color: Color(0x66000000), blurRadius: 24, offset: Offset(0, 8)),
        ],
      ),
      textStyle: const TextStyle(
        color: Color(0xD9FFFFFF), // white/85
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      child: child,
    );
  }
}
