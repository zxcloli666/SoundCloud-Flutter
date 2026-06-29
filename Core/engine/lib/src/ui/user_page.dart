import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import '../providers.dart';
import '../rust/dto.dart';
import 'user/user_aura.dart';
import 'user/user_identity_hub.dart';
import 'user/user_search_box.dart';
import 'user/user_tabs.dart';

/// Профиль пользователя (легаси `UserPage`, §3.11): атмосфера-аура за центральной
/// колонкой → IdentityHub-герой → TabDock + inline-поиск → стеклянная панель
/// контента (popular/tracks/playlists/likes/followers/following).
///
/// Профиль (`userProvider`), соц-ссылки, подписка-star и аура резолвятся по urn;
/// вкладки тянут постраничные провайдеры юзера (треки/плейлисты/лайки/связи).
/// Star-аура берётся из пресета владельца, иначе — viewer-аура из акцента (§5.6).
class UserPage extends ConsumerStatefulWidget {
  final String urn;

  const UserPage({super.key, required this.urn});

  @override
  ConsumerState<UserPage> createState() => _UserPageState();
}

class _UserPageState extends ConsumerState<UserPage> {
  UserTab _activeTab = UserTab.popular;

  final _searchController = TextEditingController();
  final _scroll = SmoothScrollController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Debounce 350ms — баланс «не лагает на символ» / «отзывчиво» (легаси).
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  @override
  void initState() {
    super.initState();
    // Накопительные провайдеры профиля шарятся между юзерами — грузим первую
    // страницу активного таба после монтажа, а далее по смене таба (ленивый
    // резолв: чужие вкладки не дёргаем, пока их не открыли).
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureLoaded(_activeTab));
  }

  /// При смене таба чистим поиск (иначе followers→tracks показал бы чужую строку)
  /// и подтягиваем первую страницу нового таба.
  void _onTabChanged(UserTab tab) {
    if (tab == _activeTab) return;
    _debounce?.cancel();
    _searchController.clear();
    setState(() {
      _activeTab = tab;
      _query = '';
    });
    _ensureLoaded(tab);
  }

  /// Триггернуть `load(urn)` постраничного провайдера, стоящего за [tab]. Popular
  /// читает `userTracks` (потом сортирует по play_count во вью).
  void _ensureLoaded(UserTab tab) {
    final urn = widget.urn;
    switch (tab) {
      case UserTab.popular:
      case UserTab.tracks:
        ref.read(userTracksProvider.notifier).load(urn);
      case UserTab.playlists:
        ref.read(userPlaylistsProvider.notifier).load(urn);
      case UserTab.likes:
        ref.read(userLikedTracksProvider.notifier).load(urn);
      case UserTab.followers:
        ref.read(userFollowersProvider.notifier).load(urn);
      case UserTab.following:
        ref.read(userFollowingsProvider.notifier).load(urn);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = ScTheme.paletteOf(context).accent;
    final me = ref.watch(meProvider).value;
    final user = ref.watch(userProvider(widget.urn)).value;
    final isOwnProfile = me != null && me.urn == widget.urn;

    // Star: свой профиль — по premium из me, чужой — по userSubscription.
    final hasStar = isOwnProfile
        ? me.premium
        : (ref.watch(userSubscriptionProvider(widget.urn)).value ?? false);

    // Star-аура — пресет/кастом владельца; иначе viewer-аура из акцента (§5.6).
    final auraDto = hasStar ? ref.watch(userAuraProvider(widget.urn)).value : null;
    final aura = hasStar
        ? UserAura.preset(auraDto?.auraId, auraDto?.customHex)
        : UserAura.viewer(accent);

    return Atmosphere(
      variant: AtmosphereVariant.aura,
      tint: aura.orbs,
      intense: hasStar,
      child: SingleChildScrollView(
        controller: _scroll,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1480),
            child: Padding(
              padding: EdgeInsets.fromLTRB(_hPad(context), 64, _hPad(context), 128),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  UserIdentityHub(
                    urn: widget.urn,
                    user: user,
                    webProfiles: ref.watch(userWebProfilesProvider(widget.urn)).value ?? const [],
                    aura: aura,
                    hasStar: hasStar,
                    isOwnProfile: isOwnProfile,
                  ),
                  const SizedBox(height: 40),
                  _TabsRow(
                    user: user,
                    aura: aura,
                    activeTab: _activeTab,
                    onTabChanged: _onTabChanged,
                    searchController: _searchController,
                    onSearchChanged: _onSearchChanged,
                  ),
                  const SizedBox(height: 24),
                  GlassContentPanel(
                    child: UserTabView(
                      urn: widget.urn,
                      tab: _activeTab,
                      aura: aura,
                      query: _query,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // px-4 md:px-8.
  double _hPad(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 768 ? 32 : 16;
}

/// Док вкладок + inline-поиск: широкий экран — в ряд, иначе друг под другом.
class _TabsRow extends StatelessWidget {
  final UserDto? user;
  final UserAura aura;
  final UserTab activeTab;
  final ValueChanged<UserTab> onTabChanged;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;

  const _TabsRow({
    required this.user,
    required this.aura,
    required this.activeTab,
    required this.onTabChanged,
    required this.searchController,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 768;
    final dock = Align(
      alignment: Alignment.centerLeft,
      child: TabDock(
        tabs: [
          for (final t in UserTab.values)
            TabDockItem(id: t.name, label: t.label, count: _countFor(t)),
        ],
        activeId: activeTab.name,
        aura: aura.accent,
        onChanged: (id) =>
            onTabChanged(UserTab.values.firstWhere((t) => t.name == id)),
      ),
    );

    final search = UserSearchBox(
      controller: searchController,
      onChanged: onSearchChanged,
      scopeLabel: activeTab.searchScopeLabel,
      enabled: activeTab.searchable,
    );

    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [dock, const SizedBox(height: 16), search],
      );
    }
    return Row(
      children: [
        Expanded(child: dock),
        const SizedBox(width: 16),
        SizedBox(width: 320, child: search),
      ],
    );
  }

  int? _countFor(UserTab tab) {
    final u = user;
    if (u == null) return null;
    return switch (tab) {
      UserTab.popular => null,
      UserTab.tracks => u.trackCount?.toInt(),
      UserTab.playlists => u.playlistCount?.toInt(),
      UserTab.likes => u.publicFavoritesCount?.toInt(),
      UserTab.followers => u.followersCount?.toInt(),
      UserTab.following => u.followingsCount?.toInt(),
    };
  }
}

