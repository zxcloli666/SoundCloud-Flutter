import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show KeyDownEvent, LogicalKeyboardKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../../providers.dart';
import '../../../rust/api.dart';
import 'equalizer_host.dart';
import 'lyrics_host.dart';
import 'queue_host.dart';

/// Единый оверлей инструмент-панелей NowBar (DRY): по [nowBarPanelProvider]
/// рисует EQ (центр-модалка) / очередь (правый док) / лирику (фуллскрин).
/// Скрим-клик и Esc закрывают активную панель. Монтируется в шелле поверх всего.
class NowBarPanelHost extends ConsumerWidget {
  const NowBarPanelHost({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final panel = ref.watch(nowBarPanelProvider);
    if (panel == NowBarPanel.none) return const SizedBox.shrink();

    final close = ref.read(nowBarPanelProvider.notifier).close;
    final track = ref.watch(playerProvider);

    // Esc закрывает; скрим-клик ловится снизу. Focus-узел берёт клавиатуру сразу.
    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          close();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Stack(
        children: [
          Positioned.fill(child: _Scrim(panel: panel, onTap: close)),
          _content(context, ref, panel, track, close),
        ],
      ),
    );
  }

  Widget _content(
    BuildContext context,
    WidgetRef ref,
    NowBarPanel panel,
    TrackDto? track,
    VoidCallback close,
  ) {
    switch (panel) {
      case NowBarPanel.equalizer:
        // Центр-модалка md (легаси `ModalContent size="md"`): фикс-ширина, клик
        // по самой панели не закрывает (поглощается).
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _Stop(child: EqualizerHost(onClose: close)),
            ),
          ),
        );
      case NowBarPanel.queue:
        // Правый стеклянный drawer 360px во всю высоту окна (легаси
        // `top-0 right-0 bottom-0`); панель сама анимирует въезд.
        return Align(
          alignment: Alignment.centerRight,
          child: FractionallySizedBox(
            heightFactor: 1,
            alignment: Alignment.centerRight,
            child: _Stop(child: QueueHost(onClose: close)),
          ),
        );
      case NowBarPanel.lyrics:
        if (track == null) return const SizedBox.shrink();
        return _Stop(
          child: _LyricsFullscreen(urn: track.urn, onClose: close),
        );
      case NowBarPanel.none:
        return const SizedBox.shrink();
    }
  }
}

/// Затемнение-скрим под панелью. Для фуллскрин-лирики он непрозрачный (контент
/// не просвечивает); для EQ/очереди — лёгкая вуаль с блюром (легаси backdrop).
class _Scrim extends StatelessWidget {
  final NowBarPanel panel;
  final VoidCallback onTap;

  const _Scrim({required this.panel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (panel == NowBarPanel.lyrics) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: const ColoredBox(color: Color(0xFF08080A)),
      );
    }
    final blur = ScPerf.of(context) == PerfMode.light ? 0.0 : 4.0;
    Widget veil = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: const ColoredBox(color: Color(0x66000000)),
    );
    if (blur > 0) {
      veil = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: veil,
      );
    }
    return veil;
  }
}

/// Поглощает тапы по самой панели, чтобы скрим-клик её не закрывал.
class _Stop extends StatelessWidget {
  final Widget child;

  const _Stop({required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: child,
    );
  }
}

/// Фуллскрин-лирика (легаси `LyricsPanel`): иммерсивный фон + парящая кнопка
/// закрытия сверху-справа + тело [LyricsHost].
class _LyricsFullscreen extends StatelessWidget {
  final String urn;
  final VoidCallback onClose;

  const _LyricsFullscreen({required this.urn, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: LyricsHost(urn: urn)),
        Positioned(
          top: 16,
          right: 16,
          child: _CloseButton(onTap: onClose),
        ),
      ],
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _hover ? const Color(0x1AFFFFFF) : const Color(0x0AFFFFFF),
            shape: BoxShape.circle,
            border: Border.all(color: ScTokens.glassBorder),
          ),
          alignment: Alignment.center,
          child: Icon(
            LucideIcons.x,
            size: 16,
            color: _hover ? const Color(0xB3FFFFFF) : const Color(0x4DFFFFFF),
          ),
        ),
      ),
    );
  }
}
