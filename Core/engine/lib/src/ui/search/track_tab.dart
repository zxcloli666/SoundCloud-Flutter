import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../providers.dart';
import '../../rust/api.dart';
import '../../rust/dto_social.dart';
import 'track_wall.dart';

/// Затравка норы (rabbit-hole) — трек, от которого пляшут похожие.
class DiveSeed {
  final String urn;
  final String title;
  const DiveSeed(this.urn, this.title);
}

/// Стена поиска: лента (без запроса) / нора (dive) / результаты запроса. Источник
/// стены переключается режимом: text→лексический поиск (с вплетёнными vibe+lyric),
/// vibe→вектор-похожесть (каждая плитка с Sparkles-гало), lyrics→full-text по
/// тексту песен (serif-цитата). Геро-правила различаются: append-only (позиция)
/// для ленты/норы/vibe, woven (urn) для лексического запроса.
class SearchTrackTab extends ConsumerWidget {
  final String query;
  final DiveSeed? dive;
  final SearchMode mode;
  final SearchSource source;
  final ScrollController scroll;
  final void Function(TrackDto track, List<TrackDto> queue) onPlay;
  final void Function(TrackDto) onDive;
  final void Function(SearchMode) onMode;

  const SearchTrackTab({
    super.key,
    required this.query,
    required this.dive,
    required this.mode,
    required this.source,
    required this.scroll,
    required this.onPlay,
    required this.onDive,
    required this.onMode,
  });

  bool get _hasQuery => query.length >= 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (dive != null) return _diveWall(ref);
    if (!_hasQuery) return _landingWall(ref);
    if (source == SearchSource.sc) return _scWall(ref);
    switch (mode) {
      case SearchMode.vibe:
        return _vibeWall(ref);
      case SearchMode.lyrics:
        return _lyricsWall(ref);
      case SearchMode.text:
        return _textWall(ref);
    }
  }

  /// Живой поиск в SoundCloud (источник «SC»): лексические треки прямо из SC.
  Widget _scWall(WidgetRef ref) {
    final async = ref.watch(searchScTracksProvider(query));
    return async.when(
      data: (tracks) {
        if (tracks.isEmpty) return _scEmpty(ref);
        return _resolvedWall(
          tracks,
          variant: CoverTileVariant.normal,
          heroByPos: true,
        );
      },
      loading: () => _loadingWall(),
      error: (e, _) => _errorWall(ref, e),
    );
  }

  /// Лента (река) — append-only, плитки резолвятся лениво по urn. Очередь не
  /// собираем: плеер продолжает из бесконечной волны сам.
  Widget _landingWall(WidgetRef ref) {
    final async = ref.watch(waveProvider);
    return async.when(
      data: (state) {
        final items = [
          for (var i = 0; i < state.items.length; i++)
            WallItem.lazy(
              'soundcloud:tracks:${state.items[i].id}',
              hero: isHeroPos(i),
            ),
        ];
        if (items.isEmpty) return _landingEmpty(ref);
        return TrackWall(
          items: items,
          loading: false,
          hasMore: state.hasMore,
          loadingMore: state.loadingMore,
          onLoadMore: () => ref.read(waveProvider.notifier).next(),
          onPlay: onPlay,
          onDive: onDive,
          controller: scroll,
        );
      },
      loading: () => _loadingWall(),
      error: (e, _) => EmptyState(
        icon: const Icon(LucideIcons.cloudOff),
        title: ref.tr('search.feedError'),
        body: '$e',
      ),
    );
  }

  /// Нора (rabbit-hole) — похожие на трек, append-only.
  Widget _diveWall(WidgetRef ref) {
    final async = ref.watch(trackRelatedProvider(dive!.urn));
    return async.when(
      data: (tracks) {
        if (tracks.isEmpty) {
          return EmptyState(
            icon: const Icon(LucideIcons.compass),
            title: ref.tr('search.diveEmpty', {'title': dive!.title}),
            body: ref.tr('search.diveEmptyBody'),
          );
        }
        return _resolvedWall(
          tracks,
          variant: CoverTileVariant.vibe,
          heroByPos: true,
        );
      },
      loading: () => _loadingWall(),
      error: (e, _) => _errorWall(ref, e),
    );
  }

  /// Vibe-режим: вектор-похожесть. Каждая плитка несёт Sparkles-гало; геро по
  /// позиции (append-only, без пагинации).
  Widget _vibeWall(WidgetRef ref) {
    final async = ref.watch(searchVibeProvider(query));
    return async.when(
      data: (page) {
        if (page.items.isEmpty) {
          // Вектор ещё кодируется (новый запрос) — не «ничего не нашлось».
          return page.preparing ? _preparingEmpty(ref) : _vibeEmpty(ref);
        }
        return _resolvedWall(
          page.items,
          variant: CoverTileVariant.vibe,
          heroByPos: true,
        );
      },
      loading: () => _loadingWall(),
      error: (e, _) => _errorWall(ref, e),
    );
  }

  /// Lyrics-режим: full-text по тексту песен. Геро по позиции; lyric-вариант
  /// (serif-цитата) у плиток с совпавшей строкой.
  Widget _lyricsWall(WidgetRef ref) {
    final async = ref.watch(searchLyricsProvider(query));
    return async.when(
      data: (page) {
        if (page.items.isEmpty) return _lyricsEmpty(ref);
        final hits = page.items;
        return TrackWall(
          items: [
            for (var i = 0; i < hits.length; i++)
              WallItem.resolved(
                hits[i].track,
                hero: isHeroPos(i),
                variant: CoverTileVariant.lyric,
                lyricLine: hits[i].matchedLine,
              ),
          ],
          loading: false,
          onPlay: onPlay,
          onDive: onDive,
          controller: scroll,
        );
      },
      loading: () => _loadingWall(),
      error: (e, _) => _errorWall(ref, e),
    );
  }

  /// Текстовый режим: лексический поиск, сплетённый с vibe и lyric результатами.
  /// Геро по urn (woven). Легаси `weaveText`: на слот — lyric если есть &
  /// `slot%4===2`; иначе vibe если есть & `slot%7===5`; иначе следующий
  /// лексический; хвосты добивают; дедуп по urn.
  Widget _textWall(WidgetRef ref) {
    final lexical = ref.watch(searchTracksProvider(query));
    return lexical.when(
      data: (tracks) {
        if (tracks.isEmpty) return _textEmpty(ref);
        final vibe = ref.watch(searchVibeProvider(query)).value?.items ?? const [];
        final lyricHits =
            ref.watch(searchLyricsProvider(query)).value?.items ?? const <LyricHitDto>[];
        final lyricTracks = [for (final h in lyricHits) h.track];
        final lyricLines = {for (final h in lyricHits) h.track.urn: h.matchedLine};
        final woven = _weaveText(tracks, vibe, lyricTracks, lyricLines);
        if (woven.isEmpty) return _textEmpty(ref);
        return TrackWall(
          items: woven,
          loading: false,
          onPlay: onPlay,
          onDive: onDive,
          controller: scroll,
        );
      },
      loading: () => _loadingWall(),
      error: (e, _) => _errorWall(ref, e),
    );
  }

  /// Простая стена из резолвнутых треков (нора/vibe): геро по позиции или urn.
  Widget _resolvedWall(
    List<TrackDto> tracks, {
    required CoverTileVariant variant,
    required bool heroByPos,
  }) {
    return TrackWall(
      items: [
        for (var i = 0; i < tracks.length; i++)
          WallItem.resolved(
            tracks[i],
            hero: heroByPos ? isHeroPos(i) : isHeroUrn(tracks[i].urn),
            variant: variant,
          ),
      ],
      loading: false,
      onPlay: onPlay,
      onDive: onDive,
      controller: scroll,
    );
  }

  List<WallItem> _weaveText(
    List<TrackDto> lexical,
    List<TrackDto> vibe,
    List<TrackDto> lyric,
    Map<String, String?> lyricLines,
  ) {
    final seen = <String>{};
    final out = <WallItem>[];
    final cursor = {lexical: 0, vibe: 0, lyric: 0};

    // Следующий ещё не виденный трек из источника (двигает курсор за границу).
    TrackDto? pull(List<TrackDto> src) {
      var i = cursor[src]!;
      while (i < src.length && !seen.add(src[i].urn)) {
        i++;
      }
      if (i >= src.length) {
        cursor[src] = i;
        return null;
      }
      cursor[src] = i + 1;
      return src[i];
    }

    void emit(TrackDto t, CoverTileVariant variant) => out.add(WallItem.resolved(
          t,
          hero: isHeroUrn(t.urn),
          variant: variant,
          lyricLine:
              variant == CoverTileVariant.lyric ? lyricLines[t.urn] : null,
        ));

    final total = lexical.length + vibe.length + lyric.length;
    for (var slot = 0; out.length < total; slot++) {
      if (slot % 4 == 2) {
        final t = pull(lyric);
        if (t != null) {
          emit(t, CoverTileVariant.lyric);
          continue;
        }
      }
      if (slot % 7 == 5) {
        final t = pull(vibe);
        if (t != null) {
          emit(t, CoverTileVariant.vibe);
          continue;
        }
      }
      final lex = pull(lexical);
      if (lex != null) {
        emit(lex, CoverTileVariant.normal);
        continue;
      }
      // Лексические кончились — добиваем хвостами (vibe, затем lyric).
      final v = pull(vibe);
      if (v != null) {
        emit(v, CoverTileVariant.vibe);
        continue;
      }
      final y = pull(lyric);
      if (y != null) {
        emit(y, CoverTileVariant.lyric);
        continue;
      }
      break;
    }
    return out;
  }

  Widget _errorWall(WidgetRef ref, Object e) => EmptyState(
        icon: const Icon(LucideIcons.circleAlert),
        title: ref.tr('search.errorTitle'),
        body: '$e',
      );

  /// Текст ничего не дал → зови в Vibe (легаси `empty.toVibe*`, скрин «По словам ничего»).
  Widget _textEmpty(WidgetRef ref) => EmptyState(
        icon: const Icon(LucideIcons.sparkles),
        title: ref.tr('search.empty.toVibeTitle'),
        body: ref.tr('search.empty.toVibeBody', {'query': query}),
        cta: ref.tr('search.empty.toVibeCta'),
        ctaIcon: const Icon(LucideIcons.sparkles, size: 15),
        onAction: () => onMode(SearchMode.vibe),
      );

  /// Vibe пусто → зови в текст (легаси `empty.toText*`).
  Widget _vibeEmpty(WidgetRef ref) => EmptyState(
        icon: const Icon(Icons.title_rounded),
        title: ref.tr('search.empty.toTextTitle'),
        body: ref.tr('search.empty.toTextBody', {'query': query}),
        cta: ref.tr('search.empty.toTextCta'),
        ctaIcon: const Icon(Icons.title_rounded, size: 15),
        onAction: () => onMode(SearchMode.text),
      );

  Widget _lyricsEmpty(WidgetRef ref) => EmptyState(
        icon: const Icon(Icons.format_quote_rounded),
        title: ref.tr('search.empty.lyricsTitle'),
        body: ref.tr('search.empty.lyricsBody', {'query': query}),
        cta: ref.tr('search.empty.toTextCta'),
        ctaIcon: const Icon(Icons.title_rounded, size: 15),
        onAction: () => onMode(SearchMode.text),
      );

  /// Вектор vibe ещё кодируется (скрин «Ловим твой вайб…»).
  Widget _preparingEmpty(WidgetRef ref) => EmptyState(
        icon: const Icon(LucideIcons.sparkles),
        title: ref.tr('search.preparingTitle'),
        body: ref.tr('search.preparingBody'),
      );

  /// Живой SC ничего не нашёл (скрин «Ничего не найдено»).
  Widget _scEmpty(WidgetRef ref) => EmptyState(
        icon: const Icon(LucideIcons.cloud),
        title: ref.tr('search.empty.scTitle'),
        body: ref.tr('search.empty.scBody', {'query': query}),
      );

  Widget _loadingWall() => TrackWall(
        items: const [],
        loading: true,
        onPlay: onPlay,
        controller: scroll,
      );

  Widget _landingEmpty(WidgetRef ref) => EmptyState(
        icon: const Icon(LucideIcons.sparkles),
        title: ref.tr('search.landingEmptyTitle'),
        body: ref.tr('search.landingEmptyBody'),
      );
}
