import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import 'lyrics_line.dart';
import 'lyrics_playhead.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Строка синхронной лирики: время старта (сек) + текст.
class LyricLineData {
  final double timeSecs;
  final String text;

  const LyricLineData({required this.timeSecs, required this.text});
}

/// Что показать в панели лирики.
enum LyricsStatus { loading, synced, plain, notFound }

/// Панель лирики (легаси `LyricsPane` внутри fullscreen `LyricsPanel`). Состояния
/// loading / synced (караоке) / plain / not-found. Источник-бейдж + кнопка
/// ручного поиска. Презентационная: данные и [playhead] для караоке — снаружи.
class LyricsPanel extends StatelessWidget {
  final LyricsStatus status;

  /// Метка источника ("LRCLib"/"AI"/…); пусто — бейдж скрыт.
  final String sourceLabel;

  final List<LyricLineData> syncedLines;
  final String? plainText;

  /// Драйвер караоке (активная строка + прогресс), ~30fps без rebuild списка.
  final ValueListenable<LyricsPlayhead>? playhead;

  /// false (light-перф) → активная строка целиком белая, без per-char sweep.
  final bool perChar;

  final ScrollController? scrollController;

  final String loadingLabel;
  final String notFoundTitle;
  final String notFoundHint;

  final void Function(double seconds)? onSeekLine;
  final VoidCallback? onManualSearch;

  const LyricsPanel({
    super.key,
    required this.status,
    this.sourceLabel = '',
    this.syncedLines = const [],
    this.plainText,
    this.playhead,
    this.perChar = true,
    this.scrollController,
    this.loadingLabel = 'Loading lyrics…',
    this.notFoundTitle = 'No lyrics found',
    this.notFoundHint = 'We could not match this track. Try a manual search.',
    this.onSeekLine,
    this.onManualSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (status == LyricsStatus.synced || status == LyricsStatus.plain) _badgeRow(),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _body() {
    switch (status) {
      case LyricsStatus.loading:
        return _Loading(label: loadingLabel);
      case LyricsStatus.notFound:
        return _NotFound(
          title: notFoundTitle,
          hint: notFoundHint,
          onManualSearch: onManualSearch,
        );
      case LyricsStatus.plain:
        return _PlainLyrics(text: plainText ?? '');
      case LyricsStatus.synced:
        return _SyncedLyrics(
          lines: syncedLines,
          playhead: playhead ?? const _StaticPlayhead(),
          perChar: perChar,
          controller: scrollController,
          onSeekLine: onSeekLine,
        );
    }
  }

  Widget _badgeRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(48, 12, 48, 0),
      child: Row(
        children: [
          if (sourceLabel.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0x0AFFFFFF),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0x0FFFFFFF)),
              ),
              child: Text(
                sourceLabel,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0x33FFFFFF),
                ),
              ),
            )
          else
            const SizedBox.shrink(),
          const Spacer(),
          _RoundIconButton(icon: LucideIcons.search, onTap: onManualSearch),
        ],
      ),
    );
  }
}

/// Фейд-маска списка (легаси `maskImage` linear-gradient).
const _fadeMask = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0x00000000), Color(0xFF000000), Color(0xFF000000), Color(0x00000000)],
  stops: [0, 0.1, 0.9, 1],
);

class _SyncedLyrics extends StatelessWidget {
  final List<LyricLineData> lines;
  final ValueListenable<LyricsPlayhead> playhead;
  final bool perChar;
  final ScrollController? controller;
  final void Function(double seconds)? onSeekLine;

  const _SyncedLyrics({
    required this.lines,
    required this.playhead,
    required this.perChar,
    required this.controller,
    required this.onSeekLine,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: _fadeMask.createShader,
      blendMode: BlendMode.dstIn,
      child: ListView.builder(
        controller: controller,
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 64),
        itemCount: lines.length,
        itemBuilder: (_, i) => LyricsLine(
          text: lines[i].text,
          index: i,
          playhead: playhead,
          perChar: perChar,
          onTap: () => onSeekLine?.call(lines[i].timeSecs),
        ),
      ),
    );
  }
}

class _PlainLyrics extends StatelessWidget {
  final String text;

  const _PlainLyrics({required this.text});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: _fadeMask.createShader,
      blendMode: BlendMode.dstIn,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 64),
        child: SelectableText(
          text,
          style: const TextStyle(
            fontSize: 22,
            height: 1.8,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
            color: Color(0xB3FFFFFF), // 0.70
          ),
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  final String label;

  const _Loading({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0x26FFFFFF)),
          ),
          const SizedBox(height: 12),
          Text(label, style: const TextStyle(fontSize: 13, color: Color(0x40FFFFFF))),
        ],
      ),
    );
  }
}

class _NotFound extends StatelessWidget {
  final String title;
  final String hint;
  final VoidCallback? onManualSearch;

  const _NotFound({required this.title, required this.hint, required this.onManualSearch});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          right: 12,
          top: 12,
          child: _RoundIconButton(icon: LucideIcons.search, onTap: onManualSearch),
        ),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.mic, size: 40, color: Color(0x0FFFFFFF)),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Color(0x4DFFFFFF),
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: Text(
                  hint,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, height: 1.5, color: Color(0x26FFFFFF)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoundIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  State<_RoundIconButton> createState() => _RoundIconButtonState();
}

class _RoundIconButtonState extends State<_RoundIconButton> {
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
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _hover ? const Color(0x1AFFFFFF) : const Color(0x00000000),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(
            widget.icon,
            size: 14,
            color: _hover ? const Color(0xB3FFFFFF) : const Color(0x4DFFFFFF),
          ),
        ),
      ),
    );
  }
}

/// Заглушка плейхеда (синхронная лирика без активного драйвера: показываем
/// статичный список в состоянии "next").
class _StaticPlayhead implements ValueListenable<LyricsPlayhead> {
  const _StaticPlayhead();

  @override
  LyricsPlayhead get value => const LyricsPlayhead();

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}
