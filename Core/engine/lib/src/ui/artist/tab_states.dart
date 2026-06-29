import 'package:flutter/material.dart';

/// Спиннер загрузки вкладки (легаси Loader2 28 в центре, py-24).
class TabLoader extends StatelessWidget {
  const TabLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 96),
      child: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.4, color: Color(0x33FFFFFF)),
        ),
      ),
    );
  }
}

/// Пустое состояние вкладки (легаси: стеклянная плитка 64×64 + иконка + строка).
class TabEmpty extends StatelessWidget {
  final IconData icon;
  final String label;

  const TabEmpty({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 96),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0x08FFFFFF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x0FFFFFFF), width: 0.5),
            ),
            child: Icon(icon, size: 24, color: const Color(0x26FFFFFF)),
          ),
          const SizedBox(height: 16),
          Text(label, style: const TextStyle(color: Color(0x4DFFFFFF), fontSize: 14)),
        ],
      ),
    );
  }
}
