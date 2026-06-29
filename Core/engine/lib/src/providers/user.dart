import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../rust/api.dart';
import '../rust/data_social.dart';
import '../rust/dto.dart';
import '../rust/dto_social.dart';

/// Профиль пользователя по urn (`user`). `null` — не резолвится/скрыт.
final userProvider =
    FutureProvider.autoDispose.family<UserDto?, String>((ref, urn) {
  return user(urn: urn);
});

/// Соц-ссылки профиля (`user_web_profiles`).
final userWebProfilesProvider = FutureProvider.autoDispose
    .family<List<WebProfileDto>, String>((ref, urn) {
  return userWebProfiles(urn: urn);
});

/// Подписан ли текущий юзер на этого (`user_subscription`). Требует сессии.
final userSubscriptionProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, urn) {
  return userSubscription(urn: urn);
});

/// Снимок urn-привязанного постраничного списка с накоплением.
class UserPagedState<T> {
  final String urn;
  final List<T> items;
  final bool hasMore;
  final bool loadingMore;
  final int nextOffset;

  const UserPagedState({
    required this.urn,
    required this.items,
    required this.hasMore,
    this.loadingMore = false,
    required this.nextOffset,
  });

  const UserPagedState.empty()
      : urn = '',
        items = const [],
        hasMore = false,
        loadingMore = false,
        nextOffset = 0;

  UserPagedState<T> copyWith({
    List<T>? items,
    bool? hasMore,
    bool? loadingMore,
    int? nextOffset,
  }) {
    return UserPagedState<T>(
      urn: urn,
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
      nextOffset: nextOffset ?? this.nextOffset,
    );
  }
}

/// База для offset-пагинации, параметризованной urn пользователя. Семейство-
/// AsyncNotifier не используем (internal-arg); вместо этого страница профиля
/// зовёт [load] с urn при входе и [more] для хвоста — как [ArtistTracksNotifier].
abstract class UserPagedNotifier<T> extends AsyncNotifier<UserPagedState<T>> {
  int get pageSize => 30;

  /// Загрузить страницу [urn] начиная с [offset].
  Future<({List<T> items, bool hasMore})> fetch({
    required String urn,
    required int limit,
    required int offset,
  });

  @override
  Future<UserPagedState<T>> build() async => UserPagedState<T>.empty();

  /// Первая страница для [urn]. Повторный вызов с тем же urn — без эффекта,
  /// если данные уже есть.
  Future<void> load(String urn) async {
    final current = state.value;
    if (current != null && current.urn == urn && current.items.isNotEmpty) {
      return;
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final page = await fetch(urn: urn, limit: pageSize, offset: 0);
      return UserPagedState<T>(
        urn: urn,
        items: page.items,
        hasMore: page.hasMore,
        nextOffset: page.items.length,
      );
    });
  }

  /// Догрузить следующую страницу для текущего urn.
  Future<void> more() async {
    final current = state.value;
    if (current == null ||
        current.urn.isEmpty ||
        !current.hasMore ||
        current.loadingMore) {
      return;
    }

    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final page = await fetch(
        urn: current.urn,
        limit: pageSize,
        offset: current.nextOffset,
      );
      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...page.items],
          hasMore: page.hasMore,
          loadingMore: false,
          nextOffset: current.nextOffset + page.items.length,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }
}

/// Треки пользователя (`user_tracks`).
final userTracksProvider =
    AsyncNotifierProvider<UserTracksNotifier, UserPagedState<TrackDto>>(
  UserTracksNotifier.new,
);

class UserTracksNotifier extends UserPagedNotifier<TrackDto> {
  @override
  int get pageSize => 40;

  @override
  Future<({List<TrackDto> items, bool hasMore})> fetch({
    required String urn,
    required int limit,
    required int offset,
  }) async {
    final page = await userTracks(urn: urn, limit: limit, offset: offset);
    return (items: page.items, hasMore: page.hasMore);
  }
}

/// Плейлисты пользователя (`user_playlists`).
final userPlaylistsProvider = AsyncNotifierProvider<UserPlaylistsNotifier,
    UserPagedState<PlaylistSummaryDto>>(
  UserPlaylistsNotifier.new,
);

class UserPlaylistsNotifier extends UserPagedNotifier<PlaylistSummaryDto> {
  @override
  Future<({List<PlaylistSummaryDto> items, bool hasMore})> fetch({
    required String urn,
    required int limit,
    required int offset,
  }) async {
    final page = await userPlaylists(urn: urn, limit: limit, offset: offset);
    return (items: page.items, hasMore: page.hasMore);
  }
}

/// Лайкнутые треки пользователя (`user_liked_tracks`).
final userLikedTracksProvider =
    AsyncNotifierProvider<UserLikedTracksNotifier, UserPagedState<TrackDto>>(
  UserLikedTracksNotifier.new,
);

class UserLikedTracksNotifier extends UserPagedNotifier<TrackDto> {
  @override
  int get pageSize => 40;

  @override
  Future<({List<TrackDto> items, bool hasMore})> fetch({
    required String urn,
    required int limit,
    required int offset,
  }) async {
    final page = await userLikedTracks(urn: urn, limit: limit, offset: offset);
    return (items: page.items, hasMore: page.hasMore);
  }
}

/// Подписчики пользователя (`user_followers`).
final userFollowersProvider =
    AsyncNotifierProvider<UserFollowersNotifier, UserPagedState<UserDto>>(
  UserFollowersNotifier.new,
);

class UserFollowersNotifier extends UserPagedNotifier<UserDto> {
  @override
  Future<({List<UserDto> items, bool hasMore})> fetch({
    required String urn,
    required int limit,
    required int offset,
  }) async {
    final page = await userFollowers(urn: urn, limit: limit, offset: offset);
    return (items: page.items, hasMore: page.hasMore);
  }
}

/// Подписки пользователя (`user_followings`).
final userFollowingsProvider =
    AsyncNotifierProvider<UserFollowingsNotifier, UserPagedState<UserDto>>(
  UserFollowingsNotifier.new,
);

class UserFollowingsNotifier extends UserPagedNotifier<UserDto> {
  @override
  Future<({List<UserDto> items, bool hasMore})> fetch({
    required String urn,
    required int limit,
    required int offset,
  }) async {
    final page = await userFollowings(urn: urn, limit: limit, offset: offset);
    return (items: page.items, hasMore: page.hasMore);
  }
}
