import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import '../providers.dart';

/// Шапка приложения 1:1 с легаси `Titlebar`: лого + wordmark + Назад/Вперёд/Домой
/// слева, глобальный поиск по центру, кнопки окна справа (отдаёт десктоп-оболочка
/// через [ScEngineConfig.windowControls]). Прозрачная — атмосфера видна за ней.
/// Перетаскивание окна — за пустые зоны (онпан → хост).
class ScHeaderBar extends ConsumerWidget {
  const ScHeaderBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = ref.read(scConfigProvider);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) => cfg.onWindowDragStart?.call(),
      onDoubleTap: cfg.onWindowDoubleTap,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x0DFFFFFF), Color(0x04FFFFFF)],
          ),
          border:
              Border(bottom: BorderSide(color: Color(0x12FFFFFF), width: 0.5)),
        ),
        child: SizedBox(
          height: 56,
          child: Stack(
            children: [
              // Верхний specular-блик.
              const Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: SizedBox(
                  height: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0x00FFFFFF),
                          Color(0x24FFFFFF),
                          Color(0x00FFFFFF)
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _logo(),
                    _Wordmark(
                      collapsed: ref.watch(
                          settingsProvider.select((s) => s.sidebarCollapsed)),
                    ),
                    const SizedBox(width: 10),
                    const _NavButtons(),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 600),
                          child: const _HeaderSearch(),
                        ),
                      ),
                    ),
                    if (cfg.windowControls != null) cfg.windowControls!,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Аватарка приложения (легаси `app-icon.png`) — sleeping-cloud иконка, как в
  /// Tauri-титлбаре, со свечением акцента под ней.
  Widget _logo() => Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(
                color: Color(0x33FF5500), blurRadius: 12, offset: Offset(0, 2)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset(
            'assets/app-icon.png',
            package: 'sc_engine',
            width: 32,
            height: 32,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
          ),
        ),
      );
}

/// Wordmark «SoundCloud» — сворачивается в такт с сайдбаром (легаси: ширина
/// 0↔120 + fade, без mount/unmount). `OverflowBox` держит контент фикс-шириной,
/// `ClipRect` режет по анимируемой ширине — без overflow-ассертов.
class _Wordmark extends StatelessWidget {
  final bool collapsed;
  const _Wordmark({required this.collapsed});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 420),
        curve: const Cubic(0.2, 0.8, 0.2, 1),
        width: collapsed ? 0 : 120,
        child: OverflowBox(
          minWidth: 120,
          maxWidth: 120,
          alignment: Alignment.centerLeft,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 280),
            opacity: collapsed ? 0 : 1,
            child: const Padding(
              padding: EdgeInsets.only(left: 10),
              child: Text(
                'SoundCloud',
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.clip,
                style: TextStyle(
                  color: Color(0xD9FFFFFF),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.35,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Назад / Вперёд / Домой (легаси `NavButtons`). Назад — pop (если есть куда),
/// Вперёд — у стекового роутера истории нет → задизейблен, Домой — на главную.
class _NavButtons extends ConsumerWidget {
  const _NavButtons();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stack = ref.watch(routerProvider);
    final router = ref.read(routerProvider.notifier);
    final accent = ScTheme.paletteOf(context).accent;
    final canBack = stack.length > 1;
    final onHome = stack.last is HomeRoute;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _NavBtn(
          icon: LucideIcons.chevronLeft,
          enabled: canBack,
          onTap: canBack ? router.pop : null,
        ),
        const _NavBtn(icon: LucideIcons.chevronRight, enabled: false),
        _NavBtn(
          icon: LucideIcons.house,
          active: onHome,
          accent: accent,
          onTap: () => router.selectTab(const HomeRoute()),
        ),
      ],
    );
  }
}

class _NavBtn extends StatefulWidget {
  final IconData icon;
  final bool enabled;
  final bool active;
  final Color? accent;
  final VoidCallback? onTap;

  const _NavBtn({
    required this.icon,
    this.enabled = true,
    this.active = false,
    this.accent,
    this.onTap,
  });

  @override
  State<_NavBtn> createState() => _NavBtnState();
}

class _NavBtnState extends State<_NavBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent ?? const Color(0xFFFF5500);
    final Color fg = !widget.enabled
        ? const Color(0x2EFFFFFF)
        : widget.active
            ? const Color(0xFFFFFFFF)
            : (_hover ? const Color(0xFFFFFFFF) : const Color(0x73FFFFFF));
    return MouseRegion(
      cursor:
          widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        child: Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: widget.active
                ? accent.withValues(alpha: 0.12)
                : (_hover && widget.enabled
                    ? const Color(0x14FFFFFF)
                    : const Color(0x00000000)),
            boxShadow: widget.active
                ? [
                    BoxShadow(
                        color: accent.withValues(alpha: 0.25), blurRadius: 16)
                  ]
                : null,
          ),
          child: Icon(widget.icon, size: 17, color: fg),
        ),
      ),
    );
  }
}

/// Глобальный поиск в шапке (легаси `GlobalSearch`): фокусируемое стеклянное поле
/// с accent-свечением на фокусе, единый запрос ([searchQueryProvider]) и выпадашка
/// недавних запросов (персист в settings). Печать ведёт в раздел поиска.
class _HeaderSearch extends ConsumerStatefulWidget {
  const _HeaderSearch();

  @override
  ConsumerState<_HeaderSearch> createState() => _HeaderSearchState();
}

class _HeaderSearchState extends ConsumerState<_HeaderSearch> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  final _link = LayerLink();
  final _portal = OverlayPortalController();
  bool _focused = false;
  double _width = 460;

  @override
  void initState() {
    super.initState();
    _ctrl.text = ref.read(searchQueryProvider);
    _focus.addListener(_onFocus);
    _ctrl.addListener(_refreshPortal);
  }

  @override
  void dispose() {
    _focus.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  void _onFocus() {
    setState(() => _focused = _focus.hasFocus);
    _refreshPortal();
  }

  void _refreshPortal() {
    final show = _focused &&
        _ctrl.text.trim().isEmpty &&
        ref.read(settingsProvider).searchHistory.isNotEmpty;
    show ? _portal.show() : _portal.hide();
  }

  void _goSearch() {
    if (ref.read(routerProvider).last is! SearchRoute) {
      ref.read(routerProvider.notifier).selectTab(const SearchRoute());
    }
  }

  void _onChanged(String v) {
    ref.read(searchQueryProvider.notifier).set(v);
    if (v.trim().isNotEmpty) _goSearch();
    _refreshPortal();
  }

  void _submit() {
    final q = _ctrl.text.trim();
    if (q.isNotEmpty) {
      ref.read(settingsProvider.notifier).addSearchQuery(q);
      _goSearch();
    }
    _focus.unfocus();
  }

  void _pick(String value) {
    _ctrl.text = value;
    ref.read(searchQueryProvider.notifier).set(value);
    ref.read(settingsProvider.notifier).addSearchQuery(value);
    _portal.hide();
    _goSearch();
    _focus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final accent = ScTheme.paletteOf(context).accent;
    final glow = ScTheme.paletteOf(context).accentGlow;
    // Внешняя установка запроса (страница поиска/жанр-сид) → синхронизируем поле.
    ref.listen(searchQueryProvider, (_, next) {
      if (next != _ctrl.text) _ctrl.text = next;
    });
    final hasText = _ctrl.text.isNotEmpty;
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: (_) => _dropdown(),
      child: CompositedTransformTarget(
        link: _link,
        child: LayoutBuilder(
          builder: (context, c) {
            _width = c.maxWidth;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: ScTokens.easeApple,
              height: 44,
              padding: const EdgeInsets.only(left: 16, right: 8),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment(-0.7, -1),
                  end: Alignment(0.7, 1),
                  colors: [
                    Color(0x12FFFFFF),
                    Color(0x06FFFFFF),
                    Color(0x0BFFFFFF)
                  ],
                  stops: [0, 0.6, 1],
                ),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: _focused ? accent : const Color(0x1FFFFFFF),
                  width: 0.5,
                ),
                boxShadow: _focused
                    ? [
                        const BoxShadow(
                            color: Color(0x66000000),
                            blurRadius: 34,
                            offset: Offset(0, 10)),
                        BoxShadow(color: glow, blurRadius: 22),
                      ]
                    : const [
                        BoxShadow(
                            color: Color(0x47000000),
                            blurRadius: 20,
                            offset: Offset(0, 6)),
                      ],
              ),
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  // Верхний specular-блик (inset-x-6, h-px).
                  const Positioned(
                    left: 24,
                    right: 24,
                    top: 0,
                    child: SizedBox(
                      height: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            Color(0x00FFFFFF),
                            Color(0x66FFFFFF),
                            Color(0x00FFFFFF),
                          ]),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Icon(LucideIcons.search,
                          size: 17,
                          color: _focused ? accent : const Color(0x73FFFFFF)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _ctrl,
                          focusNode: _focus,
                          onChanged: _onChanged,
                          onSubmitted: (_) => _submit(),
                          textInputAction: TextInputAction.search,
                          cursorColor: accent,
                          style: const TextStyle(
                              color: Color(0xE6FFFFFF), fontSize: 14),
                          decoration: InputDecoration(
                            isCollapsed: true,
                            border: InputBorder.none,
                            hintText: ref.tr('search.globalPlaceholder'),
                            hintStyle: const TextStyle(
                                color: Color(0x59FFFFFF), fontSize: 14),
                          ),
                        ),
                      ),
                      if (hasText)
                        _ClearBtn(onTap: () {
                          _ctrl.clear();
                          ref.read(searchQueryProvider.notifier).set('');
                          _refreshPortal();
                        })
                      else if (!_focused)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0x0DFFFFFF),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0x1AFFFFFF)),
                          ),
                          child: const Text('Ctrl K',
                              style: TextStyle(
                                  color: Color(0x4DFFFFFF),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'monospace')),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Выпадашка «Недавние запросы» под полем (стеклянная панель).
  Widget _dropdown() {
    return CompositedTransformFollower(
      link: _link,
      targetAnchor: Alignment.bottomLeft,
      followerAnchor: Alignment.topLeft,
      offset: const Offset(0, 8),
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: _width,
          child: Consumer(
            builder: (context, ref, _) {
              final hist =
                  ref.watch(settingsProvider.select((s) => s.searchHistory));
              if (hist.isEmpty) return const SizedBox.shrink();
              return Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xE6101014),
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: const Color(0x1AFFFFFF), width: 0.5),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x8C000000),
                          blurRadius: 60,
                          offset: Offset(0, 24)),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                  ref.tr('search.history').toUpperCase(),
                                  style: const TextStyle(
                                      color: Color(0x4DFFFFFF),
                                      fontSize: 11,
                                      letterSpacing: 0.5)),
                            ),
                            _TextBtn(
                              label: ref.tr('search.clearHistory'),
                              onTap: () => ref
                                  .read(settingsProvider.notifier)
                                  .clearSearchHistory(),
                            ),
                          ],
                        ),
                      ),
                      for (final item in hist.take(8))
                        _HistoryRow(
                          query: item,
                          onTap: () => _pick(item),
                          onRemove: () => ref
                              .read(settingsProvider.notifier)
                              .removeSearchQuery(item),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ClearBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _ClearBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          child: const Icon(LucideIcons.x, size: 15, color: Color(0x73FFFFFF)),
        ),
      ),
    );
  }
}

class _TextBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _TextBtn({required this.label, required this.onTap});

  @override
  State<_TextBtn> createState() => _TextBtnState();
}

class _TextBtnState extends State<_TextBtn> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Text(widget.label,
            style: TextStyle(
                color:
                    _hover ? const Color(0xB3FFFFFF) : const Color(0x59FFFFFF),
                fontSize: 11)),
      ),
    );
  }
}

class _HistoryRow extends StatefulWidget {
  final String query;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  const _HistoryRow(
      {required this.query, required this.onTap, required this.onRemove});

  @override
  State<_HistoryRow> createState() => _HistoryRowState();
}

class _HistoryRowState extends State<_HistoryRow> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: _hover ? const Color(0x0FFFFFFF) : const Color(0x00000000),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(LucideIcons.clock, size: 13, color: Color(0x40FFFFFF)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(widget.query,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Color(0xB3FFFFFF), fontSize: 13)),
              ),
              if (_hover)
                GestureDetector(
                  onTap: widget.onRemove,
                  child: const SizedBox(
                    width: 22,
                    height: 22,
                    child:
                        Icon(LucideIcons.x, size: 13, color: Color(0x73FFFFFF)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
