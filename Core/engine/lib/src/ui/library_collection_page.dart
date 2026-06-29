import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import '../providers.dart';
import '../rust/dto.dart';
import 'library_collection/history_tab.dart';
import 'library_collection/library_sub_header.dart';
import 'library_collection/likes_tab.dart';
import 'library_collection/playlists_tab.dart';

/// Глубокий раздел библиотеки (`/library/:section`, легаси `LibraryCollection`):
/// полный фильтруемый виртуализированный список одного вида коллекции. Кадр —
/// атмосфера + единственный страничный `CustomScrollView` (виртуализация —
/// сливерами внутри, без вложенных скроллов), шапка с возвратом в хаб, тело по виду.
class LibraryCollectionPage extends ConsumerStatefulWidget {
  final LibraryCollectionKind kind;

  const LibraryCollectionPage({super.key, required this.kind});

  @override
  ConsumerState<LibraryCollectionPage> createState() =>
      _LibraryCollectionPageState();
}

class _LibraryCollectionPageState extends ConsumerState<LibraryCollectionPage> {
  String _filter = '';
  final _scroll = SmoothScrollController();

  bool get _isHistory => widget.kind == LibraryCollectionKind.history;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(meProvider).value;
    return Atmosphere(
      child: CustomScrollView(
        controller: _scroll,
        slivers: [
          _centered(
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 20),
                child: LibrarySubHeader(
                  title: _title,
                  backLabel: 'Библиотека',
                  onBack: () => ref
                      .read(routerProvider.notifier)
                      .selectTab(const LibraryRoute()),
                  count: _count(me),
                  filter: _isHistory ? null : _filter,
                  filterHint: 'Фильтр',
                  onFilter:
                      _isHistory ? null : (v) => setState(() => _filter = v),
                ),
              ),
            ),
          ),
          for (final sliver in _bodySlivers(context)) _centered(sliver),
          const SliverToBoxAdapter(child: SizedBox(height: 136)),
        ],
      ),
    );
  }

  List<Widget> _bodySlivers(BuildContext context) => switch (widget.kind) {
        LibraryCollectionKind.likedTracks => likesTabSlivers(
            context,
            ref,
            filter: _filter,
            emptyMessage: 'Нет лайкнутых треков',
            noMatchesMessage: 'Ничего не найдено',
          ),
        LibraryCollectionKind.likedPlaylists => playlistsTabSlivers(
            ref,
            collection: PlaylistCollection.liked,
            filter: _filter,
            emptyMessage: 'Нет плейлистов',
            noMatchesMessage: 'Ничего не найдено',
          ),
        LibraryCollectionKind.myPlaylists => playlistsTabSlivers(
            ref,
            collection: PlaylistCollection.mine,
            filter: _filter,
            emptyMessage: 'Нет плейлистов',
            noMatchesMessage: 'Ничего не найдено',
          ),
        LibraryCollectionKind.history => historyTabSlivers(
            context,
            ref,
            emptyMessage: 'История пуста',
            labels: const HistoryLabels(
              today: 'Сегодня',
              yesterday: 'Вчера',
              earlier: 'Ранее',
              clear: 'Очистить историю',
            ),
          ),
      };

  /// Центрирует сливер в колонку `max-w 1320 px-4 md:px-8` (легаси `LibraryFrame`).
  SliverPadding _centered(Widget sliver) {
    final width = MediaQuery.sizeOf(context).width;
    final gutter = width >= 768 ? 32.0 : 16.0;
    final overflow = ((width - 1320) / 2).clamp(0.0, double.infinity);
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: overflow + gutter),
      sliver: sliver,
    );
  }

  String get _title => switch (widget.kind) {
        LibraryCollectionKind.likedTracks => 'Лайкнутые треки',
        LibraryCollectionKind.likedPlaylists => 'Лайкнутые плейлисты',
        LibraryCollectionKind.myPlaylists => 'Мои плейлисты',
        LibraryCollectionKind.history => 'История',
      };

  int? _count(MeDto? me) {
    if (me == null) return null;
    return switch (widget.kind) {
      LibraryCollectionKind.likedTracks => me.publicFavoritesCount?.toInt(),
      LibraryCollectionKind.myPlaylists => me.playlistCount?.toInt(),
      LibraryCollectionKind.likedPlaylists => null,
      LibraryCollectionKind.history => null,
    };
  }
}
