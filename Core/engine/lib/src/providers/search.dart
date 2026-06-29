import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../rust/api.dart';
import '../rust/data.dart';
import '../rust/data_social.dart';
import '../rust/dto.dart';
import '../rust/dto_social.dart';

/// Как интерпретировать запрос: лексический текст, vibe (вектор-похожесть) или
/// поиск по тексту песен (lyrics). Страница выбирает провайдер результатов по
/// текущему режиму.
enum SearchMode { text, vibe, lyrics }

/// Текущий режим поиска. Меняется контрольным рядом страницы.
final searchModeProvider = NotifierProvider<SearchModeNotifier, SearchMode>(
  SearchModeNotifier.new,
);

class SearchModeNotifier extends Notifier<SearchMode> {
  @override
  SearchMode build() => SearchMode.text;

  void set(SearchMode mode) => state = mode;
}

/// Единый на всё приложение поисковый запрос (легаси `searchQueryStore`): пишет
/// глобальное поле в шапке, читает страница поиска — один источник истины.
final searchQueryProvider =
    NotifierProvider<SearchQueryNotifier, String>(SearchQueryNotifier.new);

class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String q) => state = q;
}

const _searchPageSize = 30;

/// Постраничный поиск треков по запросу. `.family` по строке запроса; пустой
/// запрос — пустой результат без обращения к ядру.
final searchTracksProvider = FutureProvider.autoDispose
    .family<List<TrackDto>, String>((ref, query) async {
  final q = query.trim();
  if (q.isEmpty) return const [];
  return search(query: q, limit: _searchPageSize, offset: 0);
});

/// Поиск артистов (DB-backed). Возвращает страницу карточек с has_more.
final searchArtistsProvider = FutureProvider.autoDispose
    .family<ArtistCardPageDto, String>((ref, query) async {
  final q = query.trim();
  if (q.isEmpty) {
    return const ArtistCardPageDto(items: [], page: 0, pageSize: 0, hasMore: false);
  }
  return searchArtists(query: q, limit: _searchPageSize, offset: 0);
});

/// Поиск плейлистов (DB-backed).
final searchPlaylistsProvider = FutureProvider.autoDispose
    .family<PlaylistSummaryPageDto, String>((ref, query) async {
  final q = query.trim();
  if (q.isEmpty) {
    return const PlaylistSummaryPageDto(
        items: [], page: 0, pageSize: 0, hasMore: false);
  }
  return searchPlaylists(query: q, limit: _searchPageSize, offset: 0);
});

/// Поиск пользователей (DB-backed).
final searchUsersProvider = FutureProvider.autoDispose
    .family<UserPageDto, String>((ref, query) async {
  final q = query.trim();
  if (q.isEmpty) {
    return const UserPageDto(items: [], page: 0, pageSize: 0, hasMore: false);
  }
  return searchUsers(query: q, limit: _searchPageSize, offset: 0);
});

/// Vibe-поиск треков (вектор-похожесть). Несёт флаг `preparing` (вектор ещё
/// кодируется). `.family` по строке запроса.
final searchVibeProvider = FutureProvider.autoDispose
    .family<VibePageDto, String>((ref, query) async {
  final q = query.trim();
  if (q.isEmpty) return _emptyVibePage;
  return searchVibe(query: q, limit: _searchPageSize);
});

const _emptyVibePage = VibePageDto(items: [], preparing: false);

/// Живой поиск треков прямо в SoundCloud (источник «SC»). `.family` по запросу.
final searchScTracksProvider = FutureProvider.autoDispose
    .family<List<TrackDto>, String>((ref, query) async {
  final q = query.trim();
  if (q.isEmpty) return const [];
  return searchScTracks(query: q, limit: _searchPageSize);
});

/// Источник поиска: наша БД (db) или живой SoundCloud (sc). Легаси `searchPrefs`.
enum SearchSource { db, sc }

final searchSourceProvider =
    NotifierProvider<SearchSourceNotifier, SearchSource>(
  SearchSourceNotifier.new,
);

class SearchSourceNotifier extends Notifier<SearchSource> {
  @override
  SearchSource build() => SearchSource.db;

  void set(SearchSource s) => state = s;
}

/// Поиск треков по тексту песен (lyrics, full-text). Хит несёт совпавшую строку
/// (`matchedLine`) — карточка показывает её цитатой. `.family` по строке запроса.
final searchLyricsProvider = FutureProvider.autoDispose
    .family<LyricHitPageDto, String>((ref, query) async {
  final q = query.trim();
  if (q.isEmpty) return _emptyLyricHitPage;
  return searchLyrics(query: q, limit: _searchPageSize);
});

const _emptyLyricHitPage =
    LyricHitPageDto(items: [], page: 0, pageSize: 0, hasMore: false);
