import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../providers.dart';
import '../../rust/dto.dart';
import '../../rust/dto_social.dart';
import 'catalog_scaffold.dart';
import 'discover_seed.dart';
import 'filter_row.dart';

/// Каталог альбомов (легаси §3.3 `AlbumsCatalog`): фильтры тип/сортировка,
/// VirtualGrid карточек; при `recent` без запроса — группировка по годам.
/// Тип/сортировка/поиск едут на сервер курсором через
/// `discoverAlbumsProvider.notifier` (`setKind`/`setSort`/`setQuery`); годы —
/// `discoverAlbumsByYearProvider`. Пере-тасовка — `seededOrder` (§3.3).
class AlbumsCatalog extends ConsumerStatefulWidget {
  final String query;

  /// Сообщает странице текущую сортировку — она решает, курсорить ли плоский
  /// каталог или мы в непагинируемом режиме год-бакетов (§3.3).
  final ValueChanged<String>? onSortChanged;

  const AlbumsCatalog({super.key, required this.query, this.onSortChanged});

  @override
  ConsumerState<AlbumsCatalog> createState() => _AlbumsCatalogState();
}

class _AlbumsCatalogState extends ConsumerState<AlbumsCatalog> {
  String _kind = 'all';
  String _sort = 'recent';
  int _nonce = 0;

  static const _kindOptions = [
    FilterOption(id: 'all', label: 'Все типы'),
    FilterOption(id: 'album', label: 'Альбом'),
    FilterOption(id: 'ep', label: 'EP'),
    FilterOption(id: 'single', label: 'Сингл'),
    FilterOption(id: 'compilation', label: 'Сборник'),
  ];
  static const _sortOptions = [
    FilterOption(id: 'recent', label: 'Свежие'),
    FilterOption(id: 'popular', label: 'Популярные'),
    FilterOption(id: 'tracks', label: 'Треки'),
    FilterOption(id: 'az', label: 'А-Я'),
  ];

  bool get _useYearBuckets => _sort == 'recent' && widget.query.isEmpty;

  /// `all`/`recent` — дефолты каталога: на сервер уезжает `null` вместо литерала.
  String? get _serverKind => _kind == 'all' ? null : _kind;
  String? get _serverSort => _sort == 'recent' ? null : _sort;

  @override
  void didUpdateWidget(AlbumsCatalog old) {
    super.didUpdateWidget(old);
    if (widget.query != old.query) _pushQuery();
  }

  void _pushQuery() {
    ref.read(discoverAlbumsProvider.notifier).setQuery(_serverQuery);
  }

  /// Поиск каталога с min-len 2 (легаси §3.3): короче — это «нет фильтра».
  String? get _serverQuery {
    final q = widget.query.trim();
    return q.length < 2 ? null : q;
  }

  void _onKind(String v) {
    if (v == _kind) return;
    setState(() => _kind = v);
    ref.read(discoverAlbumsProvider.notifier).setKind(_serverKind);
  }

  void _onSort(String v) {
    if (v == _sort) return;
    setState(() => _sort = v);
    ref.read(discoverAlbumsProvider.notifier).setSort(_serverSort);
    widget.onSortChanged?.call(v);
  }

  @override
  Widget build(BuildContext context) {
    final controls = Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 16,
      runSpacing: 12,
      children: [
        FilterRow(options: _kindOptions, active: _kind, onChanged: _onKind),
        FilterRow(
          options: _sortOptions,
          active: _sort,
          small: true,
          onChanged: _onSort,
        ),
      ],
    );

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(child: controls),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ..._useYearBuckets ? _yearBucketSlivers() : _flatSlivers(),
      ],
    );
  }

  /// Плоская сетка по серверному курсору (`discoverAlbumsProvider`).
  List<Widget> _flatSlivers() {
    final async = ref.watch(discoverAlbumsProvider);
    return async.when(
      loading: () => const [
        SliverToBoxAdapter(child: CatalogSkeletonGrid(itemHeight: 300)),
      ],
      error: (e, _) => [
        const SliverToBoxAdapter(
          child: CatalogEmpty(
            icon: LucideIcons.disc3,
            message: 'Не удалось загрузить альбомы',
          ),
        ),
      ],
      data: _flatBody,
    );
  }

  List<Widget> _flatBody(PagedList<AlbumCardDto> paged) {
    if (paged.items.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: CatalogEmpty(
            icon: LucideIcons.disc3,
            message: widget.query.isNotEmpty
                ? 'Ничего не нашлось по «${widget.query}»'
                : 'Пока нет альбомов',
          ),
        ),
      ];
    }
    final items = seededOrder(
      paged.items,
      reshuffleSeed('albums:$_sort:$_kind', _nonce),
    );
    return [
      VirtualGrid<AlbumCardDto>(
        items: items,
        itemHeight: 300,
        minColumnWidth: 180,
        gap: 20,
        overscan: 3,
        getItemKey: (a, _) => ValueKey('album-${a.id}'),
        renderItem: (context, a, _) => _card(a),
      ).sliver(),
      SliverToBoxAdapter(
        child: CatalogTail(
          loadingMore: paged.loadingMore,
          capped: !paged.hasMore && paged.items.isNotEmpty,
          capMessage: 'Это весь каталог по текущим фильтрам.',
        ),
      ),
    ];
  }

  /// Группировка по году релиза (легаси `YearBucketsView`): сервер сам отдаёт
  /// топ-8 годов по `discover/albums/by-year` (years=8, per_year=20). Каждый
  /// бакет — отдельный `SliverGrid`, off-screen годы не строятся.
  List<Widget> _yearBucketSlivers() {
    final async = ref.watch(
      discoverAlbumsByYearProvider(
        AlbumsByYearArgs(years: 8, perYear: 20, kind: _serverKind),
      ),
    );
    return async.when(
      loading: () => const [
        SliverToBoxAdapter(child: CatalogSkeletonGrid(itemHeight: 300)),
      ],
      error: (e, _) => [
        const SliverToBoxAdapter(
          child: CatalogEmpty(
            icon: LucideIcons.disc3,
            message: 'Не удалось загрузить альбомы',
          ),
        ),
      ],
      data: _yearBucketBody,
    );
  }

  List<Widget> _yearBucketBody(List<AlbumYearBucketDto> buckets) {
    final filled = buckets.where((b) => b.items.isNotEmpty).toList();
    if (filled.isEmpty) {
      return [
        const SliverToBoxAdapter(
          child: CatalogEmpty(
            icon: LucideIcons.disc3,
            message: 'Пока нет альбомов',
          ),
        ),
      ];
    }
    return [
      for (final bucket in filled) ...[
        SliverToBoxAdapter(
          child: _YearLabel(year: bucket.year, count: bucket.items.length),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        VirtualGrid<AlbumCardDto>(
          items: bucket.items,
          itemHeight: 300,
          minColumnWidth: 180,
          gap: 20,
          overscan: 3,
          getItemKey: (a, _) => ValueKey('year-${bucket.year}-${a.id}'),
          renderItem: (context, a, _) => _card(a),
        ).sliver(),
        const SliverToBoxAdapter(child: SizedBox(height: 48)),
      ],
    ];
  }

  Widget _card(AlbumCardDto a) {
    final accent = (a.star) ? gradientForId(a.id).first : null;
    return AlbumCard(
      data: _toCardData(a),
      accent: accent,
      onTap: () => ref.read(routerProvider.notifier).push(AlbumRoute(a.id)),
    );
  }

  /// Тип релиза по числу треков (карточка не несёт kind) — для лейбла плитки.
  String _kindOf(AlbumCardDto a) {
    final n = a.trackCount;
    if (n <= 1) return 'single';
    if (n <= 4) return 'ep';
    if (n >= 10) return 'compilation';
    return 'album';
  }

  AlbumCardData _toCardData(AlbumCardDto a) {
    final ms = a.totalDurationMs?.toInt() ?? 0;
    return AlbumCardData(
      id: a.id,
      title: a.title,
      artistName: a.primaryArtist.name,
      coverUrl: a.coverUrl,
      kindLabel: _kindLabel(_kindOf(a)),
      trackCountLabel: '${a.trackCount}',
      durationLabel: ms > 0 ? formatDurationLong(ms) : null,
      releaseYear: a.releaseYear,
      star: a.star,
    );
  }

  String _kindLabel(String kind) => switch (kind) {
        'single' => 'Сингл',
        'ep' => 'EP',
        'compilation' => 'Сборник',
        _ => 'Альбом',
      };
}

/// Лейбл года (легаси `YearGroup`): большой градиент-год `clamp(48,7vw,80)` +
/// строка-счётчик релизов. Сетка карточек идёт отдельным сливером ниже, чтобы
/// off-screen бакеты не строились.
class _YearLabel extends StatelessWidget {
  final int year;
  final int count;

  const _YearLabel({required this.year, required this.count});

  @override
  Widget build(BuildContext context) {
    final accent = ScTheme.paletteOf(context).accent;
    final wide = MediaQuery.sizeOf(context).width >= 768;
    return Column(
      crossAxisAlignment:
          wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        ShaderMask(
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [accent.withValues(alpha: 0.95), accent.withValues(alpha: 0.4)],
          ).createShader(rect),
          child: Text(
            '$year',
            style: TextStyle(
              color: Colors.white,
              fontSize: (MediaQuery.sizeOf(context).width * 0.07).clamp(48, 80),
              height: 1,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'РЕЛИЗЫ · $count',
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
