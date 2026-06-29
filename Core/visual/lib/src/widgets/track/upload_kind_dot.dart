import 'package:flutter/widgets.dart';

/// Тип загрузки (legacy `enrichment.upload_kind`). `unknown`/null → бейджа нет.
enum UploadKind {
  original(Color(0xFF34D399)),
  demo(Color(0xFF38BDF8)),
  reupload(Color(0xFFFBBF24)),
  cover(Color(0xFFE879F9));

  final Color color;
  const UploadKind(this.color);

  static UploadKind? parse(String? raw) => switch (raw) {
        'original' => original,
        'demo' => demo,
        'reupload' => reupload,
        'cover' => cover,
        _ => null,
      };
}

/// Цветная точка-индикатор типа загрузки 6×6 (§4.2). `other`/null → SizedBox.
class UploadKindDot extends StatelessWidget {
  final UploadKind? kind;

  const UploadKindDot({super.key, required this.kind});

  @override
  Widget build(BuildContext context) {
    final k = kind;
    if (k == null) return const SizedBox.shrink();
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: k.color, shape: BoxShape.circle),
    );
  }
}
