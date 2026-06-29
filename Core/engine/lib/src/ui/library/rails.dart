import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../providers.dart';
import '../../rust/api.dart';
import '../../rust/dto.dart';
import 'collection_rail.dart';

/// Сборка полок-превью хаба: каждая — срез коллекции с «Показать все».
/// Пустые/загрузочные/ошибочные состояния полки скрыты внутри (полка не падает
/// и не оставляет дыру). Тайлы строятся лениво из уже загруженной первой страницы.
class LibraryRails {
  final WidgetRef ref;

  const LibraryRails(this.ref);

  /// Превью полка из одного `PagedNotifier`. На загрузке — скелет; пусто/ошибка —
  /// ничего.
  Widget section<T>({
    required IconData icon,
    required String title,
    int? count,
    required LibraryCollectionKind kind,
    required AsyncValue<PagedList<T>> state,
    required List<Widget> Function(PagedList<T> page) tiles,
  }) {
    return state.when(
      loading: () => RailSkeleton(icon: icon, title: title),
      error: (_, __) => const SizedBox.shrink(),
      data: (page) {
        if (page.items.isEmpty) return const SizedBox.shrink();
        return CollectionRail(
          icon: icon,
          title: title,
          count: count,
          onSeeAll: () =>
              ref.read(routerProvider.notifier).push(LibraryCollectionRoute(kind)),
          items: tiles(page),
        );
      },
    );
  }

  /// Полка без deep-page «Показать все»: для коллекций, у которых нет своей
  /// страницы [LibraryCollectionRoute] (подписки, свежак). Опц. [count] в
  /// заголовке. Скрывается на загрузке/пусто/ошибке так же, как [section].
  Widget customSection<T>({
    required IconData icon,
    required String title,
    int? count,
    required AsyncValue<PagedList<T>> state,
    required List<Widget> Function(PagedList<T> page) tiles,
  }) {
    return state.when(
      loading: () => RailSkeleton(icon: icon, title: title),
      error: (_, __) => const SizedBox.shrink(),
      data: (page) {
        if (page.items.isEmpty) return const SizedBox.shrink();
        return CollectionRail(
          icon: icon,
          title: title,
          count: count,
          items: tiles(page),
        );
      },
    );
  }

  List<Widget> playlistTiles(List<PlaylistSummaryDto> items) {
    final router = ref.read(routerProvider.notifier);
    return [
      for (final p in items.take(12))
        SizedBox(
          width: 160,
          child: PlaylistCard(
            data: PlaylistCardData(
              title: p.title,
              artworkUrl: p.artworkUrl,
              trackCount: p.trackCount,
              uploader: p.ownerUsername,
              typeLabel: p.isAlbum ? 'АЛЬБОМ' : 'ПЛЕЙЛИСТ',
            ),
            onTap: () => router.push(p.isAlbum ? AlbumRoute(p.urn) : PlaylistRoute(p.urn)),
          ),
        ),
    ];
  }

  /// Круглые тайлы артистов из подписок. Тап ведёт на страницу пользователя;
  /// под именем — счётчик подписчиков (легаси `ArtistMiniCard`).
  List<Widget> artistTiles(List<UserDto> items) {
    final router = ref.read(routerProvider.notifier);
    return [
      for (final u in items.take(14))
        ArtistTile(
          data: ArtistTileData(
            username: u.username,
            avatarUrl: u.avatarUrl,
            followersLabel: u.followersCount == null
                ? null
                : formatCount(u.followersCount!.toInt()),
          ),
          onTap: () => router.push(UserRoute(u.urn)),
        ),
    ];
  }

  /// Тайлы треков. [queue] — контекст очереди для воспроизведения (легаси: play
  /// получает весь срез как очередь). Без [queue] трек играет одиночкой.
  List<Widget> trackTiles(List<TrackDto> items, {List<TrackDto>? queue}) {
    final playing = ref.watch(playerProvider)?.urn;
    return [
      for (final t in items.take(12))
        SizedBox(
          width: 150,
          child: TrackCardTile(
            width: 150,
            playing: playing == t.urn,
            data: TrackCardTileData(
              title: t.title,
              artistLine: t.artistName,
              artworkUrl: t.artworkUrl,
              durationMs: t.durationMs.toInt(),
              playbackCount: t.playCount?.toInt(),
              liked: t.userFavorite ?? true,
              meta: TrackStatusMeta(
                storageState: t.storageState,
                storageQuality: t.storageQuality,
                indexState: t.indexState,
              ),
            ),
            onPlay: () => _play(t, queue: queue),
          ),
        ),
    ];
  }

  /// История как тайлы: дедуп по треку, до 14 штук. Тап резолвит urn лениво
  /// (`trackProvider`) и играет — карточки сами не тянут полный трек.
  List<Widget> historyTiles(List<HistoryEntryDto> items) {
    final seen = <String>{};
    final preview = <HistoryEntryDto>[];
    for (final e in items) {
      if (!seen.add(e.scTrackId)) continue;
      preview.add(e);
      if (preview.length >= 14) break;
    }
    return [
      for (final e in preview)
        SizedBox(
          width: 150,
          child: TrackCardTile(
            width: 150,
            data: TrackCardTileData(
              title: e.title,
              artistLine: e.artistName,
              artworkUrl: e.artworkUrl,
              durationMs: e.durationMs.toInt(),
            ),
            onPlay: () => _playUrn(_historyUrn(e.scTrackId)),
          ),
        ),
    ];
  }

  /// История несёт голый числовой id; плееру/кэшу нужен полный URN
  /// (из него выводится канон `soundcloud_tracks_<id>.m4a`).
  String _historyUrn(String scTrackId) => scTrackId.startsWith('soundcloud:tracks:')
      ? scTrackId
      : 'soundcloud:tracks:$scTrackId';

  Future<void> _playUrn(String urn) async {
    final track = await ref.read(trackProvider(urn).future);
    if (track != null) await _play(track);
  }

  Future<void> _play(TrackDto track, {List<TrackDto>? queue}) async {
    try {
      await ref.read(playerProvider.notifier).play(track, queue: queue);
    } catch (_) {
      // Ошибку показывает NowBar/тост на уровне оболочки.
    }
  }
}

/// Скелет полки на время загрузки коллекции.
class RailSkeleton extends StatelessWidget {
  final IconData icon;
  final String title;

  const RailSkeleton({super.key, required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              Icon(icon, size: 16, color: const Color(0x8CFFFFFF)),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xE6FFFFFF),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 5,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (_, __) => const SizedBox(
              width: 150,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton(width: 150, height: 150, rounded: SkeletonRound.lg),
                  SizedBox(height: 10),
                  Skeleton(width: 120, height: 12, rounded: SkeletonRound.sm),
                  SizedBox(height: 6),
                  Skeleton(width: 80, height: 10, rounded: SkeletonRound.sm),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
