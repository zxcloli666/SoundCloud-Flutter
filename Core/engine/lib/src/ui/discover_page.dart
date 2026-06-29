import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import '../providers.dart';
import '../rust/api.dart';
import 'discover/albums_catalog.dart';
import 'discover/artists_catalog.dart';
import 'discover/discover_hero.dart';
import 'discover/discover_prism.dart';
import 'discover/discover_search_input.dart';
import 'discover/discover_spotlight.dart';
import 'discover/featured_hero.dart';
import 'discover/sliver_backdrop_filter.dart';

/// Discover — «Открывай новое» (легаси §3.3). Вертикальный стек: геро со
/// счётчиками и «Удиви меня» → FeaturedHero → DiscoverPrism → таб-каталог
/// (Альбомы | Артисты) с фильтрами, поиском и сидированной пере-тасовкой.
/// Атмосфера — AuraField (isStar=false). Догрузка каталога — по близости скролла
/// к низу (600px-сентинел), а не безусловно.
class DiscoverPage extends ConsumerStatefulWidget {
  const DiscoverPage({super.key});

  @override
  ConsumerState<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends ConsumerState<DiscoverPage> {
  final _scroll = SmoothScrollController();
  String _tab = 'albums';
  String _query = '';
  String? _prismTag;
  bool _surprising = false;

  // Год-бакеты включены, когда альбомы в режиме «recent» без поиска (§3.3).
  // Тогда страница не дёргает курсорную догрузку плоского каталога.
  String _albumSort = 'recent';
  bool get _albumYearBuckets => _albumSort == 'recent' && _query.isEmpty;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Догрузка следующей страницы активного каталога при подходе к низу (легаси
  /// `InfiniteSentinel` rootMargin 600px). Курсор/капа решает сам нотифаер;
  /// здесь — только триггер по близости скролла. В режиме год-бакетов альбомы
  /// не курсорятся (отдельный непагинируемый эндпоинт).
  bool _onScroll(ScrollNotification n) {
    if (n.metrics.pixels < n.metrics.maxScrollExtent - 600) return false;
    if (_tab == 'albums') {
      if (_albumYearBuckets) return false;
      final paged = ref.read(discoverAlbumsProvider).value;
      if (paged != null && paged.hasMore && !paged.loadingMore) {
        ref.read(discoverAlbumsProvider.notifier).loadMore();
      }
    } else {
      final paged = ref.read(discoverArtistsProvider).value;
      if (paged != null && paged.hasMore && !paged.loadingMore) {
        ref.read(discoverArtistsProvider.notifier).loadMore();
      }
    }
    return false;
  }

  /// «Удиви меня» — серверный случайный id каталога (`discover/random?type=`)
  /// активного таба → переход на его роут (легаси §3.3).
  Future<void> _surpriseMe() async {
    if (_surprising) return;
    setState(() => _surprising = true);
    try {
      final router = ref.read(routerProvider.notifier);
      final kind = _tab == 'albums' ? 'album' : 'artist';
      // Свежий бросок на каждое нажатие (иначе family отдаёт закэшенный id).
      ref.invalidate(discoverRandomProvider(kind));
      final id = await ref.read(discoverRandomProvider(kind).future);
      if (id == null || id.isEmpty) return;
      router.push(_tab == 'albums' ? AlbumRoute(id) : ArtistRoute(id));
    } finally {
      if (mounted) setState(() => _surprising = false);
    }
  }

  /// Тап по полосе призмы — переход на каталог артистов с выбранным жанром.
  void _onPrismTag(String? tag) {
    setState(() {
      _prismTag = tag;
      if (tag != null) _tab = 'artists';
    });
  }

  /// Воспроизвести трек из мозаики призмы в очереди стены.
  Future<void> _play(TrackDto track, List<TrackDto> queue) async {
    final messenger = ToastScope.of(context);
    try {
      await ref.read(playerProvider.notifier).play(
            track,
            queue: queue.isEmpty ? null : queue,
          );
    } catch (error) {
      messenger.show('Не удалось воспроизвести: $error', kind: ToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(discoverSummaryProvider);
    final counts = summary.maybeWhen(data: (s) => s, orElse: () => null);

    final tabs = [
      TabDockItem(
          id: 'albums', label: 'Альбомы', count: counts?.albumsCount.toInt()),
      TabDockItem(
          id: 'artists', label: 'Артисты', count: counts?.artistsCount.toInt()),
    ];

    return Atmosphere(
      variant: AtmosphereVariant.aura,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: CustomScrollView(
          controller: _scroll,
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            _centered(
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 56, bottom: 40),
                  child: DiscoverHero(
                    artistsCount: counts?.artistsCount.toInt(),
                    albumsCount: counts?.albumsCount.toInt(),
                    freshCount: counts?.freshCount.toInt(),
                    isLoading: summary.isLoading,
                    isSurprising: _surprising,
                    onSurpriseMe: _surpriseMe,
                  ),
                ),
              ),
            ),
            _centered(
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 40),
                  child: FeaturedHero(),
                ),
              ),
            ),
            _centered(
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 40),
                  child: DiscoverSpotlight(),
                ),
              ),
            ),
            _centered(
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: DiscoverPrism(
                    activeTag: _prismTag,
                    onTagSelected: _onPrismTag,
                    onPlay: _play,
                  ),
                ),
              ),
            ),
            _centered(
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: _controls(tabs),
                ),
              ),
            ),
            _centered(_catalogPanel()),
            const SliverToBoxAdapter(child: SizedBox(height: 136)),
          ],
        ),
      ),
    );
  }

  Widget _controls(List<TabDockItem> tabs) {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children: [
          TabDock(
            tabs: tabs,
            activeId: _tab,
            onChanged: (id) => setState(() => _tab = id),
          ),
          DiscoverSearchInput(
            onChanged: (q) {
              if (q != _query) setState(() => _query = q);
            },
          ),
        ],
      ),
    );
  }

  /// Панель-обёртка каталога (легаси §3.3): `rounded-[2rem] p-3/6`, frosted-стекло
  /// `blur(28) saturate(160%)` + subtle white-градиент поверх атмосферы. Блюр —
  /// через [SliverBackdropFilter] (у Flutter нет box-`BackdropFilter` для сливера),
  /// клипуется в rrect; drop-тень — снаружи блюр-клипа.
  Widget _catalogPanel() {
    final wide = MediaQuery.sizeOf(context).width >= 768;
    final blur = PerfProfile.of(context).blur(28);
    final radius = BorderRadius.circular(32);

    final catalog = _tab == 'albums'
        ? AlbumsCatalog(
            query: _query,
            onSortChanged: (s) {
              if (s != _albumSort) setState(() => _albumSort = s);
            },
          )
        : ArtistsCatalog(query: _query, tag: _prismTag);

    Widget panel = DecoratedSliver(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: blur > 0
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x09FFFFFF), Color(0x04FFFFFF)],
              )
            : null,
        color: blur > 0 ? null : const Color(0xD9121216),
        border: Border.all(color: const Color(0x0FFFFFFF), width: 0.5),
      ),
      sliver: SliverPadding(
        padding: EdgeInsets.all(wide ? 24 : 12),
        sliver: catalog,
      ),
    );

    if (blur > 0) {
      panel = SliverBackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        borderRadius: radius,
        sliver: panel,
      );
    }

    // Drop-тень рисуем СНАРУЖИ блюр-клипа (иначе её срежет rrect-клип блюра).
    return DecoratedSliver(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: const [
          BoxShadow(
              color: Color(0x4D000000), blurRadius: 80, offset: Offset(0, 30)),
        ],
      ),
      sliver: panel,
    );
  }

  /// Центрирует сливер в колонку `max-w 1480 px-4 md:px-8`.
  SliverPadding _centered(Widget sliver) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 768;
    final gutter = wide ? 32.0 : 16.0;
    final overflow = ((width - 1480) / 2).clamp(0.0, double.infinity);
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: overflow + gutter),
      sliver: sliver,
    );
  }
}
