import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers.dart';
import '../rust/api.dart' show hostRecheck;

const _boostyUrl = 'https://boosty.to/lolinamide';
const _discordUrl = 'https://discord.gg/xQcGBP8fGG';
const _amber = Color(0xFFFBBF24);
const _purpleGlow = Color(0x80A855F7);

/// Оверлей failover-состояния хостов (порт легаси `HostStatusModal`/`Banner`):
/// premium на резерве → стеклянный баннер; main лёг без подписки → модалка
/// «оформи STAR»; оба легли → модалка «оффлайн-библиотека». Статус — из ядра
/// ([hostStatusProvider]), выбор UI — [failoverUiProvider]. Поверх всего шелла.
class HostStatusOverlay extends ConsumerStatefulWidget {
  const HostStatusOverlay({super.key});

  @override
  ConsumerState<HostStatusOverlay> createState() => _HostStatusOverlayState();
}

class _HostStatusOverlayState extends ConsumerState<HostStatusOverlay> {
  bool _outageDismissed = false;
  bool _bannerHidden = false;

  @override
  Widget build(BuildContext context) {
    // Оверлей — сосед AppShell (вне его Material), поэтому свой прозрачный
    // Material: иначе текст рисуется с дефолтным жёлтым подчёркиванием.
    return Material(
      type: MaterialType.transparency,
      child: _content(context),
    );
  }

  Widget _content(BuildContext context) {
    final ui = ref.watch(failoverUiProvider);
    // Вернулись в норму — сбрасываем «закрыто», чтобы новый инцидент показался.
    if (ui == FailoverUi.none) {
      if (_outageDismissed || _bannerHidden) {
        _outageDismissed = false;
        _bannerHidden = false;
      }
      return const SizedBox.shrink();
    }
    final accent = ScTheme.paletteOf(context).accent;

    if (ui == FailoverUi.starActive) {
      if (_bannerHidden) return const SizedBox.shrink();
      return _Banner.viaStar(
        text: ref.tr('failover.banner.viaStar'),
        onClose: () => setState(() => _bannerHidden = true),
      );
    }

    if (_outageDismissed) {
      return _Banner.outage(
        text: ref.tr('failover.banner.outage'),
        details: ref.tr('failover.banner.details'),
        onDetails: () => setState(() => _outageDismissed = false),
      );
    }

    final allDown = ui == FailoverUi.allDown;
    return _Modal(
      allDown: allDown,
      accent: accent,
      title: ref
          .tr(allDown ? 'failover.allDown.title' : 'failover.starOffer.title'),
      body:
          ref.tr(allDown ? 'failover.allDown.body' : 'failover.starOffer.body'),
      how: allDown ? null : ref.tr('failover.starOffer.how'),
      buyLabel: ref.tr('failover.actions.buyStar'),
      offlineLabel: ref.tr('failover.actions.offlineLibrary'),
      retryLabel: ref.tr('failover.actions.retry'),
      onBuy: () =>
          ref.read(routerProvider.notifier).selectTab(const StarRoute()),
      onOffline: () {
        ref.read(routerProvider.notifier).selectTab(const OfflineRoute());
        setState(() => _outageDismissed = true);
      },
      onClose: () => setState(() => _outageDismissed = true),
    );
  }
}

// ─────────────────────────── Модалка ───────────────────────────

class _Modal extends StatelessWidget {
  final bool allDown;
  final Color accent;
  final String title;
  final String body;
  final String? how;
  final String buyLabel;
  final String offlineLabel;
  final String retryLabel;
  final VoidCallback onBuy;
  final VoidCallback onOffline;
  final VoidCallback onClose;

  const _Modal({
    required this.allDown,
    required this.accent,
    required this.title,
    required this.body,
    required this.how,
    required this.buyLabel,
    required this.offlineLabel,
    required this.retryLabel,
    required this.onBuy,
    required this.onOffline,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final glow = ScTheme.paletteOf(context).accentGlow;
    return Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: Color(0x99000000))),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              margin: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xF717161C), Color(0xFC0A090D)],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0x1FFFFFFF), width: 0.5),
                boxShadow: [
                  const BoxShadow(
                      color: Color(0x9E000000),
                      blurRadius: 110,
                      offset: Offset(0, 40)),
                  BoxShadow(color: glow, blurRadius: 80),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Stack(
                  children: [
                    // Верхний specular-блик.
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
                              Color(0x47FFFFFF),
                              Color(0x00FFFFFF),
                            ]),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _iconTile(),
                          const SizedBox(height: 16),
                          Text(title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Color(0xE6FFFFFF),
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.3)),
                          const SizedBox(height: 6),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 300),
                            child: Text(body,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Color(0x59FFFFFF),
                                    fontSize: 12.5,
                                    height: 1.5)),
                          ),
                          if (how != null) ...[
                            const SizedBox(height: 12),
                            Text(how!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Color(0x73FFFFFF), fontSize: 11.5)),
                          ],
                          const SizedBox(height: 10),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (!allDown) ...[
                                _LinkPill(
                                    label: 'Boosty',
                                    accent: accent,
                                    url: _boostyUrl),
                                const SizedBox(width: 8),
                              ],
                              _LinkPill(
                                  label: 'Discord',
                                  accent: accent,
                                  url: _discordUrl),
                            ],
                          ),
                          const SizedBox(height: 24),
                          if (!allDown)
                            _BigButton(
                              label: buyLabel,
                              icon: Icons.star_rounded,
                              accent: accent,
                              filled: true,
                              onTap: onBuy,
                            ),
                          if (!allDown) const SizedBox(height: 10),
                          _BigButton(
                            label: offlineLabel,
                            icon: LucideIcons.download,
                            accent: accent,
                            filled: allDown,
                            onTap: onOffline,
                          ),
                          const SizedBox(height: 10),
                          _RetryButton(label: retryLabel),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 14,
                      right: 14,
                      child: _CloseButton(onTap: onClose),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _iconTile() {
    return Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x0FFFFFFF), Color(0x05FFFFFF)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x14FFFFFF), width: 0.5),
        boxShadow: const [
          BoxShadow(color: Color(0x4D000000), blurRadius: 20),
        ],
      ),
      child: allDown
          ? const Icon(LucideIcons.wifiOff, size: 24, color: Color(0x99FFFFFF))
          : Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: _purpleGlow, blurRadius: 8)],
              ),
              child: const Icon(Icons.star_rounded, size: 26, color: _amber),
            ),
    );
  }
}

// ─────────────────────────── Кнопки ───────────────────────────

class _BigButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color accent;
  final bool filled;
  final VoidCallback onTap;

  const _BigButton({
    required this.label,
    required this.icon,
    required this.accent,
    required this.filled,
    required this.onTap,
  });

  @override
  State<_BigButton> createState() => _BigButtonState();
}

class _BigButtonState extends State<_BigButton> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final filled = widget.filled;
    final Color bg = filled
        ? widget.accent.withValues(alpha: _hover ? 1 : 0.92)
        : (_hover ? const Color(0x14FFFFFF) : const Color(0x0AFFFFFF));
    final Color fg = filled
        ? Colors.white
        : (_hover ? const Color(0xCCFFFFFF) : const Color(0x8CFFFFFF));
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 0.97 : 1,
          duration: const Duration(milliseconds: 120),
          child: Container(
            width: double.infinity,
            height: filled ? 46 : 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              border: filled
                  ? null
                  : Border.all(color: const Color(0x0FFFFFFF), width: 0.5),
              boxShadow: filled
                  ? [
                      BoxShadow(
                          color: widget.accent.withValues(alpha: 0.4),
                          blurRadius: 30),
                      const BoxShadow(
                          color: Color(0x4D000000),
                          blurRadius: 8,
                          offset: Offset(0, 2)),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, size: 15, color: fg),
                const SizedBox(width: 8),
                Text(widget.label,
                    style: TextStyle(
                        color: fg, fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Кнопка «Проверить снова» со спином на время перепроверки.
class _RetryButton extends StatefulWidget {
  final String label;
  const _RetryButton({required this.label});

  @override
  State<_RetryButton> createState() => _RetryButtonState();
}

class _RetryButtonState extends State<_RetryButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  bool _hover = false;

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  Future<void> _retry() async {
    _spin.repeat();
    try {
      await hostRecheck();
    } catch (_) {}
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (mounted) {
      _spin.stop();
      _spin.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color fg = _hover ? const Color(0xCCFFFFFF) : const Color(0x8CFFFFFF);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: _retry,
        child: Container(
          width: double.infinity,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _hover ? const Color(0x14FFFFFF) : const Color(0x0AFFFFFF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x0FFFFFFF), width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              RotationTransition(
                turns: _spin,
                child: Icon(LucideIcons.refreshCw, size: 13, color: fg),
              ),
              const SizedBox(width: 7),
              Text(widget.label,
                  style: TextStyle(
                      color: fg, fontSize: 12.5, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CloseButton extends StatefulWidget {
  final VoidCallback onTap;
  const _CloseButton({required this.onTap});

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
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
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _hover ? const Color(0x10FFFFFF) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(LucideIcons.x,
              size: 14,
              color:
                  _hover ? const Color(0x99FFFFFF) : const Color(0x33FFFFFF)),
        ),
      ),
    );
  }
}

class _LinkPill extends StatefulWidget {
  final String label;
  final Color accent;
  final String url;
  const _LinkPill(
      {required this.label, required this.accent, required this.url});

  @override
  State<_LinkPill> createState() => _LinkPillState();
}

class _LinkPillState extends State<_LinkPill> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => launchUrl(Uri.parse(widget.url),
            mode: LaunchMode.externalApplication),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.accent.withValues(alpha: 0.22),
                Colors.transparent
              ],
            ),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
                color: widget.accent.withValues(alpha: 0.3), width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.label,
                  style: TextStyle(
                      color: widget.accent.withValues(alpha: _hover ? 1 : 0.85),
                      fontSize: 11,
                      fontWeight: FontWeight.w500)),
              const SizedBox(width: 4),
              Icon(LucideIcons.externalLink,
                  size: 10, color: widget.accent.withValues(alpha: 0.85)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── Баннер ───────────────────────────

class _Banner extends StatelessWidget {
  final String text;
  final bool viaStar;
  final String? details;
  final VoidCallback? onClose;
  final VoidCallback? onDetails;

  const _Banner._({
    required this.text,
    required this.viaStar,
    this.details,
    this.onClose,
    this.onDetails,
  });

  factory _Banner.viaStar(
          {required String text, required VoidCallback onClose}) =>
      _Banner._(text: text, viaStar: true, onClose: onClose);

  factory _Banner.outage(
          {required String text,
          required String details,
          required VoidCallback onDetails}) =>
      _Banner._(
          text: text, viaStar: false, details: details, onDetails: onDetails);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 64),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0x478B5CF6), Color(0x1F581C87)],
            ),
            color: const Color(0xF0121018),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0x59A855F7), width: 0.5),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x73000000),
                  blurRadius: 24,
                  offset: Offset(0, 8)),
              BoxShadow(color: Color(0x388B5CF6), blurRadius: 16),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (viaStar) ...[
                Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: _purpleGlow, blurRadius: 4)],
                  ),
                  child:
                      const Icon(Icons.star_rounded, size: 13, color: _amber),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Color(0xD9FFFFFF),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500)),
              ),
              const SizedBox(width: 8),
              if (viaStar)
                _BannerClose(onTap: onClose!)
              else
                _DetailsBtn(label: details!, onTap: onDetails!),
            ],
          ),
        ),
      ),
    );
  }
}

class _BannerClose extends StatelessWidget {
  final VoidCallback onTap;
  const _BannerClose({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          child: const Icon(LucideIcons.x, size: 12, color: Color(0x73FFFFFF)),
        ),
      ),
    );
  }
}

class _DetailsBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _DetailsBtn({required this.label, required this.onTap});

  @override
  State<_DetailsBtn> createState() => _DetailsBtnState();
}

class _DetailsBtnState extends State<_DetailsBtn> {
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: _hover ? const Color(0x1FFFFFFF) : const Color(0x0FFFFFFF),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(widget.label,
              style: TextStyle(
                  color: _hover ? Colors.white : const Color(0xE6D8B4FE),
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
