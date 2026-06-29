import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../rust/api.dart';
import '../rust/data.dart';
import '../rust/data_social.dart';
import '../rust/dto.dart';
import 'user.dart';

/// Постраничный треклист плейлиста с накоплением. Параметризация по urn — через
/// [load] (страница плейлиста зовёт `load(urn)` при входе), [more] догружает хвост.
final playlistTracksProvider =
    AsyncNotifierProvider<PlaylistTracksNotifier, PlaylistTracksState>(
  PlaylistTracksNotifier.new,
);

class PlaylistTracksState {
  final String urn;
  final PlaylistSummaryDto? summary;
  final List<TrackDto> tracks;
  final bool hasMore;
  final bool loadingMore;
  final int nextOffset;

  const PlaylistTracksState({
    required this.urn,
    this.summary,
    required this.tracks,
    required this.hasMore,
    this.loadingMore = false,
    required this.nextOffset,
  });

  PlaylistTracksState copyWith({
    PlaylistSummaryDto? summary,
    List<TrackDto>? tracks,
    bool? hasMore,
    bool? loadingMore,
    int? nextOffset,
  }) {
    return PlaylistTracksState(
      urn: urn,
      summary: summary ?? this.summary,
      tracks: tracks ?? this.tracks,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
      nextOffset: nextOffset ?? this.nextOffset,
    );
  }
}

class PlaylistTracksNotifier extends AsyncNotifier<PlaylistTracksState> {
  static const _pageSize = 50;
  static const _reorderDebounce = Duration(milliseconds: 700);

  /// Дебаунс-таймер коммита нового порядка: пока юзер таскает строки, порядок
  /// меняется локально, а в ядро уходит один `playlistReorder` после паузы.
  Timer? _reorderCommit;

  @override
  Future<PlaylistTracksState> build() async {
    ref.onDispose(() => _reorderCommit?.cancel());
    return const PlaylistTracksState(
      urn: '',
      tracks: [],
      hasMore: false,
      nextOffset: 0,
    );
  }

  Future<void> load(String urn) async {
    final current = state.value;
    if (current != null && current.urn == urn && current.tracks.isNotEmpty) {
      return;
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      // Шапка — из summary (`/playlists/{urn}`); треки — из `/playlists/{urn}/tracks`
      // (в summary `tracks` приходит пустым — это и был баг «треки не грузятся»).
      final detail = await playlistDetail(urn: urn, limit: 1, offset: 0);
      final page = await playlistTracks(urn: urn, limit: _pageSize, offset: 0);
      return PlaylistTracksState(
        urn: urn,
        summary: detail.summary,
        tracks: page.items,
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
      final page = await playlistTracks(
        urn: current.urn,
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
      // Хвост упал — сохраняем накопленный треклист, снимаем флаг догрузки.
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }

  /// Удалить трек из плейлиста (только владелец). Оптимистично убираем строку,
  /// затем зовём `playlistRemoveTrack`; ядро возвращает канонический срез — им
  /// и заменяем загруженный хвост. Падение — откат к прежнему треклисту.
  Future<void> removeTrack(String trackUrn) async {
    final current = state.value;
    if (current == null || current.urn.isEmpty) return;

    final previous = current.tracks;
    final optimistic = previous.where((t) => t.urn != trackUrn).toList();
    state = AsyncData(current.copyWith(
      tracks: optimistic,
      nextOffset: optimistic.length,
    ));

    try {
      final page = await playlistRemoveTrack(
        playlistUrn: current.urn,
        trackUrn: trackUrn,
      );
      _applyServerPage(page);
    } catch (e) {
      state = AsyncData(current.copyWith(
        tracks: previous,
        nextOffset: previous.length,
      ));
      throw StateError('remove failed: $e');
    }
  }

  /// Переставить треки (только владелец). Локально применяем порядок сразу, а
  /// коммит в ядро дебаунсим — серия перетаскиваний шлёт один `playlistReorder`.
  void reorder(List<String> orderedUrns) {
    final current = state.value;
    if (current == null || current.urn.isEmpty) return;

    final byUrn = {for (final t in current.tracks) t.urn: t};
    final reordered = [
      for (final urn in orderedUrns)
        if (byUrn[urn] != null) byUrn[urn]!,
    ];
    if (reordered.length != current.tracks.length) return;

    state = AsyncData(current.copyWith(tracks: reordered));

    _reorderCommit?.cancel();
    final urn = current.urn;
    _reorderCommit = Timer(_reorderDebounce, () => _commitReorder(urn));
  }

  Future<void> _commitReorder(String urn) async {
    final current = state.value;
    if (current == null || current.urn != urn) return;
    final urns = current.tracks.map((t) => t.urn).toList();
    try {
      final page = await playlistReorder(playlistUrn: urn, trackUrns: urns);
      _applyServerPage(page);
    } catch (_) {
      // Коммит порядка упал — локальный порядок остаётся, следующий тик повторит.
    }
  }

  /// Удалить плейлист целиком (только владелец). Чистит провайдер плейлистов
  /// куратора, чтобы списки/«ещё ящики» обновились. Возврат с экрана — на вызывающем.
  Future<void> delete() async {
    final current = state.value;
    if (current == null || current.urn.isEmpty) return;
    await deletePlaylist(playlistUrn: current.urn);
    ref.invalidate(userPlaylistsProvider);
  }

  /// Заменить загруженный хвост каноническим срезом из ядра (после mutate).
  void _applyServerPage(TrackPageDto page) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(
      tracks: page.items,
      hasMore: page.hasMore,
      nextOffset: page.items.length,
    ));
  }
}
