import 'package:flutter/widgets.dart';

import '../../perf.dart';
import '../../theme.dart';

/// Заголовок кластера рекомендаций (легаси `cluster/ClusterHeader`): акцентный
/// бейдж-иконка 36×36 + чип-индекс 16×16 + заголовок 16px/900 + описание.
/// Используется над горизонтальной полкой треков (`ClusterRow`).
class ClusterHeader extends StatelessWidget {
  final Widget icon;
  final String title;
  final String? description;

  /// 1-based номер кластера в ленте; null → чип не рисуется.
  final int? index;

  const ClusterHeader({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.index,
  });

  @override
  Widget build(BuildContext context) {
    final accent = ScTheme.paletteOf(context).accent;
    final glow = ScPerf.profileOf(context).glow;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _iconBadge(accent, glow),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (index != null) ...[
                    _indexChip(accent),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xEBFFFFFF),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ],
              ),
              if (description != null && description!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  description!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0x8CFFFFFF), fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _iconBadge(Color accent, bool glow) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.55),
            accent.withValues(alpha: 0.12),
          ],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.40), width: 0.5),
        boxShadow: glow
            ? [BoxShadow(color: accent.withValues(alpha: 0.20), blurRadius: 22)]
            : const [],
      ),
      child: IconTheme(
        data: const IconThemeData(size: 18, color: Color(0xFFFFFFFF)),
        child: icon,
      ),
    );
  }

  Widget _indexChip(Color accent) {
    return Container(
      width: 16,
      height: 16,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        '$index',
        style: TextStyle(
          color: accent,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}
