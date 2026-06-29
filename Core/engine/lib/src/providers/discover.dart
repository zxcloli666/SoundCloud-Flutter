import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../rust/data.dart';
import '../rust/dto.dart';
import '../rust/dto_social.dart';
import 'pagination.dart';

/// Одна курсорная страница из ядра: элементы + курсор на следующую (`null` — конец).
class CursorSlice<T> {
  final List<T> items;
  final String? nextCursor;

  const CursorSlice({required this.items, this.nextCursor});
}

/// База для курсорной пагинации поверх моста, с фильтром [F].
///
/// Состояние — [PagedList] (общая форма для UI): `items` накапливаются,
/// `hasMore = nextCursor != null`, `nextOffset` тут просто длина списка.
/// Курсор живёт в [_cursor], фильтр — в [filter]; смена фильтра через
/// [setFilter] сбрасывает курсор и перечитывает с нуля.
abstract class CursorPagedNotifier<T, F> extends AsyncNotifier<PagedList<T>> {
  int get pageSize => 80;

  String? _cursor;
  late F _filter;

  /// Текущий фильтр.
  F get filter => _filter;

  /// Фильтр по умолчанию для первой загрузки.
  F initialFilter();

  /// Загрузить страницу: с [cursor] (хвост) или с нуля (`cursor == null`).
  Future<CursorSlice<T>> fetch({required F filter, String? cursor});

  @override
  Future<PagedList<T>> build() async {
    _filter = initialFilter();
    _cursor = null;
    final slice = await fetch(filter: _filter, cursor: null);
    _cursor = slice.nextCursor;
    return PagedList<T>(
      items: slice.items,
      hasMore: slice.nextCursor != null,
      nextOffset: slice.items.length,
    );
  }

  /// Догрузить следующую страницу по несомому курсору.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null ||
        !current.hasMore ||
        current.loadingMore ||
        _cursor == null) {
      return;
    }

    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final slice = await fetch(filter: _filter, cursor: _cursor);
      _cursor = slice.nextCursor;
      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...slice.items],
          hasMore: slice.nextCursor != null,
          loadingMore: false,
          nextOffset: current.items.length + slice.items.length,
        ),
      );
    } catch (_) {
      // Хвост упал — оставляем показанное, снимаем флаг догрузки.
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }

  /// Перечитать с нуля по текущему фильтру.
  Future<void> refresh() async {
    _cursor = null;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final slice = await fetch(filter: _filter, cursor: null);
      _cursor = slice.nextCursor;
      return PagedList<T>(
        items: slice.items,
        hasMore: slice.nextCursor != null,
        nextOffset: slice.items.length,
      );
    });
  }

  /// Применить новый фильтр: сбросить курсор и перечитать с нуля.
  void setFilter(F next) {
    _filter = next;
    refresh();
  }
}

/// Счётчики каталога (`discover/summary`).
final discoverSummaryProvider =
    FutureProvider.autoDispose<DiscoverSummaryDto>((ref) {
  return discoverSummary();
});

/// Теги-жанры каталога (`discover/tags`).
final discoverTagsProvider = FutureProvider.autoDispose<List<TagDto>>((ref) {
  return discoverTags();
});

/// «В центре внимания» (`discover/spotlight`): курируемые карточки (артист|альбом),
/// без пагинации. Лента горизонтального скролла под FeaturedHero.
final discoverSpotlightProvider =
    FutureProvider.autoDispose<SpotlightFeedDto>((ref) {
  return discoverSpotlight();
});

/// Случайный id из каталога (`discover/random`); `kind` — album/artist/track.
/// Возвращает `null`, если каталог по фильтру пуст.
final discoverRandomProvider =
    FutureProvider.autoDispose.family<String?, String?>((ref, kind) {
  return discoverRandom(kind: kind);
});

/// Альбомы, сгруппированные по году выпуска (`discover/albums_by_year`).
/// `(years, perYear, kind)` — сколько лет назад, сколько на год, тип релиза.
final discoverAlbumsByYearProvider = FutureProvider.autoDispose
    .family<List<AlbumYearBucketDto>, AlbumsByYearArgs>((ref, args) {
  return discoverAlbumsByYear(
    years: args.years,
    perYear: args.perYear,
    kind: args.kind,
  );
});

class AlbumsByYearArgs {
  final int years;
  final int perYear;
  final String? kind;

  const AlbumsByYearArgs({
    required this.years,
    required this.perYear,
    this.kind,
  });

  @override
  int get hashCode => Object.hash(years, perYear, kind);

  @override
  bool operator ==(Object other) =>
      other is AlbumsByYearArgs &&
      years == other.years &&
      perYear == other.perYear &&
      kind == other.kind;
}

/// Каталог артистов: курсорная подгрузка + фильтры (`sort`/`tag`/`q`).
/// Состояние — [PagedList] (как у offset-списков), но хвост двигает курсор:
/// `hasMore = nextCursor != null`.
final discoverArtistsProvider =
    AsyncNotifierProvider<DiscoverArtistsNotifier, PagedList<ArtistCardDto>>(
  DiscoverArtistsNotifier.new,
);

class DiscoverArtistsNotifier
    extends CursorPagedNotifier<ArtistCardDto, ArtistFilter> {
  @override
  ArtistFilter initialFilter() => const ArtistFilter();

  @override
  Future<CursorSlice<ArtistCardDto>> fetch({
    required ArtistFilter filter,
    String? cursor,
  }) async {
    final page = await discoverArtists(
      limit: pageSize,
      cursor: cursor,
      sort: filter.sort,
      tag: filter.tag,
      q: filter.q,
    );
    return CursorSlice(items: page.items, nextCursor: page.nextCursor);
  }

  /// Сменить сортировку (`popular`/`trending`/…); сбрасывает и перезагружает.
  void setSort(String? sort) => setFilter(filter.copyWith(sort: () => sort));

  /// Сменить тег-фильтр; сбрасывает и перезагружает.
  void setTag(String? tag) => setFilter(filter.copyWith(tag: () => tag));

  /// Сменить поисковый запрос; сбрасывает и перезагружает.
  void setQuery(String? q) => setFilter(filter.copyWith(q: () => q));
}

class ArtistFilter {
  final String? sort;
  final String? tag;
  final String? q;

  const ArtistFilter({this.sort, this.tag, this.q});

  ArtistFilter copyWith({
    String? Function()? sort,
    String? Function()? tag,
    String? Function()? q,
  }) {
    return ArtistFilter(
      sort: sort != null ? sort() : this.sort,
      tag: tag != null ? tag() : this.tag,
      q: q != null ? q() : this.q,
    );
  }
}

/// Каталог альбомов: курсорная подгрузка + фильтры (`sort`/`kind`/`q`).
final discoverAlbumsProvider =
    AsyncNotifierProvider<DiscoverAlbumsNotifier, PagedList<AlbumCardDto>>(
  DiscoverAlbumsNotifier.new,
);

class DiscoverAlbumsNotifier
    extends CursorPagedNotifier<AlbumCardDto, AlbumFilter> {
  @override
  AlbumFilter initialFilter() => const AlbumFilter();

  @override
  Future<CursorSlice<AlbumCardDto>> fetch({
    required AlbumFilter filter,
    String? cursor,
  }) async {
    final page = await discoverAlbums(
      limit: pageSize,
      cursor: cursor,
      sort: filter.sort,
      kind: filter.kind,
      q: filter.q,
    );
    return CursorSlice(items: page.items, nextCursor: page.nextCursor);
  }

  /// Сменить сортировку; сбрасывает и перезагружает.
  void setSort(String? sort) => setFilter(filter.copyWith(sort: () => sort));

  /// Сменить тип релиза (`album`/`ep`/…); сбрасывает и перезагружает.
  void setKind(String? kind) => setFilter(filter.copyWith(kind: () => kind));

  /// Сменить поисковый запрос; сбрасывает и перезагружает.
  void setQuery(String? q) => setFilter(filter.copyWith(q: () => q));
}

class AlbumFilter {
  final String? sort;
  final String? kind;
  final String? q;

  const AlbumFilter({this.sort, this.kind, this.q});

  AlbumFilter copyWith({
    String? Function()? sort,
    String? Function()? kind,
    String? Function()? q,
  }) {
    return AlbumFilter(
      sort: sort != null ? sort() : this.sort,
      kind: kind != null ? kind() : this.kind,
      q: q != null ? q() : this.q,
    );
  }
}
