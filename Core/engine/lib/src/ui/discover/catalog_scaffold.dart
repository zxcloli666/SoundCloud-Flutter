import 'package:flutter/material.dart';
import 'package:sc_visual/sc_visual.dart';

/// Скелетон каталога (легаси `SkeletonGrid`): 10 плиток фиксированной высоты.
class CatalogSkeletonGrid extends StatelessWidget {
  final double itemHeight;

  const CatalogSkeletonGrid({super.key, required this.itemHeight});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final metrics = GridMetrics.resolve(
          width: c.maxWidth,
          minColumnWidth: 200,
          itemHeight: itemHeight,
          gap: 20,
        );
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: metrics.columns,
            mainAxisSpacing: 20,
            crossAxisSpacing: 20,
            mainAxisExtent: itemHeight,
          ),
          itemCount: 10,
          itemBuilder: (_, __) =>
              Skeleton(height: itemHeight, rounded: SkeletonRound.lg),
        );
      },
    );
  }
}

/// Пустое состояние каталога (легаси `EmptyArtists`/`EmptyAlbums`): иконка-плитка
/// 64×64 + одна строка.
class CatalogEmpty extends StatelessWidget {
  final IconData icon;
  final String message;

  const CatalogEmpty({super.key, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return EmptyState(icon: Icon(icon), title: message);
  }
}

/// Хвост каталога: чисто визуальный индикатор подгрузки + плашка достижения
/// кап-лимита (`RefineHint`). Сам триггер догрузки живёт на странице — по
/// близости скролла к низу (легаси `InfiniteSentinel` rootMargin 600px), а не
/// безусловно при каждом билде хвоста.
class CatalogTail extends StatelessWidget {
  final bool loadingMore;
  final bool capped;
  final String capMessage;

  const CatalogTail({
    super.key,
    required this.loadingMore,
    required this.capped,
    required this.capMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (capped) {
      return Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              capMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0x59FFFFFF),
                fontSize: 11,
                fontWeight: FontWeight.w500,
                height: 1.6,
              ),
            ),
          ),
        ),
      );
    }
    if (loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: Skeleton(width: 96, height: 12, rounded: SkeletonRound.full)),
      );
    }
    return const SizedBox(height: 8);
  }
}
