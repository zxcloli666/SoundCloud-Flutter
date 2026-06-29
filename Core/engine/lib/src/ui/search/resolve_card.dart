import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers.dart';
import '../../rust/api.dart';

/// Карточка резолва вставленной SoundCloud-ссылки (легаси `ResolveCard`):
/// крутилка пока [resolveUrlProvider] думает, карточка трека с Play/Открыть при
/// успехе, мягкий алерт когда ссылка не указывает на трек.
class ResolveCard extends ConsumerWidget {
  final String url;
  final ValueChanged<String> onOpenTrack;
  final ValueChanged<TrackDto> onPlay;

  const ResolveCard({
    super.key,
    required this.url,
    required this.onOpenTrack,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(resolveUrlProvider(url));
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: GlassPanel(
        padding: const EdgeInsets.all(20),
        child: async.when(
          loading: () => _pending(),
          error: (_, __) => _notTrack(),
          data: (track) => track == null ? _notTrack() : _resolved(track),
        ),
      ),
    );
  }

  Widget _pending() {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(width: 14),
        Flexible(
          child: Text(
            'Разбираю ссылку SoundCloud…',
            style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 13.5),
          ),
        ),
      ],
    );
  }

  Widget _notTrack() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(LucideIcons.circleAlert,
                size: 18, color: Color(0xCCFF6B6B)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Это не трек',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Ссылка не указывает на трек либо недоступна. Откройте её в браузере '
          'или вставьте прямую ссылку на трек.',
          style: TextStyle(color: Color(0x99FFFFFF), fontSize: 12.5, height: 1.4),
        ),
        const SizedBox(height: 14),
        _GlowButton(
          icon: LucideIcons.externalLink,
          label: 'Открыть в браузере',
          onTap: _openExternally,
        ),
      ],
    );
  }

  Widget _resolved(TrackDto track) {
    return Builder(builder: (context) {
      final accent = ScTheme.paletteOf(context).accent;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _artwork(track),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      track.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          height: 1.25),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      track.artistName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: accent.withValues(alpha: 0.9), fontSize: 12.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatDuration(track.durationMs.toInt()),
                      style: const TextStyle(
                          color: Color(0x73FFFFFF), fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _GlowButton(
                  icon: LucideIcons.play,
                  label: 'Слушать',
                  filled: true,
                  onTap: () => onPlay(track),
                ),
              ),
              const SizedBox(width: 10),
              _GlowButton(
                icon: Icons.open_in_full_rounded,
                label: 'Открыть',
                onTap: () => onOpenTrack(track.urn),
              ),
            ],
          ),
        ],
      );
    });
  }

  Widget _artwork(TrackDto track) {
    final url = track.artworkUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 72,
        height: 72,
        color: const Color(0x14FFFFFF),
        alignment: Alignment.center,
        child: url == null || url.isEmpty
            ? const Icon(LucideIcons.music,
                size: 26, color: Color(0x59FFFFFF))
            : Image(
                image: ScImageProxy.provider(url),
                width: 72,
                height: 72,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                    LucideIcons.music,
                    size: 26,
                    color: Color(0x59FFFFFF)),
              ),
      ),
    );
  }

  Future<void> _openExternally() async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// Маленькая стеклянная/акцентная кнопка действия карточки.
class _GlowButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _GlowButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  @override
  State<_GlowButton> createState() => _GlowButtonState();
}

class _GlowButtonState extends State<_GlowButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final accent = ScTheme.paletteOf(context).accent;
    final bg = widget.filled
        ? accent.withValues(alpha: _hover ? 0.28 : 0.20)
        : (_hover ? const Color(0x14FFFFFF) : const Color(0x0AFFFFFF));
    final fg = widget.filled ? Colors.white : const Color(0xCCFFFFFF);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: ScTokens.dFast,
          curve: ScTokens.easeApple,
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: widget.filled ? accent.withValues(alpha: 0.5) : const Color(0x1AFFFFFF),
              width: 0.5,
            ),
            boxShadow: widget.filled && _hover
                ? [BoxShadow(color: accent.withValues(alpha: 0.25), blurRadius: 16)]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 16, color: fg),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                    color: fg, fontSize: 12.5, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
