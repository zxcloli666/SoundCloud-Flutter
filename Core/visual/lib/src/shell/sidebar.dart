import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../ambient_clock.dart';
import '../perf.dart';
import '../theme.dart';
import '../tokens.dart';
import '../widgets/primitives/avatar.dart';
import '../widgets/primitives/star_badge.dart';
import '../widgets/track/track_art.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class SidebarDestination {
  final IconData icon;
  final String label;

  const SidebarDestination({required this.icon, required this.label});
}

/// Закреплённый плейлист в «Быстром доступе» (артворк-иконка + название).
class SidebarPlaylist {
  final String urn;
  final String title;
  final String? artworkUrl;

  const SidebarPlaylist({
    required this.urn,
    required this.title,
    this.artworkUrl,
  });
}

/// Текущий пользователь для нижней строки сайдбара (аватар + ник + STAR-бейдж).
class SidebarUser {
  final String urn;
  final String username;
  final String? avatarUrl;
  final bool isPremium;

  const SidebarUser({
    required this.urn,
    required this.username,
    this.avatarUrl,
    this.isPremium = false,
  });
}

/// Боковая навигация (легаси): nav + быстрый доступ + STAR-карта + служебные
/// строки. Сворачивается 196↔56; активный пункт со свечением акцента.
class Sidebar extends StatefulWidget {
  final List<SidebarDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  /// Закреплённые плейлисты под «Историей»; пусто — секция не показывается.
  final List<SidebarPlaylist> pinnedPlaylists;
  final ValueChanged<String>? onPlaylist;

  /// Текущий пользователь нижней строки; `null` — строки нет (как в легаси).
  final SidebarUser? user;
  final ValueChanged<String>? onUser;

  /// Сеть онлайн. `false` → пункт оффлайна получает alert-вариант (§2.3).
  final bool online;

  /// Индекс пункта-оффлайна для alert-варианта; `null` — без alert.
  final int? offlineIndex;

  /// Служебные строки футера (легаси «быстрый доступ» + настройки). Шелл
  /// связывает их с маршрутами; нет колбэка — строка неактивна (как было).
  final VoidCallback? onSettings;
  final VoidCallback? onHistory;
  final VoidCallback? onStar;

  /// Свёрнут ли сайдбар — управляется снаружи (персист в settings, общий с
  /// шапкой). `onToggleCollapse` дёргает строка «Свернуть».
  final bool collapsed;
  final VoidCallback? onToggleCollapse;

  const Sidebar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelect,
    this.pinnedPlaylists = const [],
    this.onPlaylist,
    this.user,
    this.onUser,
    this.online = true,
    this.offlineIndex,
    this.onSettings,
    this.onHistory,
    this.onStar,
    this.collapsed = false,
    this.onToggleCollapse,
  });

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  bool _isAlert(int index) =>
      !widget.online && widget.offlineIndex == index;

  @override
  Widget build(BuildContext context) {
    final accent = ScTheme.paletteOf(context).accent;
    final expanded = !widget.collapsed;
    return AnimatedContainer(
      duration: ScTokens.dSidebar,
      curve: ScTokens.easeApple,
      width: expanded ? ScTokens.sidebarExpanded : ScTokens.sidebarCollapsed,
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: ScTokens.glassBorder)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          for (var i = 0; i < widget.destinations.length; i++)
            _NavRow(
              icon: widget.destinations[i].icon,
              label: expanded ? widget.destinations[i].label : null,
              active: i == widget.selectedIndex,
              alert: _isAlert(i),
              accent: accent,
              onTap: () => widget.onSelect(i),
            ),
          const SizedBox(height: 12),
          _QuickAccessHeader(expanded: expanded),
          _NavRow(
            icon: LucideIcons.history,
            label: expanded ? 'История' : null,
            active: false,
            accent: accent,
            onTap: widget.onHistory ?? () {},
          ),
          for (final p in widget.pinnedPlaylists)
            _PinnedRow(
              playlist: p,
              expanded: expanded,
              accent: accent,
              onTap: () => widget.onPlaylist?.call(p.urn),
            ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
            child: _StarCard(
              expanded: expanded,
              isPremium: widget.user?.isPremium ?? false,
              onTap: widget.onStar,
            ),
          ),
          _NavRow(
            icon: expanded ? LucideIcons.chevronLeft : LucideIcons.chevronRight,
            label: expanded ? 'Свернуть' : null,
            active: false,
            accent: accent,
            onTap: widget.onToggleCollapse ?? () {},
          ),
          _NavRow(
            icon: LucideIcons.languages,
            label: expanded ? 'Русский' : null,
            active: false,
            accent: accent,
            onTap: () {},
          ),
          _NavRow(
            icon: LucideIcons.settings,
            label: expanded ? 'Настройки' : null,
            active: false,
            accent: accent,
            onTap: widget.onSettings ?? () {},
          ),
          if (widget.user != null)
            _UserRow(
              user: widget.user!,
              expanded: expanded,
              accent: accent,
              onTap: () => widget.onUser?.call(widget.user!.urn),
            ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

/// Заголовок секции: текст «Быстрый доступ» (раскрыто) ↔ волосок (свёрнуто).
class _QuickAccessHeader extends StatelessWidget {
  final bool expanded;

  const _QuickAccessHeader({required this.expanded});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedOpacity(
              opacity: expanded ? 0 : 1,
              duration: ScTokens.dFast,
              child: Container(height: 1, color: const Color(0x12FFFFFF)),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: AnimatedOpacity(
                opacity: expanded ? 1 : 0,
                duration: ScTokens.dFast,
                child: const Text(
                  'БЫСТРЫЙ ДОСТУП',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.8,
                    fontWeight: FontWeight.w600,
                    color: ScTokens.textTertiary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Закреплённый плейлист: артворк 18×18 в icon-box (или нота-фолбэк) + название.
class _PinnedRow extends StatefulWidget {
  final SidebarPlaylist playlist;
  final bool expanded;
  final Color accent;
  final VoidCallback onTap;

  const _PinnedRow({
    required this.playlist,
    required this.expanded,
    required this.accent,
    required this.onTap,
  });

  @override
  State<_PinnedRow> createState() => _PinnedRowState();
}

class _PinnedRowState extends State<_PinnedRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final color =
        _hover ? const Color(0xCCFFFFFF) : const Color(0x73FFFFFF);
    final art = widget.playlist.artworkUrl;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: ScTokens.dFast,
            curve: ScTokens.easeApple,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ScTokens.rButton),
              color: _hover ? ScTokens.glassTintHover : const Color(0x00000000),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: Center(
                    child: art == null || art.isEmpty
                        ? Icon(LucideIcons.listMusic, size: 17, color: color)
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: TrackArtwork(url: art, size: ArtSize.avatar),
                            ),
                          ),
                  ),
                ),
                if (widget.expanded)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Text(
                        widget.playlist.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: color,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Нижняя строка пользователя: аватар 26 + ник + STAR-бейдж (если премиум).
class _UserRow extends StatefulWidget {
  final SidebarUser user;
  final bool expanded;
  final Color accent;
  final VoidCallback onTap;

  const _UserRow({
    required this.user,
    required this.expanded,
    required this.accent,
    required this.onTap,
  });

  @override
  State<_UserRow> createState() => _UserRowState();
}

class _UserRowState extends State<_UserRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 0),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: ScTokens.dFast,
            curve: ScTokens.easeApple,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ScTokens.rButton),
              color: _hover ? ScTokens.glassTintHover : const Color(0x00000000),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: Center(
                    child: Avatar(
                      src: widget.user.avatarUrl,
                      alt: widget.user.username,
                      size: 26,
                    ),
                  ),
                ),
                if (widget.expanded)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.user.username,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0x8CFFFFFF), // white/55
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (widget.user.isPremium) ...[
                            const SizedBox(width: 6),
                            const StarBadge(),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Промо STAR-подписки (collapse-aware, hover-scale) — легаси `StarCard` (§2.5):
/// фиолетовый градиент 135°, янтарная звезда с фиолетовым свечением, дрейфующие
/// частицы-звёзды, тексты «Подписка Star» + «Активна»/«Узнать больше» (premium).
class _StarCard extends StatefulWidget {
  final bool expanded;
  final bool isPremium;
  final VoidCallback? onTap;

  const _StarCard({required this.expanded, required this.isPremium, this.onTap});

  // rgba(139,92,246,…) / rgba(168,85,247,…) / rgba(192,132,252,…)
  static const _violetA = Color(0x2E8B5CF6); // .18
  static const _violetMid = Color(0x1AA855F7); // .10
  static const _violetB = Color(0x14C084FC); // .08
  static const _border = Color(0x33A855F7); // .20
  static const _amber = Color(0xFFFBBF24);
  static const _glow = Color(0x80A855F7); // фиолетовое свечение звезды (.5)

  @override
  State<_StarCard> createState() => _StarCardState();
}

class _StarCardState extends State<_StarCard> {
  bool _hover = false;

  Widget _star(double size) => Icon(
        Icons.star_rounded,
        color: _StarCard._amber,
        size: size,
        shadows: const [Shadow(color: _StarCard._glow, blurRadius: 6)],
      );

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hover ? 1.01 : 1.0,
          duration: ScTokens.dFast,
          curve: ScTokens.easeApple,
          child: Container(
            padding: widget.expanded
                ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
                : const EdgeInsets.symmetric(vertical: 10),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ScTokens.rCard),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _StarCard._violetA,
                  _StarCard._violetMid,
                  _StarCard._violetB,
                ],
              ),
              border: Border.all(color: _StarCard._border, width: 0.5),
              boxShadow: const [
                BoxShadow(color: Color(0x1F8B5CF6), blurRadius: 12, offset: Offset(0, 2)),
              ],
            ),
            child: Stack(
              children: [
                const Positioned.fill(child: _StarParticles()),
                if (widget.expanded)
                  Row(
                    children: [
                      _star(16),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Подписка Star',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: Color(0xE6FFFFFF),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3)),
                            Text(widget.isPremium ? 'Активна' : 'Узнать больше',
                                style: const TextStyle(
                                    color: Color(0x99C4B5FD),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ],
                  )
                else
                  Center(child: _star(16)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Дрейфующие частицы-звёзды на STAR-карте (легаси `StarParticles`): мелкие
/// фиолетовые точки, плавают (perf-gated: число/анимация). Тикер — AmbientClock.
class _StarParticles extends StatefulWidget {
  const _StarParticles();

  @override
  State<_StarParticles> createState() => _StarParticlesState();
}

class _StarParticlesState extends State<_StarParticles> {
  // (left%, top%, opacity, hueShift, lightness) — сид как в легаси.
  static const _defs = <(double, double, double, double, double)>[
    (10, 10, 0.4, 0, 70), (47, 63, 0.6, 20, 75), (84, 16, 0.8, 40, 80),
    (21, 69, 0.4, 0, 85), (58, 22, 0.6, 20, 90), (95, 75, 0.8, 40, 95),
    (32, 28, 0.4, 0, 70), (69, 81, 0.6, 20, 75),
  ];
  bool _sub = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  void _sync() {
    final on = ScPerf.of(context) != PerfMode.light;
    if (on && !_sub) {
      _sub = true;
      AmbientClock.instance.subscribe();
    } else if (!on && _sub) {
      _sub = false;
      AmbientClock.instance.unsubscribe();
    }
  }

  @override
  void dispose() {
    if (_sub) AmbientClock.instance.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final perf = PerfProfile.of(context);
    final count = perf.particles(_defs.length);
    if (count == 0) return const SizedBox.shrink();
    final idle = perf.idleAnim;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: AmbientClock.instance.tick,
        builder: (context, _) {
          final s = AmbientClock.instance.seconds;
          return LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth, h = c.maxHeight;
              return Stack(
                children: [
                  for (var i = 0; i < count; i++)
                    _dot(_defs[i], i, w, h, s, idle),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _dot((double, double, double, double, double) d, int i, double w,
      double h, double s, bool idle) {
    final color = HSLColor.fromAHSL(d.$3, 260 + d.$4, 0.8, d.$5 / 100).toColor();
    final dy = idle ? math.sin((s + i * 0.5) * 0.9) * 3 : 0.0;
    return Positioned(
      left: d.$1 / 100 * w,
      top: d.$2 / 100 * h + dy,
      child: Container(
        width: 3,
        height: 3,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _NavRow extends StatefulWidget {
  final IconData icon;
  final String? label;
  final bool active;
  final bool alert;
  final Color accent;
  final VoidCallback onTap;

  const _NavRow({
    required this.icon,
    required this.label,
    required this.active,
    required this.accent,
    required this.onTap,
    this.alert = false,
  });

  @override
  State<_NavRow> createState() => _NavRowState();
}

class _NavRowState extends State<_NavRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    final alert = widget.alert && !active;
    final Color foreground = active
        ? const Color(0xFFFFFFFF)
        : alert
            ? const Color(0xD9FFFFFF) // white/85
            : (_hover ? const Color(0xCCFFFFFF) : const Color(0x73FFFFFF));

    final BoxDecoration decoration = active
        ? BoxDecoration(
            borderRadius: BorderRadius.circular(ScTokens.rButton),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [widget.accent.withValues(alpha: 0.20), const Color(0x0DFFFFFF)],
            ),
            border: const Border(
              top: BorderSide(color: Color(0x24FFFFFF), width: 0.5),
            ),
            boxShadow: [
              BoxShadow(color: widget.accent.withValues(alpha: 0.20), blurRadius: 18),
            ],
          )
        : alert
            // Alert-вариант (оффлайн): bg-accent/0.08 + ring accent/20.
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(ScTokens.rButton),
                color: widget.accent.withValues(alpha: 0.08),
                border: Border.all(color: widget.accent.withValues(alpha: 0.20)),
              )
            : BoxDecoration(
                borderRadius: BorderRadius.circular(ScTokens.rButton),
                color: _hover ? ScTokens.glassTintHover : const Color(0x00000000),
              );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: ScTokens.dFast,
            curve: ScTokens.easeApple,
            height: 40,
            decoration: decoration,
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(widget.icon, size: 18, color: foreground),
                ),
                if (widget.label != null)
                  Expanded(
                    child: Text(
                      widget.label!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
