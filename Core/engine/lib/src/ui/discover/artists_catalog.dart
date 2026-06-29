import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../providers.dart';
import '../../rust/dto.dart';
import 'catalog_scaffold.dart';
import 'discover_seed.dart';
import 'filter_row.dart';

/// Каталог артистов (легаси §3.3 `ArtistsCatalog`): фильтры тег/сортировка,
/// VirtualGrid карточек, курсорная подгрузка. Тег/сортировка/поиск едут на
/// сервер через `discoverArtistsProvider.notifier` (`setTag`/`setSort`/
/// `setQuery`); пере-тасовка отдачи — `seededOrder` (§3.3).
class ArtistsCatalog extends ConsumerStatefulWidget {
  final String query;

  /// Внешний тег-фильтр от призмы (§3.3). null → внутренний выбор фильтр-ряда.
  final String? tag;

  const ArtistsCatalog({super.key, required this.query, this.tag});

  @override
  ConsumerState<ArtistsCatalog> createState() => _ArtistsCatalogState();
}

class _ArtistsCatalogState extends ConsumerState<ArtistsCatalog> {
  String _sort = 'popular';
  late String _tag = widget.tag ?? 'all';
  int _nonce = 0;

  static const _sortOptions = [
    FilterOption(id: 'popular', label: 'Популярные'),
    FilterOption(id: 'trending', label: 'В тренде'),
    FilterOption(id: 'listeners', label: 'Слушатели'),
    FilterOption(id: 'tracks', label: 'Треки'),
    FilterOption(id: 'star', label: 'STAR'),
    FilterOption(id: 'az', label: 'А-Я'),
  ];

  /// `all`/`popular` — дефолты: на сервер уезжает `null` вместо литерала.
  String? get _serverTag => _tag == 'all' ? null : _tag;
  String? get _serverSort => _sort == 'popular' ? null : _sort;

  /// Поиск каталога с min-len 2 (легаси §3.3): короче — это «нет фильтра».
  String? get _serverQuery {
    final q = widget.query.trim();
    return q.length < 2 ? null : q;
  }

  @override
  void initState() {
    super.initState();
    if (_serverTag != null || _serverQuery != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncFilters();
      });
    }
  }

  @override
  void didUpdateWidget(ArtistsCatalog old) {
    super.didUpdateWidget(old);
    var changed = false;
    if (widget.tag != old.tag && widget.tag != null && widget.tag != _tag) {
      _tag = widget.tag!;
      changed = true;
    }
    if (widget.query != old.query) changed = true;
    if (changed) _syncFilters();
  }

  /// Одним фильтром (один refetch), а не тремя setX подряд.
  void _syncFilters() {
    ref.read(discoverArtistsProvider.notifier).setFilter(
          ArtistFilter(sort: _serverSort, tag: _serverTag, q: _serverQuery),
        );
  }

  void _onTag(String v) {
    if (v == _tag) return;
    setState(() => _tag = v);
    ref.read(discoverArtistsProvider.notifier).setTag(_serverTag);
  }

  void _onSort(String v) {
    if (v == _sort) return;
    setState(() => _sort = v);
    ref.read(discoverArtistsProvider.notifier).setSort(_serverSort);
  }

  @override
  Widget build(BuildContext context) {
    final tags = ref.watch(discoverTagsProvider);
    final async = ref.watch(discoverArtistsProvider);

    final tagOptions = <FilterOption>[
      const FilterOption(id: 'all', label: 'Все теги'),
      ...tags.maybeWhen(
        data: (list) => list.map(
          (t) => FilterOption(id: t.id, label: t.label, count: t.count.toInt()),
        ),
        orElse: () => const <FilterOption>[],
      ),
    ];

    final controls = Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 16,
      runSpacing: 12,
      children: [
        FilterRow(options: tagOptions, active: _tag, onChanged: _onTag),
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
        ...async.when(
          loading: () => const [
            SliverToBoxAdapter(child: CatalogSkeletonGrid(itemHeight: 320)),
          ],
          error: (e, _) => [
            const SliverToBoxAdapter(
              child: CatalogEmpty(
                icon: LucideIcons.mic,
                message: 'Не удалось загрузить артистов',
              ),
            ),
          ],
          data: _gridSlivers,
        ),
      ],
    );
  }

  List<Widget> _gridSlivers(PagedList<ArtistCardDto> paged) {
    if (paged.items.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: CatalogEmpty(
            icon: LucideIcons.mic,
            message: widget.query.isNotEmpty
                ? 'Ничего не нашлось по «${widget.query}»'
                : 'Пока нет артистов',
          ),
        ),
      ];
    }
    final items = seededOrder(
      paged.items,
      reshuffleSeed('artists:$_sort:$_tag', _nonce),
    );
    return [
      VirtualGrid<ArtistCardDto>(
        items: items,
        itemHeight: 320,
        minColumnWidth: 210,
        gap: 20,
        overscan: 3,
        getItemKey: (a, _) => ValueKey('artist-${a.id}'),
        renderItem: (context, a, _) => ArtistCard(
          data: _toCardData(a),
          onTap: () => ref.read(routerProvider.notifier).push(ArtistRoute(a.id)),
        ),
      ).sliver(),
      SliverToBoxAdapter(
        child: CatalogTail(
          loadingMore: paged.loadingMore,
          capped: !paged.hasMore && paged.items.isNotEmpty,
          capMessage: 'Это все артисты по текущим фильтрам.',
        ),
      ),
    ];
  }

  ArtistCardData _toCardData(ArtistCardDto a) {
    final orbs = (a.star && a.auraId != null)
        ? gradientForId(a.id)
        : const <Color>[];
    final stats = <ArtistStat>[
      ArtistStat(
        icon: LucideIcons.mic,
        value: '${a.trackCountPrimary}',
        label: 'Треки',
      ),
      if (a.trackCountFeatured > 0)
        ArtistStat(
          icon: LucideIcons.star,
          value: '${a.trackCountFeatured}',
          label: 'Гостевые',
        ),
      ArtistStat(
        icon: LucideIcons.disc3,
        value: '${a.albumCount}',
        label: 'Альбомы',
      ),
    ];
    return ArtistCardData(
      id: a.id,
      name: a.name,
      avatarUrl: a.avatarUrl,
      country: a.country,
      tags: a.tags,
      stats: stats,
      popularity: a.popularity,
      monthlyListenersLabel: formatCount(a.monthlyListeners.toInt()),
      trendLabel: '+${(a.popularity * 100).round()}%',
      verified: a.confidence >= 0.7,
      star: a.star,
      auraOrbs: orbs,
    );
  }
}
