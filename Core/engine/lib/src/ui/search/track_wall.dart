import 'package:flutter/material.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../rust/api.dart';
import 'wall_layout.dart';
import 'wall_tile.dart';

/// Один элемент стены: уже резолвнутый трек (поисковый результат) или сырой urn
/// (лента/река — резолвится лениво на каждую видимую плитку). `hero` фиксирован
/// заранее (по urn для woven-результатов, по позиции для append-only ленты), так
/// что плитка не перескакивает 1×1↔2×2 при дозагрузке.
class WallItem {
  final String urn;
  final TrackDto? track;
  final bool hero;
  final CoverTileVariant variant;
  final String? lyricLine;

  WallItem.resolved(
    TrackDto this.track, {
    required this.hero,
    this.variant = CoverTileVariant.normal,
    this.lyricLine,
  }) : urn = track.urn;

  const WallItem.lazy(this.urn, {required this.hero})
      : track = null,
        variant = CoverTileVariant.normal,
        lyricLine = null;
}

/// «Стена» — детерминированная плотная мозаика квадратных плиток. Колонки и
/// размер ячейки берутся из [WallMetrics] по ширине; геро-плитки занимают 2×2,
/// поток `dense` ([WallSliverGridDelegate]) втискивает мелкие тайлы в ритм.
/// Лежит в [SliverGrid] поверх [CustomScrollView]: строятся только тайлы в
/// viewport — скролл сотен элементов не инстанцирует невидимые [CoverTile].
///
/// [TrackWall.embedded] — та же мозаика, но без своего скролла: shrink-wrap
/// для конечной капнутой стены внутри чужого [CustomScrollView] (призма §3.3).
class TrackWall extends StatelessWidget {
  final List<WallItem> items;
  final bool loading;
  final bool hasMore;
  final bool loadingMore;
  final VoidCallback? onLoadMore;
  final void Function(TrackDto)? onDive;

  /// Воспроизвести тапнутый трек в очереди стены ([queue] — все резолвнутые
  /// треки стены в порядке мозаики). Ленивые плитки (urn) в очередь не попадают.
  final void Function(TrackDto track, List<TrackDto> queue) onPlay;

  /// Без своего скролла (shrink-wrap): стена встраивается в чужой скролл-вью.
  /// Конечная (без догрузки) — `controller`/сентинел не нужны.
  final bool embedded;
  final ScrollController? controller;

  const TrackWall({
    super.key,
    required this.items,
    required this.loading,
    required this.onPlay,
    required ScrollController this.controller,
    this.hasMore = false,
    this.loadingMore = false,
    this.onLoadMore,
    this.onDive,
  }) : embedded = false;

  const TrackWall.embedded({
    super.key,
    required this.items,
    required this.loading,
    required this.onPlay,
    this.onDive,
  })  : embedded = true,
        controller = null,
        hasMore = false,
        loadingMore = false,
        onLoadMore = null;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth - 32; // px-4 (16+16)
        final metrics = WallMetrics.resolve(width <= 0 ? 1 : width);
        if (loading && items.isEmpty) {
          return _skeleton(metrics);
        }
        if (embedded) return _embedded(metrics);
        return _grid(metrics);
      },
    );
  }

  /// Shrink-wrap-сетка той же [WallSliverGridDelegate]: один проход, без своего
  /// скролла и сентинела (стена конечная и капнутая).
  Widget _embedded(WallMetrics m) {
    final hero = [for (final it in items) it.hero];
    final queue = [for (final it in items) if (it.track != null) it.track!];
    // Явная высота: shrink-wrap кастомного dense-делегата не меряется внутри
    // чужого сливера (схлопывается в 0) — считаем высоту раскладки сами.
    final height = WallSliverGridDelegate.heightFor(
      columns: m.columns,
      cellPx: m.cellPx,
      gap: WallMetrics.gap,
      hero: hero,
    );
    return SizedBox(
      height: height,
      child: GridView.custom(
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: WallSliverGridDelegate(
          columns: m.columns,
          cellPx: m.cellPx,
          gap: WallMetrics.gap,
          hero: hero,
        ),
        childrenDelegate: SliverChildBuilderDelegate(
          (context, i) => WallTile(
            item: items[i],
            onPlay: (track) => onPlay(track, queue),
            onDive: onDive,
          ),
          childCount: items.length,
        ),
      ),
    );
  }

  Widget _grid(WallMetrics m) {
    final hero = [for (final it in items) it.hero];
    final queue = [for (final it in items) if (it.track != null) it.track!];
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (hasMore &&
            !loadingMore &&
            onLoadMore != null &&
            n.metrics.pixels >= n.metrics.maxScrollExtent - 600) {
          onLoadMore!();
        }
        return false;
      },
      child: CustomScrollView(
        controller: controller,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            sliver: SliverGrid(
              gridDelegate: WallSliverGridDelegate(
                columns: m.columns,
                cellPx: m.cellPx,
                gap: WallMetrics.gap,
                hero: hero,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) => WallTile(
                  item: items[i],
                  onPlay: (track) => onPlay(track, queue),
                  onDive: onDive,
                ),
                childCount: items.length,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: loadingMore
                ? const Padding(
                    padding: EdgeInsets.fromLTRB(0, 24, 0, 132),
                    child:
                        Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : const SizedBox(height: 132),
          ),
        ],
      ),
    );
  }

  Widget _skeleton(WallMetrics m) {
    final count = embedded
        ? (m.columns * 3).clamp(12, 36)
        : (m.columns * 5).clamp(18, 60);
    final hero = [for (var i = 0; i < count; i++) isHeroIndex(i)];
    final delegate = WallSliverGridDelegate(
      columns: m.columns,
      cellPx: m.cellPx,
      gap: WallMetrics.gap,
      hero: hero,
    );
    if (embedded) {
      return SizedBox(
        height: WallSliverGridDelegate.heightFor(
          columns: m.columns,
          cellPx: m.cellPx,
          gap: WallMetrics.gap,
          hero: hero,
        ),
        child: GridView.custom(
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: delegate,
          childrenDelegate: SliverChildBuilderDelegate(
            (context, i) => const Skeleton(rounded: SkeletonRound.lg),
            childCount: count,
          ),
        ),
      );
    }
    return CustomScrollView(
      controller: controller,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 132),
          sliver: SliverGrid(
            gridDelegate: delegate,
            delegate: SliverChildBuilderDelegate(
              (context, i) => const Skeleton(rounded: SkeletonRound.lg),
              childCount: count,
            ),
          ),
        ),
      ],
    );
  }
}
