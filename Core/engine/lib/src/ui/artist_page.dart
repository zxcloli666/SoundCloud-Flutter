import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import '../providers.dart';
import '../rust/dto.dart';
import 'artist/artist_about_tab.dart';
import 'artist/artist_albums_tab.dart';
import 'artist/artist_aura.dart';
import 'artist/artist_hero.dart';
import 'artist/artist_related_tab.dart';
import 'artist/artist_soundwave.dart';
import 'artist/artist_tracks_tab.dart';
import 'artist/tab_states.dart';

/// Страница артиста (§3.9). Шелл = AuraField (атмосфера-aura) + центрированная
/// колонка `max-w 1480`: геро → саундвейв-блок → TabDock → стеклянная панель с
/// активной вкладкой. Аура — star-`custom_hex` ([artistStarProvider]), иначе
/// акцент вьюера. Навигация — через [routerProvider].
class ArtistPage extends ConsumerStatefulWidget {
  final String id;

  const ArtistPage({super.key, required this.id});

  @override
  ConsumerState<ArtistPage> createState() => _ArtistPageState();
}

class _ArtistPageState extends ConsumerState<ArtistPage> {
  String _tab = 'tracks';
  final _scroll = SmoothScrollController();

  @override
  void initState() {
    super.initState();
    // Подтянуть первую страницу треков артиста (накопительный провайдер).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(artistTracksProvider.notifier).load(widget.id);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(artistDetailProvider(widget.id));
    final aura = _resolveAura(context);
    final hasStar = ref.watch(artistStarProvider(widget.id)).value?.premium ?? false;

    return Atmosphere(
      variant: AtmosphereVariant.aura,
      tint: aura.orbs,
      intense: hasStar,
      child: detail.when(
        loading: () => const _CenteredSpinner(),
        error: (_, __) => const _CenteredError(),
        data: (artist) => _content(artist, aura, hasStar),
      ),
    );
  }

  /// Star → аура из `custom_hex`; иначе акцент вьюера (пресет-аур по id нет).
  ArtistAura _resolveAura(BuildContext context) {
    final star = ref.watch(artistStarProvider(widget.id)).value;
    if (star != null && star.premium) {
      final fromHex = ArtistAura.fromHex(star.customHex);
      if (fromHex != null) return fromHex;
    }
    return ArtistAura.fromAccent(ScTheme.paletteOf(context).accent);
  }

  Widget _content(ArtistDetailDto artist, ArtistAura aura, bool hasStar) {
    final tabs = _tabsFor(artist);
    // Гарантируем валидную активную вкладку (covers/appears могут отсутствовать).
    final activeId = tabs.any((t) => t.id == _tab) ? _tab : 'tracks';

    return LayoutBuilder(
      builder: (context, c) {
        final hPad = c.maxWidth >= 768 ? 32.0 : 16.0;
        final topPad = c.maxWidth >= 768 ? 64.0 : 40.0;
        return SingleChildScrollView(
          controller: _scroll,
          padding: EdgeInsets.fromLTRB(hPad, topPad, hPad, 136),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ArtistHero(
                    artist: artist,
                    hasStar: hasStar,
                    aura: aura,
                    onOpenUser: (urn) => ref.read(routerProvider.notifier).push(UserRoute(urn)),
                  ),
                  const SizedBox(height: 32),
                  ArtistSoundWave(
                    artistId: artist.id,
                    artistName: artist.name,
                    fallbackTracks: artist.popularTracks,
                    aura: aura,
                  ),
                  const SizedBox(height: 40),
                  TabDock(
                    tabs: tabs,
                    activeId: activeId,
                    onChanged: _onTab,
                    aura: aura.primary,
                  ),
                  const SizedBox(height: 32),
                  GlassContentPanel(child: _tabContent(activeId, artist, aura)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _tabContent(String id, ArtistDetailDto artist, ArtistAura aura) {
    switch (id) {
      case 'appears':
        return _appearsTab(artist, aura);
      case 'covers':
        return _coversTab(aura);
      case 'albums':
        return _albumsTab(aura);
      case 'related':
        return ArtistRelatedTab(
          related: artist.relatedArtists,
          aura: aura,
          onOpenArtist: (id) => ref.read(routerProvider.notifier).push(ArtistRoute(id)),
        );
      case 'about':
        return ArtistAboutTab(
          artist: artist,
          aura: aura,
          onOpenUser: (urn) => ref.read(routerProvider.notifier).push(UserRoute(urn)),
        );
      case 'tracks':
      default:
        return _tracksTab(aura);
    }
  }

  Widget _tracksTab(ArtistAura aura) {
    final state = ref.watch(artistTracksProvider);
    return state.when(
      loading: () => const TabLoader(),
      error: (_, __) => const TabEmpty(icon: LucideIcons.music, label: 'Не удалось загрузить треки'),
      data: (s) {
        // Накопительный провайдер шарится между артистами: показываем треки лишь
        // если он держит наш id (иначе ждём load в initState).
        if (s.id != widget.id) return const TabLoader();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ArtistTracksTab(tracks: s.tracks, aura: aura, emptyLabel: 'Нет треков'),
            if (s.hasMore) ...[
              const SizedBox(height: 16),
              _LoadMore(loading: s.loadingMore, onTap: () => ref.read(artistTracksProvider.notifier).more()),
            ],
          ],
        );
      },
    );
  }

  /// «Появляется в» — реальные участия (`role=featured`), а не фильтр популярных.
  Widget _appearsTab(ArtistDetailDto artist, ArtistAura aura) {
    final featured = ref.watch(artistFeaturedProvider(artist.id));
    return featured.when(
      loading: () => const TabLoader(),
      error: (_, __) =>
          const TabEmpty(icon: LucideIcons.music, label: 'Не удалось загрузить участия'),
      data: (tracks) => ArtistTracksTab(
        tracks: tracks,
        aura: aura,
        emptyLabel: 'Нет участий',
        showSort: false,
      ),
    );
  }

  Widget _coversTab(ArtistAura aura) {
    final state = ref.watch(artistCoversProvider);
    return state.when(
      loading: () => const TabLoader(),
      error: (_, __) => const TabEmpty(icon: LucideIcons.disc3, label: 'Не удалось загрузить каверы'),
      data: (s) {
        // Накопительный провайдер шарится между артистами: ждём load для нашего id.
        if (s.id != widget.id) return const TabLoader();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ArtistTracksTab(
              tracks: s.tracks,
              aura: aura,
              emptyLabel: 'Нет каверов',
              showSort: false,
            ),
            if (s.hasMore) ...[
              const SizedBox(height: 16),
              _LoadMore(loading: s.loadingMore, onTap: () => ref.read(artistCoversProvider.notifier).more()),
            ],
          ],
        );
      },
    );
  }

  Widget _albumsTab(ArtistAura aura) {
    final albums = ref.watch(artistAlbumsProvider(widget.id));
    return albums.when(
      loading: () => const TabLoader(),
      error: (_, __) => const TabEmpty(icon: LucideIcons.disc3, label: 'Не удалось загрузить альбомы'),
      data: (list) => ArtistAlbumsTab(
        albums: list,
        aura: aura,
        onOpenAlbum: (id) => ref.read(routerProvider.notifier).push(AlbumRoute(id)),
      ),
    );
  }

  void _onTab(String id) {
    setState(() => _tab = id);
    // Каверы тянем лениво — только при первом открытии вкладки.
    if (id == 'covers') {
      ref.read(artistCoversProvider.notifier).load(widget.id);
    }
  }

  /// Динамические вкладки (легаси): tracks всегда; appears (>0); covers; albums;
  /// related; about.
  List<TabDockItem> _tabsFor(ArtistDetailDto a) {
    final appears = a.popularTracks.where((t) => t.artistId != a.id).length;
    return [
      TabDockItem(id: 'tracks', label: 'Треки', count: a.trackCountPrimary),
      if (a.trackCountFeatured > 0 || appears > 0)
        TabDockItem(id: 'appears', label: 'Участие', count: a.trackCountFeatured),
      const TabDockItem(id: 'covers', label: 'Каверы'),
      TabDockItem(id: 'albums', label: 'Альбомы', count: a.albumCount),
      TabDockItem(id: 'related', label: 'Похожие', count: a.relatedArtists.length),
      const TabDockItem(id: 'about', label: 'О себе'),
    ];
  }
}

class _LoadMore extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;

  const _LoadMore({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GlassButton(
        onTap: loading ? null : onTap,
        child: loading
            ? const SizedBox(
                width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0x8CFFFFFF)))
            : const Text('Показать ещё', style: TextStyle(color: Color(0x8CFFFFFF), fontSize: 13)),
      ),
    );
  }
}

class _CenteredSpinner extends StatelessWidget {
  const _CenteredSpinner();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(strokeWidth: 2.4, color: Color(0x4DFFFFFF)),
      ),
    );
  }
}

class _CenteredError extends StatelessWidget {
  const _CenteredError();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Ошибка загрузки', style: TextStyle(color: Color(0x66FFFFFF), fontSize: 14)),
    );
  }
}
