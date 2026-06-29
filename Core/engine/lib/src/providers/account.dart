import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../rust/api.dart';
import '../rust/data_social.dart';
import '../rust/dto.dart';
import '../rust/dto_social.dart';
import 'pagination.dart';

/// Подписки текущего пользователя (`me_followings`) с бесконечной подгрузкой.
final meFollowingsProvider =
    AsyncNotifierProvider<MeFollowingsNotifier, PagedList<UserDto>>(
  MeFollowingsNotifier.new,
);

class MeFollowingsNotifier extends PagedNotifier<UserDto> {
  @override
  int get pageSize => 50;

  @override
  Future<PageSlice<UserDto>> fetch({
    required int limit,
    required int offset,
  }) async {
    final page = await meFollowings(limit: limit, offset: offset);
    return PageSlice(items: page.items, hasMore: page.hasMore);
  }
}

/// Свежие треки тех, на кого подписан (`me_followings_tracks`).
final meFollowingsTracksProvider =
    AsyncNotifierProvider<MeFollowingsTracksNotifier, PagedList<TrackDto>>(
  MeFollowingsTracksNotifier.new,
);

class MeFollowingsTracksNotifier extends PagedNotifier<TrackDto> {
  @override
  int get pageSize => 50;

  @override
  Future<PageSlice<TrackDto>> fetch({
    required int limit,
    required int offset,
  }) async {
    final page = await meFollowingsTracks(limit: limit, offset: offset);
    return PageSlice(items: page.items, hasMore: page.hasMore);
  }
}

/// Аура пользователя по urn (`user_aura`) — id пресета + опц. кастомный цвет.
final userAuraProvider =
    FutureProvider.autoDispose.family<AuraDto, String>((ref, urn) {
  return userAura(urn: urn);
});

/// Записать ауру и обновить читающий [userAuraProvider] для [urn].
///
/// Без собственного состояния: страница зовёт
/// `ref.read(auraControllerProvider).put(...)`.
final auraControllerProvider = Provider<AuraController>(AuraController.new);

class AuraController {
  AuraController(this._ref);

  final Ref _ref;

  /// Сохранить ауру текущего пользователя. [urn] нужен лишь для инвалидации
  /// соответствующего [userAuraProvider]; запись идёт в `me`.
  Future<AuraDto> put({
    required String urn,
    required String auraId,
    String? customHex,
  }) async {
    final saved = await putAura(auraId: auraId, customHex: customHex);
    _ref.invalidate(userAuraProvider(urn));
    return saved;
  }
}

/// Резолв публичной ссылки SoundCloud в трек (`resolve_url`). `null` — ссылка
/// не указывает на трек (артист/плейлист/мусор) либо недоступна.
final resolveUrlProvider =
    FutureProvider.autoDispose.family<TrackDto?, String>((ref, url) {
  final u = url.trim();
  if (u.isEmpty) return Future.value(null);
  return resolveUrl(url: u);
});
