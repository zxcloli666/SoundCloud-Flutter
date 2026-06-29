import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Снимок постранично подгружаемого списка.
///
/// [items] — всё накопленное, [hasMore] — есть ли следующая страница,
/// [loadingMore] — идёт ли догрузка хвоста (первая загрузка живёт в
/// `AsyncValue.loading` самого нотифера, не здесь).
class PagedList<T> {
  final List<T> items;
  final bool hasMore;
  final bool loadingMore;
  final int nextOffset;

  const PagedList({
    required this.items,
    required this.hasMore,
    this.loadingMore = false,
    required this.nextOffset,
  });

  const PagedList.empty()
      : items = const [],
        hasMore = true,
        loadingMore = false,
        nextOffset = 0;

  PagedList<T> copyWith({
    List<T>? items,
    bool? hasMore,
    bool? loadingMore,
    int? nextOffset,
  }) {
    return PagedList<T>(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
      nextOffset: nextOffset ?? this.nextOffset,
    );
  }
}

/// Одна загруженная страница из ядра: элементы + флаг продолжения.
class PageSlice<T> {
  final List<T> items;
  final bool hasMore;

  const PageSlice({required this.items, required this.hasMore});
}

/// База для offset-пагинации поверх моста.
///
/// Наследник реализует [fetch] (страница по offset). Первая страница приходит
/// через `build` как `AsyncValue.loading → data`; хвост — [loadMore], который не
/// сбрасывает уже показанные элементы в loading, а лишь поднимает [PagedList.loadingMore].
abstract class PagedNotifier<T> extends AsyncNotifier<PagedList<T>> {
  int get pageSize => 30;

  /// Загрузить страницу начиная с [offset].
  Future<PageSlice<T>> fetch({required int limit, required int offset});

  @override
  Future<PagedList<T>> build() async {
    final slice = await fetch(limit: pageSize, offset: 0);
    return PagedList<T>(
      items: slice.items,
      hasMore: slice.hasMore,
      nextOffset: slice.items.length,
    );
  }

  /// Догрузить следующую страницу. Без эффекта, если идёт загрузка или хвост кончился.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;

    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final slice = await fetch(limit: pageSize, offset: current.nextOffset);
      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...slice.items],
          hasMore: slice.hasMore,
          loadingMore: false,
          nextOffset: current.nextOffset + slice.items.length,
        ),
      );
    } catch (_) {
      // Хвост упал — оставляем уже показанное, снимаем флаг догрузки.
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }

  /// Перечитать с нуля.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }
}
