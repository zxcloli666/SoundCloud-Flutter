import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../rust/api.dart';
import '../rust/data.dart';
import '../rust/data_social.dart';
import '../rust/dto.dart';
import 'home.dart' show ResolvedCluster;

/// Резолв одного трека по urn. `null` — трек недоступен/не найден.
final trackProvider =
    FutureProvider.autoDispose.family<TrackDto?, String>((ref, urn) {
  return resolveTrack(urn: urn);
});

/// Похожие треки (`GET /tracks/{urn}/related`).
final trackRelatedProvider =
    FutureProvider.autoDispose.family<List<TrackDto>, String>((ref, urn) async {
  final page = await trackRelated(urn: urn, limit: 20);
  return page.items;
});

/// Лирика трека (`GET /lyrics/{sc_track_id}`). `null` — лирики нет.
final lyricsProvider =
    FutureProvider.autoDispose.family<LyricsDto?, String>((ref, scTrackId) {
  return lyrics(scTrackId: scTrackId);
});

/// Реальные сэмплы огибающей по `waveform_url` трека. `null` — мост ещё не отдал
/// (виджет тогда рисует синтетическую форму). Float32List ядра → `List<double>`.
final waveformProvider =
    FutureProvider.autoDispose.family<List<double>?, String>(
        (ref, waveformUrl) async {
  if (waveformUrl.isEmpty) return null;
  final samples = await trackWaveform(waveformUrl: waveformUrl);
  return samples.toList(growable: false);
});

/// Кто лайкнул трек (`GET /tracks/{urn}/favoriters`). Без догрузки — первая
/// порция; страница знает [UserPageDto.hasMore].
final trackFavoritersProvider =
    FutureProvider.autoDispose.family<UserPageDto, String>((ref, urn) {
  return trackFavoriters(urn: urn, limit: 30);
});

/// Постраничные комментарии трека с накоплением (как плейлист-треки): [load]
/// на входе на страницу, [more] догружает хвост, [post] добавляет свой коммент в
/// начало (оптимистично — сервер уже принял).
final trackCommentsProvider =
    AsyncNotifierProvider<TrackCommentsNotifier, CommentsState>(
  TrackCommentsNotifier.new,
);

class CommentsState {
  final String urn;
  final List<CommentDto> comments;
  final bool hasMore;
  final bool loadingMore;
  final int nextOffset;

  const CommentsState({
    required this.urn,
    required this.comments,
    required this.hasMore,
    this.loadingMore = false,
    required this.nextOffset,
  });

  CommentsState copyWith({
    List<CommentDto>? comments,
    bool? hasMore,
    bool? loadingMore,
    int? nextOffset,
  }) =>
      CommentsState(
        urn: urn,
        comments: comments ?? this.comments,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
        nextOffset: nextOffset ?? this.nextOffset,
      );
}

class TrackCommentsNotifier extends AsyncNotifier<CommentsState> {
  static const _pageSize = 20;

  @override
  Future<CommentsState> build() async {
    return const CommentsState(
        urn: '', comments: [], hasMore: false, nextOffset: 0);
  }

  Future<void> load(String urn) async {
    final current = state.value;
    if (current != null && current.urn == urn && current.comments.isNotEmpty) {
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final page = await trackComments(urn: urn, limit: _pageSize, offset: 0);
      return CommentsState(
        urn: urn,
        comments: page.items,
        hasMore: page.hasMore,
        nextOffset: page.items.length,
      );
    });
  }

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
      final page = await trackComments(
        urn: current.urn,
        limit: _pageSize,
        offset: current.nextOffset,
      );
      state = AsyncData(current.copyWith(
        comments: [...current.comments, ...page.items],
        hasMore: page.hasMore,
        loadingMore: false,
        nextOffset: current.nextOffset + page.items.length,
      ));
    } catch (_) {
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }

  /// Оставить комментарий (опц. с таймкодом в мс) и вставить его сверху.
  Future<void> post(String body, {int? timestampMs}) async {
    final current = state.value;
    if (current == null || current.urn.isEmpty || body.trim().isEmpty) return;
    final created = await postComment(
      urn: current.urn,
      body: body.trim(),
      timestampMs: timestampMs,
    );
    state = AsyncData(current.copyWith(comments: [created, ...current.comments]));
  }
}

/// Похожие через рекомендации ядра (`recommendations/similar`): кластеры id →
/// зарезолвленные [TrackDto] батч-резолвом (`resolve_tracks`, один round-trip);
/// недоступные треки выпадают.
final recommendationsSimilarProvider =
    FutureProvider.autoDispose.family<List<ResolvedCluster>, String>(
        (ref, trackId) async {
  final clusters = await recommendationsSimilar(trackId: trackId, limit: 6);
  return Future.wait(
    clusters.map((c) async {
      final tracks = await resolveTracks(urns: c.trackIds);
      return ResolvedCluster(id: c.id, tracks: tracks);
    }),
  );
});
