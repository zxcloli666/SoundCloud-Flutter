import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:sc_visual/sc_visual.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../rust/api.dart';
export '../track_meta.dart' show trackScdMeta;

/// Запустить трек, показав ошибку как snackbar (общий обработчик для всех полок
/// реки). [queue] задан (лайки/список) — играем как очередь: список доигрывается,
/// потом волна продолжает; null — одиночный старт (сразу волна).
Future<void> playHomeTrack(
  WidgetRef ref,
  BuildContext context,
  TrackDto track, {
  List<TrackDto>? queue,
}) async {
  final messenger = ToastScope.of(context);
  try {
    await ref.read(playerProvider.notifier).play(track, queue: queue);
  } catch (error) {
    messenger.show('Не удалось воспроизвести: $error', kind: ToastKind.error);
  }
}

/// Жанр → цвет (легаси `genreColor`, 12 кураторских оттенков). Неизвестный жанр
/// и null → нейтральный белый. Используется тонировкой VibeShelf.
Color genreColor(String? genre) {
  if (genre == null || genre.isEmpty) return const Color(0x40FFFFFF);
  final key = genre.toLowerCase();
  for (final entry in _genrePalette.entries) {
    if (key.contains(entry.key)) return entry.value;
  }
  return const Color(0x59FFFFFF);
}

const _genrePalette = <String, Color>{
  'house': Color(0xFFf472b6),
  'techno': Color(0xFF22d3ee),
  'trap': Color(0xFFa78bfa),
  'hip': Color(0xFFfbbf24),
  'rap': Color(0xFFfbbf24),
  'lo-fi': Color(0xFF34d399),
  'lofi': Color(0xFF34d399),
  'ambient': Color(0xFF60a5fa),
  'dnb': Color(0xFFf87171),
  'drum': Color(0xFFf87171),
  'pop': Color(0xFFfb7185),
  'rock': Color(0xFFf97316),
  'electronic': Color(0xFF818cf8),
  'jazz': Color(0xFFc084fc),
};

/// Горизонтальная лента с drag-to-scroll (легаси `HorizontalScroll`): мышь тянет
/// контент, тап по карточке подавляется только после порога перетаскивания.
/// Виртуализирует через `ListView.builder` — рендерит лишь видимое.
class HomeHScroll extends StatefulWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double gap;
  final double height;

  const HomeHScroll({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.gap = 16,
    this.height = 252,
  });

  @override
  State<HomeHScroll> createState() => _HomeHScrollState();
}

class _HomeHScrollState extends State<HomeHScroll> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: ScrollConfiguration(
        behavior: const _DragScrollBehavior(),
        child: ListView.separated(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          itemCount: widget.itemCount,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          separatorBuilder: (_, __) => SizedBox(width: widget.gap),
          itemBuilder: widget.itemBuilder,
        ),
      ),
    );
  }
}

/// Разрешает перетаскивание мышью (на десктопе по умолчанию выключено).
class _DragScrollBehavior extends MaterialScrollBehavior {
  const _DragScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

/// Пунктирная рамка-плашка (дельта реки): dashed border white/0.1.
class DottedRiverBox extends StatelessWidget {
  final Widget child;

  const DottedRiverBox({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Center(child: child),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x1AFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(16),
    );
    final path = Path()..addRRect(rrect);
    const dash = 6.0;
    const gap = 5.0;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(
          metric.extractPath(d, (d + dash).clamp(0, metric.length)),
          paint,
        );
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => false;
}
