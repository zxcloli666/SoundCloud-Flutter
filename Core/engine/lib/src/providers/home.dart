import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../rust/api.dart';
import '../rust/data.dart';
import '../rust/data_social.dart';
import '../rust/dto.dart';
import 'settings.dart';

/// Один кластер реки с уже зарезолвленными треками (а не голыми id) и
/// соседями-артистами (для «От любимых»/«Близкие миры» — артист-карточки).
class ResolvedCluster {
  final String id;
  final List<TrackDto> tracks;
  final List<ClusterNeighborDto> neighbors;

  const ResolvedCluster({
    required this.id,
    required this.tracks,
    this.neighbors = const [],
  });
}

/// Фильтры волны (легаси `EstuaryDeck`): `hideListened`/`languages` уходят на
/// бэкенд query-параметрами, `hideLiked` — клиентский фильтр (как в легаси).
class WaveFilters {
  final bool hideListened;
  final bool hideLiked;
  final List<String> languages;

  const WaveFilters({
    required this.hideListened,
    required this.hideLiked,
    required this.languages,
  });
}

/// Производная от персиста: фильтры волны живут в [settingsProvider] (settings.json),
/// поэтому переживают перезапуск (а не «тыкнул и забыл»). Сеттеры — у
/// `settingsProvider.notifier` (`setSoundwave*`).
final waveFiltersProvider = Provider<WaveFilters>((ref) {
  final s = ref.watch(settingsProvider);
  return WaveFilters(
    hideListened: s.soundwaveHideListened,
    hideLiked: s.soundwaveHideLiked,
    languages: s.soundwaveLanguages,
  );
});

/// Сырые кластеры реки (`home_river`) — только id треков по кластерам. Языки и
/// «свежак» (hide_listened) уходят на бэкенд; смена фильтров пере-запрашивает.
final homeRiverClustersProvider =
    FutureProvider.autoDispose<List<ClusterDto>>((ref) {
  final f = ref.watch(waveFiltersProvider);
  return homeRiver(limit: 6, languages: f.languages, hideListened: f.hideListened);
});

/// Река с резолвом: для каждого кластера id → [TrackDto] одним батч-резолвом
/// (`resolve_tracks`). `hideLiked` фильтрует клиентом (трек + его сосед), как в
/// легаси, и выкидывает опустевшие кластеры.
final homeRiverProvider =
    FutureProvider.autoDispose<List<ResolvedCluster>>((ref) async {
  final clusters = await ref.watch(homeRiverClustersProvider.future);
  final hideLiked = ref.watch(waveFiltersProvider.select((f) => f.hideLiked));
  final resolved = await Future.wait(
    clusters.map((c) async {
      final tracks = await resolveTracks(urns: c.trackIds);
      return ResolvedCluster(id: c.id, tracks: tracks, neighbors: c.neighbors);
    }),
  );
  if (!hideLiked) return resolved;

  final out = <ResolvedCluster>[];
  for (final rc in resolved) {
    final tracks = rc.tracks.where((t) => !(t.userFavorite ?? false)).toList();
    if (tracks.isEmpty) continue;
    final keptIds = {for (final t in tracks) t.urn.split(':').last};
    final neighbors =
        rc.neighbors.where((n) => keptIds.contains(n.trackId)).toList();
    out.add(ResolvedCluster(id: rc.id, tracks: tracks, neighbors: neighbors));
  }
  return out;
});

/// Бесконечная волна (`recommendations/wave`) с курсором. Питает очередь
/// воспроизведения, а не визуал: [next] догружает следующую порцию.
final waveProvider = NotifierProvider<WaveNotifier, AsyncValue<WaveState>>(
  WaveNotifier.new,
);

class WaveState {
  final List<WaveItemDto> items;
  final String? cursor;
  final bool loadingMore;

  const WaveState({
    required this.items,
    this.cursor,
    this.loadingMore = false,
  });

  bool get hasMore => cursor != null;

  WaveState copyWith({
    List<WaveItemDto>? items,
    String? cursor,
    bool? loadingMore,
  }) {
    return WaveState(
      items: items ?? this.items,
      cursor: cursor ?? this.cursor,
      loadingMore: loadingMore ?? this.loadingMore,
    );
  }
}

class WaveNotifier extends Notifier<AsyncValue<WaveState>> {
  static const _limit = 20;

  @override
  AsyncValue<WaveState> build() {
    _load();
    return const AsyncValue.loading();
  }

  Future<void> _load() async {
    final f = ref.read(waveFiltersProvider);
    state = await AsyncValue.guard(() async {
      final w = await wave(
        limit: _limit,
        cursor: null,
        languages: f.languages,
        hideListened: f.hideListened,
      );
      return WaveState(items: w.items, cursor: w.cursor);
    });
  }

  /// Догрузить следующую порцию волны по курсору.
  Future<void> next() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;

    state = AsyncData(current.copyWith(loadingMore: true));
    final f = ref.read(waveFiltersProvider);
    try {
      final w = await wave(
        limit: _limit,
        cursor: current.cursor,
        languages: f.languages,
        hideListened: f.hideListened,
      );
      state = AsyncData(
        WaveState(items: [...current.items, ...w.items], cursor: w.cursor),
      );
    } catch (_) {
      // Хвост упал — сохраняем накопленное, снимаем флаг догрузки.
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    await _load();
  }
}
