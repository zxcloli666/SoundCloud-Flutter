import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../rust/api.dart';
import '../rust/data.dart';
import '../rust/dto.dart';
import 'pagination.dart';

/// Профиль текущего пользователя (`me`). Требует сессии.
final meProvider = FutureProvider<MeDto>((ref) {
  return me();
});

/// Флаг премиума (`me_subscription`). Требует сессии.
final meSubscriptionProvider = FutureProvider<bool>((ref) {
  return meSubscription();
});

/// Лайкнутые треки с бесконечной подгрузкой (`library_likes_tracks`).
final likedTracksProvider =
    AsyncNotifierProvider<LikedTracksNotifier, PagedList<TrackDto>>(
  LikedTracksNotifier.new,
);

class LikedTracksNotifier extends PagedNotifier<TrackDto> {
  @override
  int get pageSize => 50;

  @override
  Future<PageSlice<TrackDto>> fetch({
    required int limit,
    required int offset,
  }) async {
    final page = await libraryLikesTracks(limit: limit, offset: offset);
    return PageSlice(items: page.items, hasMore: page.hasMore);
  }
}

/// Лайкнутые плейлисты с подгрузкой (`library_likes_playlists`).
final likedPlaylistsProvider = AsyncNotifierProvider<LikedPlaylistsNotifier,
    PagedList<PlaylistSummaryDto>>(
  LikedPlaylistsNotifier.new,
);

class LikedPlaylistsNotifier extends PagedNotifier<PlaylistSummaryDto> {
  @override
  Future<PageSlice<PlaylistSummaryDto>> fetch({
    required int limit,
    required int offset,
  }) async {
    final page = await libraryLikesPlaylists(limit: limit, offset: offset);
    return PageSlice(items: page.items, hasMore: page.hasMore);
  }
}

/// Свои плейлисты с подгрузкой (`library_playlists`).
final myPlaylistsProvider =
    AsyncNotifierProvider<MyPlaylistsNotifier, PagedList<PlaylistSummaryDto>>(
  MyPlaylistsNotifier.new,
);

class MyPlaylistsNotifier extends PagedNotifier<PlaylistSummaryDto> {
  @override
  Future<PageSlice<PlaylistSummaryDto>> fetch({
    required int limit,
    required int offset,
  }) async {
    final page = await libraryPlaylists(limit: limit, offset: offset);
    return PageSlice(items: page.items, hasMore: page.hasMore);
  }
}

/// История прослушиваний с подгрузкой (`history`). Бэкенд отдаёт `total`, по нему
/// и вычисляем, есть ли ещё.
final historyProvider =
    AsyncNotifierProvider<HistoryNotifier, PagedList<HistoryEntryDto>>(
  HistoryNotifier.new,
);

class HistoryNotifier extends PagedNotifier<HistoryEntryDto> {
  @override
  int get pageSize => 50;

  @override
  Future<PageSlice<HistoryEntryDto>> fetch({
    required int limit,
    required int offset,
  }) async {
    final page = await history(limit: limit, offset: offset);
    final hasMore = offset + page.items.length < page.total;
    return PageSlice(items: page.items, hasMore: hasMore);
  }
}
