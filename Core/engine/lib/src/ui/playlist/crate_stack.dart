import 'package:flutter/material.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../rust/api.dart';

/// Сид-веер: индекс 0 — передний рукав, остальные веером за ним. Без рандома
/// (§3.8: фиксированная 5-строчная таблица). rot/x/y/scale/z.
const _fan = <(double rot, double x, double y, double scale, int z)>[
  (0, 0, 0, 1.0, 50),
  (6, 17, 7, 0.965, 40),
  (-7, -17, 9, 0.95, 30),
  (11, 31, 15, 0.93, 20),
  (-12, -31, 17, 0.91, 10),
];

const _sleeveShadow = <BoxShadow>[
  BoxShadow(color: Color(0x80000000), blurRadius: 50, offset: Offset(0, 24)),
];

/// «Ящик» (The Crate): развёрнутый веером стек реальных обложек треков —
/// коллекция, ставшая видимой, не один диск. Клик = играть сет. Передний рукав
/// несёт play-оверлей и счётчик треков.
class CrateStack extends StatefulWidget {
  final String title;
  final String? playlistArtworkUrl;
  final List<TrackDto> tracks;
  final bool playing;
  final int trackCount;
  final VoidCallback? onPlay;

  const CrateStack({
    super.key,
    required this.title,
    required this.playlistArtworkUrl,
    required this.tracks,
    required this.playing,
    required this.trackCount,
    this.onPlay,
  });

  @override
  State<CrateStack> createState() => _CrateStackState();
}

class _CrateStackState extends State<CrateStack> {
  bool _hover = false;

  List<String> _covers(int max) {
    final urls = <String>[];
    final seen = <String>{};
    void push(String? u) {
      final r = artUrl(u, ArtSize.row);
      if (r.isNotEmpty && !seen.contains(r)) {
        seen.add(r);
        urls.add(r);
      }
    }

    push(widget.playlistArtworkUrl);
    for (final tr in widget.tracks) {
      if (urls.length >= max) break;
      push(tr.artworkUrl);
    }
    return urls.take(max).toList();
  }

  @override
  Widget build(BuildContext context) {
    final mode = ScPerf.of(context);
    final max = mode == PerfMode.light
        ? 1
        : mode == PerfMode.medium
            ? 3
            : 5;
    final covers = _covers(max);
    final size = MediaQuery.sizeOf(context).width < 768 ? 150.0 : 200.0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onPlay,
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (covers.isEmpty) _placeholder(),
              for (int i = covers.length - 1; i >= 0; i--)
                _sleeve(covers[i], i),
              Positioned(bottom: -8, right: -4, child: _countPill()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0x0AFFFFFF),
          borderRadius: BorderRadius.circular(27.2), // rounded-[1.7rem]
          boxShadow: _sleeveShadow,
        ),
        child: const Center(
          child: Icon(LucideIcons.listMusic, size: 56, color: Color(0x26FFFFFF)),
        ),
      ),
    );
  }

  Widget _sleeve(String url, int index) {
    final f = index < _fan.length ? _fan[index] : _fan.last;
    final isFront = index == 0;
    final radius = BorderRadius.circular(27.2);
    final transform = Matrix4.identity()
      ..translateByDouble(f.$2, f.$3, 0, 1)
      ..rotateZ(f.$1 * 3.1415926535 / 180)
      ..scaleByDouble(f.$4, f.$4, 1, 1);

    Widget img = Image(
      image: ScImageProxy.provider(url),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0x0AFFFFFF)),
    );
    if (isFront) {
      img = AnimatedScale(
        scale: _hover ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 700),
        curve: ScTokens.easeApple,
        child: img,
      );
    }

    return Positioned.fill(
      child: Transform(
        alignment: Alignment.center,
        transform: transform,
        child: DecoratedBox(
          decoration: BoxDecoration(borderRadius: radius, boxShadow: _sleeveShadow),
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              fit: StackFit.expand,
              children: [
                img,
                if (isFront) _frontOverlay(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _frontOverlay() {
    final visible = _hover || widget.playing;
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: ScTokens.dSidebar,
      child: ColoredBox(
        color: Color(widget.playing ? 0x40000000 : 0x4D000000),
        child: Center(
          child: AnimatedScale(
            scale: visible ? 1.0 : 0.75,
            duration: ScTokens.dSidebar,
            curve: ScTokens.easeApple,
            child: Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFFFFFFFF),
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.playing ? LucideIcons.pause : LucideIcons.play,
                size: 26,
                color: const Color(0xFF000000),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _countPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xBF0A0A0C),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x24FFFFFF), width: 0.5),
        boxShadow: const [
          BoxShadow(color: Color(0x66000000), blurRadius: 20, offset: Offset(0, 8)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.listMusic, size: 10, color: Color(0xD9FFFFFF)),
          const SizedBox(width: 4),
          Text(
            '${widget.trackCount}',
            style: const TextStyle(
              color: Color(0xD9FFFFFF),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
