import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../rust/api.dart';
import '../rust/data_social.dart';
import '../rust/dto_social.dart';

/// Инвентарь оффлайн-кэша: по одному [CacheEntryDto] на скачанный m4a.
/// Перечитывается после правок через [OfflineController].
final cacheInventoryProvider =
    FutureProvider.autoDispose<List<CacheEntryDto>>((ref) {
  return cacheInventory();
});

/// Суммарный вес кэша в байтах (`cache_total_bytes`).
final cacheTotalBytesProvider = FutureProvider.autoDispose<int>((ref) async {
  final total = await cacheTotalBytes();
  return total.toInt();
});

/// Вес защищённого кэша лайков в байтах (`cache_liked_bytes`).
final cacheLikedBytesProvider = FutureProvider.autoDispose<int>((ref) async {
  final total = await cacheLikedBytes();
  return total.toInt();
});

/// Сырой поток прогресса bulk-кэша лайков из ядра.
final likesProgressStreamProvider =
    StreamProvider.autoDispose<LikesProgressDto>((ref) {
  return likesProgress();
});

/// Состояние bulk-кэша лайков для кнопки в настройках.
class LikesCacheState {
  final bool running;
  final int done;
  final int failed;
  final int total;
  const LikesCacheState({
    this.running = false,
    this.done = 0,
    this.failed = 0,
    this.total = 0,
  });
}

/// Драйвер кнопки «Закэшировать лайки»: подписан на поток прогресса ядра,
/// держит текущее состояние и по завершении перечитывает размеры кэша.
final likesCacheProvider =
    NotifierProvider<LikesCacheNotifier, LikesCacheState>(
  LikesCacheNotifier.new,
);

class LikesCacheNotifier extends Notifier<LikesCacheState> {
  @override
  LikesCacheState build() {
    ref.listen(likesProgressStreamProvider, (_, next) {
      final p = next.value;
      if (p == null) return;
      state = LikesCacheState(
        running: !p.finished,
        done: p.done,
        failed: p.failed,
        total: p.total,
      );
      if (p.finished) {
        ref.invalidate(cacheInventoryProvider);
        ref.invalidate(cacheTotalBytesProvider);
        ref.invalidate(cacheLikedBytesProvider);
      }
    });
    return const LikesCacheState();
  }

  /// Запустить кэширование переданных лайков (urn-ы). Прогресс — из потока ядра.
  Future<void> start(List<String> urns) async {
    state = LikesCacheState(running: true, total: urns.length);
    await cacheLikes(urns: urns);
  }

  Future<void> cancel() => cancelCacheLikes();
}

/// Управляет оффлайн-кэшем: качает/удаляет m4a и перечитывает инвентарь.
///
/// Своего состояния не держит — это командный контроллер. Каждый метод правит
/// кэш в ядре и инвалидирует [cacheInventoryProvider] с [cacheTotalBytesProvider],
/// чтобы экран «Кузницы» показал актуальный список и вес.
final offlineControllerProvider =
    NotifierProvider<OfflineController, void>(OfflineController.new);

class OfflineController extends Notifier<void> {
  @override
  void build() {}

  /// Удалить трек из кэша и перечитать инвентарь.
  Future<void> remove(String urn) async {
    await cacheRemove(urn: urn);
    _refresh();
  }

  /// Скачать трек в кэш (если ещё нет) и перечитать инвентарь.
  Future<void> ensure(String urn) async {
    await cacheEnsure(urn: urn);
    _refresh();
  }

  /// Очистить обычный кэш (защищённый кэш лайков не трогаем) и перечитать.
  Future<void> clearAll() async {
    await cacheClear();
    _refresh();
  }

  /// Применить лимит аудиокэша (LRU-вытеснение) и перечитать размеры.
  Future<void> enforceLimit(int limitMB) async {
    await cacheEnforceLimit(limitMb: BigInt.from(limitMB));
    _refresh();
  }

  void _refresh() {
    ref.invalidate(cacheInventoryProvider);
    ref.invalidate(cacheTotalBytesProvider);
    ref.invalidate(cacheLikedBytesProvider);
  }
}
