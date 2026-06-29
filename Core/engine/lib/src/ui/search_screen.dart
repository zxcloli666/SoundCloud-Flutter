import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import '../providers.dart';
import '../rust/api.dart';
import 'search/entity_strip.dart';
import 'search/genre_palette.dart';
import 'search/genre_ticker.dart';
import 'search/resolve_card.dart';
import 'search/search_controls.dart';
import 'search/track_tab.dart';

/// Поиск — «Стена» (Pinterest-мозаика обложек). Страница и ЕСТЬ стена: плотная
/// мозаика квадратов, дебаунс 350ms. При запросе появляется контрольный ряд
/// (Текст|Vibe|Lyrics) и полоска сущностей (артисты/плейлисты/люди) над единой
/// стеной треков. Текстовый режим сплетает лексические, vibe и lyric результаты;
/// vibe/lyrics — отдельные источники. Вставленная SC-ссылка резолвится в
/// карточку (ResolveCard). Жанровая лента сидирует запрос; атмосфера тинтуется по
/// топ-жанрам результата.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _scroll = SmoothScrollController();
  DiveSeed? _dive;
  Timer? _historyDebounce;
  String _lastSaved = '';

  @override
  void dispose() {
    // Уход со страницы поиска — mouse-leave не сработает, гасим сэмпл вручную.
    ref.read(searchPreviewProvider.notifier).stop();
    _historyDebounce?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  /// Сохранить набранный запрос в историю (как легаси: дебаунс, а не только Enter).
  void _scheduleHistory(String q) {
    final t = q.trim();
    _historyDebounce?.cancel();
    if (t.length < 2 || _looksLikeScUrl(t) || t == _lastSaved) return;
    _historyDebounce = Timer(const Duration(milliseconds: 600), () {
      _lastSaved = t;
      ref.read(settingsProvider.notifier).addSearchQuery(t);
    });
  }

  void _seedGenre(String genre) {
    // Лента сидирует запрос: ставим текст в общий стор, уходим в vibe (seedGenre).
    ref.read(searchModeProvider.notifier).set(SearchMode.vibe);
    ref.read(searchQueryProvider.notifier).set(genre);
    ref.read(settingsProvider.notifier).addSearchQuery(genre);
    setState(() => _dive = null);
  }

  // Единый запрос из глобального поля шапки ([searchQueryProvider]); у страницы
  // своего инпута нет (как в легаси: инпут в титлбаре).
  String get _query => ref.read(searchQueryProvider).trim();
  bool get _hasQuery => _query.length >= 2;
  bool get _isScUrl => _looksLikeScUrl(_query);

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(searchModeProvider);
    final source = ref.watch(searchSourceProvider);
    // Набранный из шапки запрос → история (дебаунс) + ребилд страницы.
    ref.listen(searchQueryProvider, (_, q) => _scheduleHistory(q));
    ref.watch(searchQueryProvider);
    final atmosphere = _atmosphereTint(mode, source);
    return Atmosphere(
      tint: atmosphere.tint,
      energy: atmosphere.energy,
      child: Column(
        children: [
          const SizedBox(height: 12),
          if (_isScUrl)
            Expanded(child: _resolvePane())
          else
            ..._searchPane(mode, source),
        ],
      ),
    );
  }

  List<Widget> _searchPane(SearchMode mode, SearchSource source) {
    return [
      if (_hasQuery && _dive == null)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: SearchControls(
            mode: mode,
            onMode: (m) => ref.read(searchModeProvider.notifier).set(m),
            source: source,
            onSource: (s) => ref.read(searchSourceProvider.notifier).set(s),
          ),
        ),
      _ticker(),
      if (_hasQuery && source == SearchSource.db) SearchEntityStrip(query: _query),
      Expanded(
        child: SearchTrackTab(
          query: _query,
          dive: _dive,
          mode: mode,
          source: source,
          scroll: _scroll,
          onPlay: _play,
          onMode: (m) => ref.read(searchModeProvider.notifier).set(m),
          onDive: (track) =>
              setState(() => _dive = DiveSeed(track.urn, track.title)),
        ),
      ),
    ];
  }

  Widget _resolvePane() {
    return Center(
      child: ResolveCard(
        url: _query,
        onOpenTrack: (urn) =>
            ref.read(routerProvider.notifier).push(TrackRoute(urn)),
        onPlay: (track) => _play(track, const []),
      ),
    );
  }

  Widget _ticker() {
    if (_dive != null) return _diveBackPill();
    final accent = ScTheme.paletteOf(context).accent;
    final chips = _tickerChips(accent);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: GenreTicker(chips: chips, onSelect: _seedGenre),
    );
  }

  Widget _diveBackPill() {
    final dive = _dive!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Center(
        child: GestureDetector(
          onTap: () => setState(() => _dive = null),
          child: Container(
            height: 32,
            padding: const EdgeInsets.only(left: 10, right: 16),
            decoration: BoxDecoration(
              color: const Color(0x0DFFFFFF),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0x1AFFFFFF), width: 0.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.arrowLeft,
                    size: 14, color: Color(0xB3FFFFFF)),
                const SizedBox(width: 8),
                Text(
                  ref.tr('search.diveFrom', {'title': dive.title}),
                  style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

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

  ({List<Color> tint, double energy}) _atmosphereTint(
      SearchMode mode, SearchSource source) {
    if (_dive != null || !_hasQuery || _isScUrl || source == SearchSource.sc) {
      return (tint: const [], energy: 0.4);
    }
    final accent = ScTheme.paletteOf(context).accent;
    final tracks = _resultTracks(mode);
    if (tracks == null || tracks.isEmpty) return (tint: const [], energy: 0.4);
    final top = topGenres(tracks.map((t) => t.genre), 4);
    if (top.isEmpty) return (tint: const [], energy: 0.4);
    return (
      tint: top.take(2).map((g) => genreColor(g, accent)).toList(),
      energy: vibeEnergy(top),
    );
  }

  List<TrackDto>? _resultTracks(SearchMode mode) {
    switch (mode) {
      case SearchMode.vibe:
        return ref.watch(searchVibeProvider(_query)).value?.items;
      case SearchMode.lyrics:
        return ref
            .watch(searchLyricsProvider(_query))
            .value
            ?.items
            .map((h) => h.track)
            .toList();
      case SearchMode.text:
        return ref.watch(searchTracksProvider(_query)).value;
    }
  }

  List<GenreChip> _tickerChips(Color accent) {
    final tracks =
        _hasQuery && !_isScUrl ? _resultTracks(ref.watch(searchModeProvider)) : null;
    if (tracks == null) return genres;
    final top = topGenres(tracks.map((t) => t.genre), 16);
    if (top.length < 4) return genres;
    return [
      for (final g in top) GenreChip(key: g, label: g, color: genreColor(g, accent))
    ];
  }
}

/// Распознаёт публичную ссылку SoundCloud (включая короткие `snd.sc`).
bool _looksLikeScUrl(String value) {
  final v = value.trim().toLowerCase();
  if (!v.startsWith('http://') && !v.startsWith('https://')) return false;
  return v.contains('soundcloud.com/') || v.contains('snd.sc/');
}
