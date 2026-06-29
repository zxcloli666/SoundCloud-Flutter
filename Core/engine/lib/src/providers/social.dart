import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../rust/data_social.dart' as bridge;
import 'library.dart';

/// Контроллер соц-мутаций (лайки, фолловы, дизлайки, очистка истории).
///
/// Без собственного состояния: страница держит свой оптимистичный флаг и зовёт
/// `ref.read(socialControllerProvider).likeTrack(urn)`. Методы прокидывают вызов
/// в ядро (единый писатель в нашу БД) и пробрасывают ошибку наверх, чтобы
/// вызывающий мог откатить оптимизм. После очистки истории инвалидируется
/// [historyProvider].
final socialControllerProvider = Provider<SocialController>(
  SocialController.new,
);

class SocialController {
  SocialController(this._ref);

  final Ref _ref;

  Future<void> likeTrack(String trackUrn) =>
      bridge.likeTrack(trackUrn: trackUrn);

  Future<void> unlikeTrack(String trackUrn) =>
      bridge.unlikeTrack(trackUrn: trackUrn);

  Future<void> likePlaylist(String playlistUrn) =>
      bridge.likePlaylist(playlistUrn: playlistUrn);

  Future<void> unlikePlaylist(String playlistUrn) =>
      bridge.unlikePlaylist(playlistUrn: playlistUrn);

  Future<void> followUser(String userUrn) =>
      bridge.followUser(userUrn: userUrn);

  Future<void> unfollowUser(String userUrn) =>
      bridge.unfollowUser(userUrn: userUrn);

  Future<void> dislikeTrack(String scTrackId) =>
      bridge.dislikeTrack(scTrackId: scTrackId);

  Future<void> undislikeTrack(String scTrackId) =>
      bridge.undislikeTrack(scTrackId: scTrackId);

  /// Очистить историю прослушиваний и перечитать [historyProvider].
  Future<void> clearHistory() async {
    await bridge.clearHistory();
    _ref.invalidate(historyProvider);
  }
}
