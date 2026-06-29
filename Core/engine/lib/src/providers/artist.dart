import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../rust/api.dart';
import '../rust/data.dart';
import '../rust/data_social.dart';
import '../rust/dto.dart';
import '../rust/dto_social.dart';
import 'home.dart' show ResolvedCluster;

/// Карточка артиста (`artist_detail`) — заголовок, соц-ссылки, ~6 популярных.
final artistDetailProvider =
    FutureProvider.autoDispose.family<ArtistDetailDto, String>((ref, id) {
  return artistDetail(id: id);
});

/// Альбомы артиста (`artist_albums`) — полный список ссылок на релизы за раз.
final artistAlbumsProvider =
    FutureProvider.autoDispose.family<List<AlbumRefDto>, String>((ref, id) {
  return artistAlbums(id: id);
});

/// STAR-профиль артиста (`artist_star`) — премиум-флаг, аура, исходный SC-юзер.
final artistStarProvider =
    FutureProvider.autoDispose.family<ArtistStarDto, String>((ref, id) {
  return artistStar(id: id);
});

/// «Появляется в» (участия) — треки артиста с `role=featured`. Бэкенд отдаёт
/// порцию разом (limit 80), пагинация на этой вкладке не нужна (как в легаси).
final artistFeaturedProvider =
    FutureProvider.autoDispose.family<List<TrackDto>, String>((ref, id) async {
  final page = await artistTracks(id: id, role: 'featured', limit: 80, offset: 0);
  return page.items;
});

/// Постраничные кавер-версии артиста (`artist_covers`) с накоплением.
/// Параметризация по id — через [load(id)] при входе, [more] догружает хвост
/// (тот же паттерн, что у [artistTracksProvider]: без family-internal-arg).
final artistCoversProvider =
    AsyncNotifierProvider<ArtistCoversNotifier, ArtistCoversState>(
  ArtistCoversNotifier.new,
);

class ArtistCoversState {
  final String id;
  final List<TrackDto> tracks;
  final bool hasMore;
  final bool loadingMore;
  final int nextOffset;

  const ArtistCoversState({
    required this.id,
    required this.tracks,
    required this.hasMore,
    this.loadingMore = false,
    required this.nextOffset,
  });

  ArtistCoversState copyWith({
    List<TrackDto>? tracks,
    bool? hasMore,
    bool? loadingMore,
    int? nextOffset,
  }) {
    return ArtistCoversState(
      id: id,
      tracks: tracks ?? this.tracks,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
      nextOffset: nextOffset ?? this.nextOffset,
    );
  }
}

class ArtistCoversNotifier extends AsyncNotifier<ArtistCoversState> {
  static const _pageSize = 30;

  @override
  Future<ArtistCoversState> build() async {
    return const ArtistCoversState(
      id: '',
      tracks: [],
      hasMore: false,
      nextOffset: 0,
    );
  }

  /// Загрузить первую страницу каверов артиста [id]. Повторный вызов с тем же
  /// id игнорируется, если данные уже есть.
  Future<void> load(String id) async {
    final current = state.value;
    if (current != null && current.id == id && current.tracks.isNotEmpty) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final page = await artistCovers(id: id, limit: _pageSize, offset: 0);
      return ArtistCoversState(
        id: id,
        tracks: page.items,
        hasMore: page.hasMore,
        nextOffset: page.items.length,
      );
    });
  }

  /// Догрузить следующую страницу каверов для текущего артиста.
  Future<void> more() async {
    final current = state.value;
    if (current == null ||
        current.id.isEmpty ||
        !current.hasMore ||
        current.loadingMore) {
      return;
    }

    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final page = await artistCovers(
        id: current.id,
        limit: _pageSize,
        offset: current.nextOffset,
      );
      state = AsyncData(
        current.copyWith(
          tracks: [...current.tracks, ...page.items],
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

/// Похожее от артиста (`recommendations_artist`): кластеры id → резолв в
/// [TrackDto]. Резолв ленивый и параллельный с ограничением (см. [resolveTracks]).
///
/// PERF: суммарно много одиночных резолвов; батч-эндпоинт `resolve_tracks` в
/// мосте схлопнул бы их в один round-trip (флаг в notes).
final artistWaveProvider = FutureProvider.autoDispose
    .family<List<ResolvedCluster>, String>((ref, artistId) async {
  final clusters = await recommendationsArtist(artistId: artistId, limit: 6);
  return Future.wait(
    clusters.map((c) async {
      final tracks = await resolveTracks(urns: c.trackIds);
      return ResolvedCluster(id: c.id, tracks: tracks);
    }),
  );
});

/// Постраничные треки артиста с накоплением. Параметризация по id — через
/// [load]: страница артиста зовёт `load(id)` при входе, [more] догружает хвост.
/// (Семейство-AsyncNotifier здесь не используем, чтобы не трогать internal-arg.)
final artistTracksProvider =
    AsyncNotifierProvider<ArtistTracksNotifier, ArtistTracksState>(
  ArtistTracksNotifier.new,
);

class ArtistTracksState {
  final String id;
  final List<TrackDto> tracks;
  final bool hasMore;
  final bool loadingMore;
  final int nextOffset;

  const ArtistTracksState({
    required this.id,
    required this.tracks,
    required this.hasMore,
    this.loadingMore = false,
    required this.nextOffset,
  });

  ArtistTracksState copyWith({
    List<TrackDto>? tracks,
    bool? hasMore,
    bool? loadingMore,
    int? nextOffset,
  }) {
    return ArtistTracksState(
      id: id,
      tracks: tracks ?? this.tracks,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
      nextOffset: nextOffset ?? this.nextOffset,
    );
  }
}

class ArtistTracksNotifier extends AsyncNotifier<ArtistTracksState> {
  static const _pageSize = 40;

  @override
  Future<ArtistTracksState> build() async {
    return const ArtistTracksState(
      id: '',
      tracks: [],
      hasMore: false,
      nextOffset: 0,
    );
  }

  /// Загрузить первую страницу треков артиста [id]. Повторный вызов с тем же id
  /// игнорируется, если данные уже есть.
  Future<void> load(String id) async {
    final current = state.value;
    if (current != null && current.id == id && current.tracks.isNotEmpty) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final page =
          await artistTracks(id: id, role: 'primary', limit: _pageSize, offset: 0);
      return ArtistTracksState(
        id: id,
        tracks: page.items,
        hasMore: page.hasMore,
        nextOffset: page.items.length,
      );
    });
  }

  /// Догрузить следующую страницу для текущего артиста.
  Future<void> more() async {
    final current = state.value;
    if (current == null ||
        current.id.isEmpty ||
        !current.hasMore ||
        current.loadingMore) {
      return;
    }

    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final page = await artistTracks(
        id: current.id,
        role: 'primary',
        limit: _pageSize,
        offset: current.nextOffset,
      );
      state = AsyncData(
        current.copyWith(
          tracks: [...current.tracks, ...page.items],
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
