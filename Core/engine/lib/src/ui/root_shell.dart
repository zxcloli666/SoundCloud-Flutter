import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import '../providers.dart';
import '../rust/api.dart';
import 'album_page.dart';
import 'artist_page.dart';
import 'discover_page.dart';
import 'header_bar.dart';
import 'home_page.dart';
import 'host_status_overlay.dart';
import 'library_collection_page.dart';
import 'library_page.dart';
import 'login_page.dart';
import 'now_playing_bar.dart';
import 'now_playing_bar/panels/now_bar_panel_host.dart';
import 'offline_page.dart';
import 'playlist_page.dart';
import 'search_screen.dart';
import 'settings_page.dart';
import 'star_page.dart';
import 'track_page.dart';
import 'user_page.dart';
import '../tray/mini_player_host.dart';

/// Верхние разделы сайдбара (легаси-порядок). Индекс = [ScRoute.tab]. Подписи —
/// из локали (`nav.*`), иконки и порядок постоянны.
List<SidebarDestination> _destinations(WidgetRef ref) => [
      SidebarDestination(icon: LucideIcons.house, label: ref.tr('nav.home')),
      SidebarDestination(icon: LucideIcons.search, label: ref.tr('nav.search')),
      SidebarDestination(
          icon: LucideIcons.compass, label: ref.tr('nav.discover')),
      SidebarDestination(
          icon: LucideIcons.libraryBig, label: ref.tr('nav.library')),
      SidebarDestination(icon: Icons.star_rounded, label: ref.tr('nav.star')),
      SidebarDestination(
          icon: LucideIcons.download, label: ref.tr('nav.offline')),
    ];

/// Раздел сайдбара по его индексу — корень стека при `selectTab`.
const _tabRoots = <ScRoute>[
  HomeRoute(),
  SearchRoute(),
  DiscoverRoute(),
  LibraryRoute(),
  StarRoute(),
  OfflineRoute(),
];

/// Корневая оболочка движка: сайдбар + атмосфера + страница раздела + NowBar.
class ScRootShell extends ConsumerWidget {
  const ScRootShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boot = ref.watch(bootstrapProvider);
    // Локали грузим до первого кадра вместе с ядром — иначе `tr` отдаёт ключи.
    final i18n = ref.watch(i18nStoreProvider);
    // Акцент юзера → вся дизайн-система (hover/glow/selection выводятся из него);
    // `null` — дефолт темы SoundCloud (#ff5500).
    final accent = ref.watch(settingsProvider.select((s) => s.accent));
    return ScPerf(
      mode: ref.watch(settingsProvider.select((s) => s.perfMode)),
      child: ScTheme(
        palette: accent == null ? const ScPalette() : ScPalette(Color(accent)),
        // Плавная инерция скролла во всём приложении (премиум-фил, без «ступенек»).
        child: ScrollConfiguration(
          behavior: const ScScrollBehavior(),
          // Единый тостер поверх всего (гейт/логин/шелл) — уведомления без Scaffold.
          child: ToastScope(
            child: boot.when(
              data: (_) =>
                  i18n.hasValue ? const _AuthGate() : const _BootScreen(),
              loading: () => const _BootScreen(),
              error: (error, _) => ColoredBox(
                color: ScTokens.bgRoot,
                child: Center(
                  child: Text(
                    'Не удалось запустить ядро: $error',
                    style: const TextStyle(color: ScTokens.textSecondary),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Гейт входа: в основное приложение — только с сессией (легаси-инвариант). Без
/// сессии — экран входа; «смотреть офлайн» — только по явному выбору. Главное:
/// data-провайдеры (me/библиотека/волна) не монтируются, пока не вошли — отсюда
/// нет анонимных 401.
class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final offline = ref.watch(offlineBypassProvider);
    return auth.when(
      data: (state) {
        if (state.canUseMainShell) return const _Shell();
        if (offline) return const _OfflineGate();
        return const LoginPage();
      },
      loading: () => const _BootScreen(),
      error: (_, __) => const LoginPage(),
    );
  }
}

/// Офлайн-режим без входа: только «Кузница» оффлайна + выход обратно на вход.
class _OfflineGate extends ConsumerWidget {
  const _OfflineGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ColoredBox(
      color: ScTokens.bgRoot,
      child: Stack(
        children: [
          const Positioned.fill(child: OfflinePage()),
          Positioned(
            top: 16,
            left: 16,
            child: _BackChip(
              onTap: ref.read(offlineBypassProvider.notifier).exit,
              label: ref.tr('common.back'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Заставка запуска (инициализация ядра / проверка сессии).
class _BootScreen extends StatelessWidget {
  const _BootScreen();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: ScTokens.bgRoot,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

/// Сайдбар + NowBar — персистентны; меняется только содержимое content-области
/// (по верхушке стека маршрутов). Шелл не пересоздаётся при навигации.
class _Shell extends ConsumerStatefulWidget {
  const _Shell();

  @override
  ConsumerState<_Shell> createState() => _ShellState();
}

class _ShellState extends ConsumerState<_Shell> {
  /// Последняя отданная в системные контролы секунда (дроссель тика позиции).
  int _lastProgressSec = -1;

  @override
  void initState() {
    super.initState();
    // Подхватить последнее воспроизведение один раз после входа: трек появляется
    // в NowBar на паузе, готовый к запуску (легаси `sc-player` rehydrate).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final snap = ref.read(playbackPersistProvider).load();
      if (snap != null) ref.read(playerProvider.notifier).restore(snap);
    });
  }

  @override
  Widget build(BuildContext context) {
    final stack = ref.watch(routerProvider);
    final router = ref.read(routerProvider.notifier);
    final route = stack.last;

    // Критические события плеера живут на уровне шелла (он персистентен): конец
    // трека продолжает очередь из волны, авто-переезд ядра синхронизирует
    // now-playing. Иначе плеер встаёт в тупик, а NowBar показывает старый трек.
    ref.listen(playbackEventsProvider, (_, next) {
      switch (next.value) {
        case PlaybackEventDto_Ended():
          ref.read(playbackQueueProvider.notifier).onEnded();
        case PlaybackEventDto_TrackChanged(:final urn):
          ref.read(playerProvider.notifier).adoptCurrent(urn);
        case null:
          break;
      }
    });

    // Смена аудиовыхода в настройках — переключаем устройство в ядре (текущий
    // трек переезжает сам, с сохранением позиции).
    ref.listen(settingsProvider.select((s) => s.audioDevice), (_, device) {
      setAudioOutput(name: device);
    });

    // Тик позиции в системные контролы (MPRIS-скраббер/Discord-таймстемп),
    // дросселированный до целой секунды — не дёргаем FFI на каждый кадр.
    ref.listen(positionStreamProvider, (_, next) {
      final secs = next.value;
      if (secs == null) return;
      final sec = secs.floor();
      if (sec == _lastProgressSec) return;
      _lastProgressSec = sec;
      ref.read(scConfigProvider).media?.onProgress?.call(secs);
    });

    // Инструмент-панели NowBar (EQ/очередь/лирика) парят поверх всего шелла —
    // правый док и фуллскрин-лирика должны крыть окно целиком (включая сайдбар).
    return Stack(
      children: [
        AppShell(
          destinations: _destinations(ref),
          selectedIndex: _selectedTab(stack),
          onSelect: (i) => router.selectTab(_tabRoots[i]),
          pinnedPlaylists: _pinnedPlaylists(ref),
          onPlaylist: (urn) => router.push(PlaylistRoute(urn)),
          user: _sidebarUser(ref),
          onUser: (urn) => router.push(UserRoute(urn)),
          offlineIndex: _tabRoots.indexWhere((r) => r is OfflineRoute),
          onSettings: () => router.selectTab(const SettingsRoute()),
          onStar: () => router.selectTab(const StarRoute()),
          onHistory: () => router.selectTab(
              const LibraryCollectionRoute(LibraryCollectionKind.history)),
          sidebarCollapsed:
              ref.watch(settingsProvider.select((s) => s.sidebarCollapsed)),
          onToggleSidebar: ref.read(settingsProvider.notifier).toggleSidebar,
          header: const ScHeaderBar(),
          wallpaper: _wallpaper(ref),
          content: _RouteContent(
            route: route,
            canPop: stack.length > 1,
            onBack: router.pop,
            backLabel: ref.tr('common.back'),
          ),
          nowBar: const NowBarHost(),
        ),
        const Positioned.fill(child: NowBarPanelHost()),
        const Positioned.fill(child: HostStatusOverlay()),
        const _RemoteBinder(),
        const MiniPlayerHost(),
      ],
    );
  }

  /// Слой обоины из настроек (`backgroundImage` + затемнение/прозрачность/блюр).
  /// `null` — фон не выбран (рисуется обычная атмосфера).
  Widget? _wallpaper(WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    if (s.backgroundImage.isEmpty) return null;
    return ScWallpaperLayer(
      image: FileImage(File(s.backgroundImage)),
      opacity: s.backgroundOpacity,
      dim: s.backgroundDim,
      blur: s.backgroundBlur,
    );
  }

  /// Закреплённые плейлисты «Быстрого доступа» — ТОЛЬКО закреплённые юзером
  /// (персист `settings.pinnedPlaylists`), без моков «все плейлисты».
  List<SidebarPlaylist> _pinnedPlaylists(WidgetRef ref) {
    final pins = ref.watch(settingsProvider.select((s) => s.pinnedPlaylists));
    return [
      for (final p in pins)
        SidebarPlaylist(urn: p.urn, title: p.title, artworkUrl: p.artworkUrl),
    ];
  }

  /// Нижняя строка пользователя из профиля `me` + флага премиума.
  SidebarUser? _sidebarUser(WidgetRef ref) {
    final me = ref.watch(meProvider).value;
    if (me == null) return null;
    final premium =
        me.premium || (ref.watch(meSubscriptionProvider).value ?? false);
    return SidebarUser(
      urn: me.urn,
      username: me.username,
      avatarUrl: me.avatarUrl,
      isPremium: premium,
    );
  }

  /// Подсветка раздела: tab текущего маршрута, иначе последний верхнеуровневый
  /// в стеке (деталь под разделом не гасит его подсветку).
  int _selectedTab(List<ScRoute> stack) {
    for (final route in stack.reversed) {
      final tab = route.tab;
      if (tab != null) return tab;
    }
    return 0;
  }
}

/// Регистрирует обработчики внешнего управления (трей/MPRIS) в [ScRemoteControls]
/// хоста — раз, на маунте шелла. Невидим. До этого вызовы трея — no-op.
class _RemoteBinder extends ConsumerStatefulWidget {
  const _RemoteBinder();

  @override
  ConsumerState<_RemoteBinder> createState() => _RemoteBinderState();
}

class _RemoteBinderState extends ConsumerState<_RemoteBinder> {
  @override
  void initState() {
    super.initState();
    ref.read(scConfigProvider).remote?.bind(
          // Явные play/pause (MPRIS) — состояние-зависимы поверх тоггла, чтобы не
          // «переключить наоборот», если ОС прислала Play, а уже играет.
          play: () async {
            if (!ref.read(isPlayingProvider)) {
              await ref.read(playerProvider.notifier).togglePause();
            }
          },
          pause: () async {
            if (ref.read(isPlayingProvider)) {
              await ref.read(playerProvider.notifier).togglePause();
            }
          },
          playPause: () => ref.read(playerProvider.notifier).togglePause(),
          next: () => ref.read(playbackQueueProvider.notifier).next(),
          previous: () => ref.read(playbackQueueProvider.notifier).previous(),
          stop: () => ref.read(playerProvider.notifier).stopPlayback(),
        );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Анимированная подмена страницы + шелл-уровневая «назад», когда у маршрута нет
/// собственной. Сайдбар/NowBar остаются снаружи и не перерисовываются.
class _RouteContent extends StatelessWidget {
  final ScRoute route;
  final bool canPop;
  final VoidCallback onBack;
  final String backLabel;

  const _RouteContent({
    required this.route,
    required this.canPop,
    required this.onBack,
    required this.backLabel,
  });

  @override
  Widget build(BuildContext context) {
    final showBack = canPop && !_routeOwnsBack(route);
    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: ScTokens.dGlass,
            switchInCurve: ScTokens.easeApple,
            switchOutCurve: ScTokens.easeApple,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.012),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: KeyedSubtree(
              key: ValueKey(_routeKey(route)),
              child: _pageFor(route),
            ),
          ),
        ),
        if (showBack)
          Positioned(
            top: 16,
            left: 16,
            child: _BackChip(onTap: onBack, label: backLabel),
          ),
      ],
    );
  }

  Widget _pageFor(ScRoute route) {
    return switch (route) {
      HomeRoute() => const HomePage(),
      SearchRoute() => const SearchScreen(),
      DiscoverRoute() => const DiscoverPage(),
      LibraryRoute() => const LibraryPage(),
      StarRoute() => const StarPage(),
      OfflineRoute() => const OfflinePage(),
      SettingsRoute() => const SettingsPage(),
      LoginRoute() => const LoginPage(),
      LibraryCollectionRoute(:final kind) => LibraryCollectionPage(kind: kind),
      TrackRoute(:final urn) => TrackPage(urn: urn),
      PlaylistRoute(:final urn) => PlaylistPage(urn: urn),
      AlbumRoute(:final id) => AlbumPage(id: id),
      ArtistRoute(:final id) => ArtistPage(id: id),
      UserRoute(:final urn) => UserPage(urn: urn),
    };
  }

  /// Стабильный ключ для AnimatedSwitcher: тип + параметр детали.
  String _routeKey(ScRoute route) {
    return switch (route) {
      LibraryCollectionRoute(:final kind) => 'collection:${kind.name}',
      TrackRoute(:final urn) => 'track:$urn',
      PlaylistRoute(:final urn) => 'playlist:$urn',
      AlbumRoute(:final id) => 'album:$id',
      ArtistRoute(:final id) => 'artist:$id',
      UserRoute(:final urn) => 'user:$urn',
      _ => route.runtimeType.toString(),
    };
  }

  /// Детальные экраны с собственной кнопкой «назад» — шелл свою не рисует.
  bool _routeOwnsBack(ScRoute route) => switch (route) {
        TrackRoute() ||
        PlaylistRoute() ||
        LibraryCollectionRoute() ||
        StarRoute() =>
          true,
        _ => false,
      };
}

/// Парящая стеклянная «назад» поверх контента (для экранов без своей).
class _BackChip extends StatelessWidget {
  final VoidCallback onTap;
  final String label;

  const _BackChip({required this.onTap, required this.label});

  @override
  Widget build(BuildContext context) {
    return GlassButton(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.arrowLeft, size: 18, color: Color(0xCCFFFFFF)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xCCFFFFFF),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
