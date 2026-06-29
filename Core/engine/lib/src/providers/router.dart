import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings.dart';

/// Навигация движка: стек маршрутов поверх единой content-области. Верхние пункты
/// сайдбара заменяют корень стека (`selectTab`), детальные экраны кладутся сверху
/// (`push`) и снимаются `pop`. Шелл (сайдбар + NowBar) живёт вокруг и не пересоздаётся.
final routerProvider = NotifierProvider<RouterNotifier, List<ScRoute>>(
  RouterNotifier.new,
);

class RouterNotifier extends Notifier<List<ScRoute>> {
  @override
  List<ScRoute> build() => [_startupRoot(ref.read(settingsProvider).startupTab)];

  /// Стартовый раздел по сохранённой настройке (индекс таба сайдбара).
  ScRoute _startupRoot(int tab) => switch (tab) {
        1 => const SearchRoute(),
        2 => const DiscoverRoute(),
        3 => const LibraryRoute(),
        4 => const StarRoute(),
        5 => const OfflineRoute(),
        _ => const HomeRoute(),
      };

  ScRoute get current => state.last;
  bool get canPop => state.length > 1;

  /// Перейти в раздел сайдбара: сбросить стек к одному корню.
  void selectTab(ScRoute root) => state = [root];

  void push(ScRoute route) => state = [...state, route];

  void pop() {
    if (canPop) state = state.sublist(0, state.length - 1);
  }

  void reset() => state = const [HomeRoute()];
}

/// Маршрут. `tab` — индекс destination сайдбара для подсветки (null у детальных
/// и модальных экранов).
sealed class ScRoute {
  const ScRoute();
  int? get tab => null;
}

class HomeRoute extends ScRoute {
  const HomeRoute();
  @override
  int? get tab => 0;
}

class SearchRoute extends ScRoute {
  const SearchRoute();
  @override
  int? get tab => 1;
}

class DiscoverRoute extends ScRoute {
  const DiscoverRoute();
  @override
  int? get tab => 2;
}

class LibraryRoute extends ScRoute {
  const LibraryRoute();
  @override
  int? get tab => 3;
}

class StarRoute extends ScRoute {
  const StarRoute();
  @override
  int? get tab => 4;
}

class OfflineRoute extends ScRoute {
  const OfflineRoute();
  @override
  int? get tab => 5;
}

class SettingsRoute extends ScRoute {
  const SettingsRoute();
}

class LoginRoute extends ScRoute {
  const LoginRoute();
}

class TrackRoute extends ScRoute {
  final String urn;
  const TrackRoute(this.urn);
}

class PlaylistRoute extends ScRoute {
  final String urn;
  const PlaylistRoute(this.urn);
}

class AlbumRoute extends ScRoute {
  final String id;
  const AlbumRoute(this.id);
}

class ArtistRoute extends ScRoute {
  final String id;
  const ArtistRoute(this.id);
}

class UserRoute extends ScRoute {
  final String urn;
  const UserRoute(this.urn);
}

/// Раздел библиотеки (лайкнутые треки / плейлисты / история / мои плейлисты).
class LibraryCollectionRoute extends ScRoute {
  final LibraryCollectionKind kind;
  const LibraryCollectionRoute(this.kind);
  @override
  int? get tab => 3;
}

enum LibraryCollectionKind { likedTracks, likedPlaylists, myPlaylists, history }
