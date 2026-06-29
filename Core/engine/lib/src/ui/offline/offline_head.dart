import 'package:flutter/material.dart';
import 'package:sc_visual/sc_visual.dart';

import 'offline_pulse.dart';

/// Шапка «Кузницы»: кикер + заголовок слева, статус сети / очередь синка справа.
class OfflineHead extends StatelessWidget {
  final bool online;
  final int pendingSync;
  final int failedSync;
  final VoidCallback onTryOnline;

  const OfflineHead({
    super.key,
    required this.online,
    required this.onTryOnline,
    this.pendingSync = 0,
    this.failedSync = 0,
  });

  @override
  Widget build(BuildContext context) {
    final accentGlow = ScTheme.paletteOf(context).accentGlow;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ОФЛАЙН · КУЗНИЦА',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.4,
                  color: Color(0x4DFFFFFF),
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Библиотека',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -1.3,
                  height: 1,
                  color: Color(0xF0FFFFFF),
                ),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (pendingSync > 0 || failedSync > 0) _syncPill(accentGlow),
            _netPill(),
            if (!online) _tryOnlineBtn(),
          ],
        ),
      ],
    );
  }

  Widget _syncPill(Color accentGlow) {
    return _Pill(
      border: accentGlow,
      background: accentGlow,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.clock, size: 11, color: Color(0xB3FFFFFF)),
          const SizedBox(width: 6),
          Text(
            'В очереди: $pendingSync',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: Color(0xB3FFFFFF),
            ),
          ),
          if (failedSync > 0)
            Text(
              ' · ошибок $failedSync',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 10.5,
                color: Color(0xCCFB7185),
              ),
            ),
        ],
      ),
    );
  }

  Widget _netPill() {
    final color = online ? const Color(0xD9A7F3D0) : const Color(0xD9BAE6FD);
    final bg = online ? const Color(0x127EE7B0) : const Color(0x1238BDF8);
    return _Pill(
      border: bg,
      background: bg,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OfflinePulse(
            active: online,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 8),
          Icon(online ? Icons.wifi_rounded : Icons.wifi_off_rounded,
              size: 11, color: color),
          const SizedBox(width: 6),
          Text(
            online ? 'ОНЛАЙН' : 'ОФЛАЙН',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.2,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tryOnlineBtn() {
    return _HoverPill(
      onTap: onTryOnline,
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.rotateCw, size: 12, color: Color(0xBFFFFFFF)),
          SizedBox(width: 8),
          Text(
            'Попробовать онлайн',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xBFFFFFFF),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final Color border;
  final Color background;
  final Widget child;

  const _Pill({required this.border, required this.background, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: child,
    );
  }
}

class _HoverPill extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;

  const _HoverPill({required this.onTap, required this.child});

  @override
  State<_HoverPill> createState() => _HoverPillState();
}

class _HoverPillState extends State<_HoverPill> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: ScTokens.dFast,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: _hover ? const Color(0x17FFFFFF) : const Color(0x0DFFFFFF),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
                color: _hover ? const Color(0x29FFFFFF) : const Color(0x1AFFFFFF)),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
