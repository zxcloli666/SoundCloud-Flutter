import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import '../providers.dart';
import '../rust/api.dart';
import 'library/rails.dart';
import 'library/soundprint_masthead.dart';

/// Библиотека — «Хаб». Личная домашняя база: твой Sound Print сверху, свежак от
/// подписок, затем полки в глубокие страницы коллекции. Полки коллекций несут
/// «Показать все» в свою страницу `LibraryCollectionRoute`; полки подписок и
/// свежака — без deep-page (бэкенд отдаёт ленту, но отдельной страницы нет).
///
/// За гейтом юзер всегда авторизован — своего logged-out состояния у страницы нет.
/// Жанровый soundprint (spectrum-бары вкуса) требует данных, которых бэкенд пока
/// не отдаёт — его нет.
class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Atmosphere(child: _LibraryHub());
  }
}

/// Содержимое хаба: один скролл-вью на страницу (NowBar парит поверх), мастхед
/// и полки вертикально с зазором 36.
class _LibraryHub extends ConsumerStatefulWidget {
  const _LibraryHub();

  @override
  ConsumerState<_LibraryHub> createState() => _LibraryHubState();
}

class _LibraryHubState extends ConsumerState<_LibraryHub> {
  final _scroll = SmoothScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(meProvider).value;
    final liked = ref.watch(likedTracksProvider);
    final likedPlaylists = ref.watch(likedPlaylistsProvider);
    final myPlaylists = ref.watch(myPlaylistsProvider);
    final history = ref.watch(historyProvider);
    final followings = ref.watch(meFollowingsProvider);
    final freshDrops = ref.watch(meFollowingsTracksProvider);
    final rails = LibraryRails(ref);

    final likedTracks = liked.value?.items ?? const <TrackDto>[];

    final shelves = <Widget>[
      // «Свежак» — новые треки тех, на кого подписан (легаси FreshDrops).
      rails.customSection(
        icon: LucideIcons.sparkles,
        title: 'Свежее от подписок',
        state: freshDrops,
        tiles: (page) => rails.trackTiles(page.items, queue: page.items),
      ),
      // «Продолжить» — недавно слушанное (легаси ContinueRow).
      rails.section(
        icon: LucideIcons.history,
        title: 'Продолжить',
        kind: LibraryCollectionKind.history,
        state: history,
        tiles: (page) => rails.historyTiles(page.items),
      ),
      rails.section(
        icon: LucideIcons.listMusic,
        title: 'Твои плейлисты',
        count: me?.playlistCount?.toInt(),
        kind: LibraryCollectionKind.myPlaylists,
        state: myPlaylists,
        tiles: (page) => rails.playlistTiles(page.items),
      ),
      rails.section(
        icon: Icons.bookmark_rounded,
        title: 'Сохранённые плейлисты',
        kind: LibraryCollectionKind.likedPlaylists,
        state: likedPlaylists,
        tiles: (page) => rails.playlistTiles(page.items),
      ),
      // «Артисты» — подписки (легаси ArtistMiniCard rail). Без deep-page.
      rails.customSection(
        icon: LucideIcons.users,
        title: 'Артисты',
        count: me?.followingsCount?.toInt(),
        state: followings,
        tiles: (page) => rails.artistTiles(page.items),
      ),
      rails.section(
        icon: Icons.favorite_rounded,
        title: 'Любимые треки',
        count: me?.publicFavoritesCount?.toInt(),
        kind: LibraryCollectionKind.likedTracks,
        state: liked,
        tiles: (page) => rails.trackTiles(page.items, queue: page.items),
      ),
    ];

    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 136),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1320),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SoundPrintMasthead(
                  username: me?.username ?? '...',
                  avatarUrl: me?.avatarUrl,
                  likedCovers:
                      likedTracks.map((t) => t.artworkUrl).toList(growable: false),
                  shuffleEnabled: likedTracks.isNotEmpty,
                  onShuffle:
                      likedTracks.isEmpty ? null : () => _shuffle(ref, likedTracks),
                ),
                const SizedBox(height: 36),
                for (final shelf in shelves) ...[
                  shelf,
                  const SizedBox(height: 36),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Перемешать лайки: случайный старт, очередь — весь срез лайков (легаси:
  /// play получает `queue: likedTracks`, дальше доигрывает очередь).
  Future<void> _shuffle(WidgetRef ref, List<TrackDto> tracks) async {
    if (tracks.isEmpty) return;
    final pick = tracks[math.Random().nextInt(tracks.length)];
    try {
      await ref.read(playerProvider.notifier).play(pick, queue: tracks);
    } catch (_) {
      // Ошибку покажет NowBar/тост оболочки.
    }
  }
}
