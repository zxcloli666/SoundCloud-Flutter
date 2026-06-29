import 'package:flutter/material.dart';
import 'package:sc_visual/sc_visual.dart';

import 'offline_pulse.dart';
import 'storage_module.dart' show CacheLikesProgress;

/// CTA «скачать все лайки»: кнопка-старт с остатком, либо прогресс-полоса
/// (заливка + sheen + done/total + отмена), либо строка «все лайки в кэше».
class CacheLikesCta extends StatelessWidget {
  final bool caching;
  final CacheLikesProgress? progress;
  final int remaining;
  final VoidCallback onStart;
  final VoidCallback onCancel;

  const CacheLikesCta({
    super.key,
    required this.caching,
    required this.progress,
    required this.remaining,
    required this.onStart,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    if (!caching) {
      if (remaining == 0) {
        return const SizedBox(
          height: 40,
          child: Row(
            children: [
              Icon(LucideIcons.check, size: 13, color: Color(0xB3A7F3D0)),
              SizedBox(width: 8),
              Text(
                'все лайки в кэше',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xB3A7F3D0),
                ),
              ),
            ],
          ),
        );
      }
      return _StartButton(remaining: remaining, onTap: onStart);
    }

    final palette = ScTheme.paletteOf(context);
    final p = progress;
    final pct =
        p != null && p.total > 0 ? (p.done / p.total).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Stack(
            children: [
              Positioned.fill(
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: pct,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [palette.accentGlow, palette.accentSelection],
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: palette.accentGlow),
                ),
                child: Row(
                  children: [
                    OfflinePulse(
                      active: true,
                      period: const Duration(milliseconds: 1600),
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                            color: palette.accentHover, shape: BoxShape.circle),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      p != null ? 'качаю' : 'старт',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xE6FFFFFF),
                      ),
                    ),
                    const Spacer(),
                    if (p != null)
                      Text(
                        '${p.done} / ${p.total}',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: palette.accentHover,
                        ),
                      ),
                    const SizedBox(width: 8),
                    _CancelButton(onTap: onCancel),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (p != null && p.failed > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                const Text('докачка',
                    style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10.5,
                        color: Color(0x4DFFFFFF))),
                const Spacer(),
                Text('ошибок ${p.failed}',
                    style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10.5,
                        color: Color(0xCCFDA4AF))),
              ],
            ),
          ),
      ],
    );
  }
}

class _StartButton extends StatefulWidget {
  final int remaining;
  final VoidCallback onTap;

  const _StartButton({required this.remaining, required this.onTap});

  @override
  State<_StartButton> createState() => _StartButtonState();
}

class _StartButtonState extends State<_StartButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final palette = ScTheme.paletteOf(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: _hover ? const Color(0x0AFFFFFF) : const Color(0x05FFFFFF),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: palette.accentGlow),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.download, size: 13, color: palette.accentHover),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'скачать все лайки',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xD9FFFFFF),
                  ),
                ),
              ),
              Text(
                '${widget.remaining}',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: palette.accentHover,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CancelButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CancelButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(shape: BoxShape.circle),
          child:
              const Icon(LucideIcons.x, size: 12, color: Color(0x73FFFFFF)),
        ),
      ),
    );
  }
}
