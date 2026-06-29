import 'package:flutter/material.dart';

import '../atmosphere.dart';
import '../tokens.dart';
import 'sidebar.dart';

/// Десктоп-оболочка: атмосфера на ВСЁ окно (за прозрачным сайдбаром, как
/// `fixed inset-0` в легаси) + сайдбар слева + контент + парящий NowBar снизу.
/// Хостит [AtmosphereScope]: страница отдаёт сюда конфиг, фон рисуется фуллскрин.
class AppShell extends StatefulWidget {
  final List<SidebarDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final Widget content;
  final Widget? nowBar;

  /// Данные сайдбара поверх навигации (см. [Sidebar]).
  final List<SidebarPlaylist> pinnedPlaylists;
  final ValueChanged<String>? onPlaylist;
  final SidebarUser? user;
  final ValueChanged<String>? onUser;
  final bool online;
  final int? offlineIndex;

  /// Служебные строки сайдбара (см. [Sidebar]).
  final VoidCallback? onSettings;
  final VoidCallback? onHistory;
  final VoidCallback? onStar;

  /// Свёрнут ли сайдбар (общий с шапкой; персист в settings движка).
  final bool sidebarCollapsed;
  final VoidCallback? onToggleSidebar;

  /// Высота титлбара хоста (когда [header] не задан): контент резервирует её
  /// сверху, атмосфера рисуется на всё окно (видна сквозь прозрачный титлбар).
  final double topInset;

  /// Шапка приложения на всю ширину сверху (лого+нав+поиск+кнопки окна). Строит
  /// движок (нужен роутер). Прозрачная — атмосфера видна за ней.
  final Widget? header;

  /// Слой фоновой обоины (ScWallpaperLayer) — рисуется поверх тёмной базы, но под
  /// орбами/звёздами: «обоина + glow + звёзды» одной композицией. `null` — нет фона.
  final Widget? wallpaper;

  const AppShell({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelect,
    required this.content,
    this.nowBar,
    this.pinnedPlaylists = const [],
    this.onPlaylist,
    this.user,
    this.onUser,
    this.online = true,
    this.offlineIndex,
    this.onSettings,
    this.onHistory,
    this.onStar,
    this.sidebarCollapsed = false,
    this.onToggleSidebar,
    this.topInset = 0,
    this.header,
    this.wallpaper,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  /// Конфиг атмосферы текущей страницы — пишет страница-[Atmosphere], читает фон.
  final ValueNotifier<AtmosphereConfig?> _atmo =
      ValueNotifier<AtmosphereConfig?>(null);

  @override
  void dispose() {
    _atmo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    // Material (прозрачный) — чтобы вложенные Material-виджеты работали без
    // Scaffold; атмосфера остаётся видна сквозь сайдбар/титлбар.
    return AtmosphereScope(
      config: _atmo,
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            // Атмосфера на ВСЁ окно (за сайдбаром): база+орбы+звёзды из конфига
            // страницы. Пока страница не выставила конфиг — тёмная база.
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: ValueListenableBuilder<AtmosphereConfig?>(
                    valueListenable: _atmo,
                    builder: (context, cfg, _) {
                      final wp = w.wallpaper;
                      if (wp == null) {
                        return cfg == null
                            ? const ColoredBox(color: ScTokens.bgRoot)
                            : AtmosphereBackdrop(config: cfg);
                      }
                      // Тёмная база → обоина → орбы/звёзды поверх (прозрачная база).
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          const ColoredBox(color: ScTokens.bgRoot),
                          wp,
                          if (cfg != null)
                            AtmosphereBackdrop(config: cfg, transparentBase: true),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            Column(
              children: [
                if (w.header != null)
                  w.header!
                else if (w.topInset > 0)
                  SizedBox(height: w.topInset),
                Expanded(
                  child: Row(
                    children: [
                      Sidebar(
                        destinations: w.destinations,
                        selectedIndex: w.selectedIndex,
                        onSelect: w.onSelect,
                        pinnedPlaylists: w.pinnedPlaylists,
                        onPlaylist: w.onPlaylist,
                        user: w.user,
                        onUser: w.onUser,
                        online: w.online,
                        offlineIndex: w.offlineIndex,
                        onSettings: w.onSettings,
                        onHistory: w.onHistory,
                        onStar: w.onStar,
                        collapsed: w.sidebarCollapsed,
                        onToggleCollapse: w.onToggleSidebar,
                      ),
                      Expanded(
                        child: Stack(
                          children: [
                            Positioned.fill(child: w.content),
                            // `.npb` overlay (§2.4): full-bleed снизу; док парит
                            // снизу-по-центру, клики мимо пилюли проходят насквозь.
                            if (w.nowBar != null)
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 11, 16, 15),
                                  child: Align(
                                    alignment: Alignment.bottomCenter,
                                    child: w.nowBar,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
