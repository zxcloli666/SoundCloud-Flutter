import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../providers.dart';
import '../../rust/dto.dart';
import '../../rust/dto_social.dart';

/// «В центре внимания» (легаси §3.3 `DiscoverSpotlight`): горизонтальная лента
/// курируемых промо-карточек 280×360 — артисты и альбомы вперемешку. Источник —
/// `discoverSpotlightProvider` (`/discover/spotlight`), без пагинации.
class DiscoverSpotlight extends ConsumerWidget {
  const DiscoverSpotlight({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(discoverSpotlightProvider);
    return async.maybeWhen(
      data: (feed) =>
          feed.items.isEmpty ? const SizedBox.shrink() : _section(ref, feed.items),
      loading: () => _section(ref, const [], loading: true),
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _section(WidgetRef ref, List<SpotlightItemDto> items,
      {bool loading = false}) {
    final accent = ScTheme.paletteOf(ref.context).accent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(ref, accent, loading ? null : items.length),
        const SizedBox(height: 16),
        SizedBox(
          height: 360,
          child: loading
              ? ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  itemCount: 4,
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                  itemBuilder: (_, __) => const SizedBox(
                    width: 280,
                    child: Skeleton(rounded: SkeletonRound.lg),
                  ),
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                  itemBuilder: (_, i) => switch (items[i]) {
                    SpotlightItemDto_Artist(:final field0) =>
                      _ArtistSpotlightCard(artist: field0),
                    SpotlightItemDto_Album(:final field0) =>
                      _AlbumSpotlightCard(album: field0),
                  },
                ),
        ),
      ],
    );
  }

  Widget _header(WidgetRef ref, Color accent, int? count) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [accent.withValues(alpha: 0.28), accent.withValues(alpha: 0.04)],
              ),
              border: Border.all(color: accent.withValues(alpha: 0.4)),
            ),
            child: const Icon(LucideIcons.sparkles, size: 14, color: Color(0xD9FFFFFF)),
          ),
          const SizedBox(width: 12),
          Text(
            ref.tr('discover.spotlightTitle'),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xF2FFFFFF),
              letterSpacing: -0.2,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 8),
            Text(
              '$count',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0x4DFFFFFF),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

const _kCardRadius = 28.0; // rounded-[1.75rem]

/// Промо-карточка альбома: обложка во всю карту + нижний градиент с мета.
class _AlbumSpotlightCard extends ConsumerWidget {
  final AlbumCardDto album;

  const _AlbumSpotlightCard({required this.album});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = ScTheme.paletteOf(context).accent;
    final radius = BorderRadius.circular(_kCardRadius);
    final g = gradientForId(album.id, 3);
    final ms = album.totalDurationMs?.toInt() ?? 0;
    final meta = <String>[
      '${album.trackCount}',
      if (ms > 0) formatDurationLong(ms),
      if (album.releaseYear != null) '${album.releaseYear}',
    ];

    return _CardShell(
      radius: radius,
      onTap: () =>
          ref.read(routerProvider.notifier).push(AlbumRoute(album.id)),
      glow: accent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: g,
              ),
            ),
          ),
          if (album.coverUrl != null)
            TrackArtwork(url: album.coverUrl, size: ArtSize.hero),
          // Нижний градиент под текст.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: [Color(0x00000000), Color(0xB3000000)],
              ),
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            child: _Badge(
              icon: LucideIcons.disc3,
              text: _kindLabel(album.trackCount),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  album.primaryArtist.name.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xD9FFFFFF),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  album.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFFFFFFF),
                    fontSize: 22,
                    height: 0.95,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  meta.join('  ·  '),
                  style: const TextStyle(
                    color: Color(0xBFFFFFFF),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _kindLabel(int n) {
    if (n <= 1) return 'Сингл';
    if (n <= 4) return 'EP';
    if (n >= 10) return 'Сборник';
    return 'Альбом';
  }
}

/// Промо-карточка артиста: aura-радиал, круглый аватар, имя/страна/теги, слушатели.
class _ArtistSpotlightCard extends ConsumerWidget {
  final ArtistCardDto artist;

  const _ArtistSpotlightCard({required this.artist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = ScTheme.paletteOf(context).accent;
    final radius = BorderRadius.circular(_kCardRadius);

    return _CardShell(
      radius: radius,
      onTap: () =>
          ref.read(routerProvider.notifier).push(ArtistRoute(artist.id)),
      glow: accent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.4, -0.8),
            radius: 1.3,
            colors: [
              accent.withValues(alpha: 0.5),
              const Color(0xEB0E0E12),
              const Color(0xF2080808),
            ],
            stops: const [0, 0.65, 1],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 20),
          child: Column(
            children: [
              _avatar(accent),
              const SizedBox(height: 20),
              Text(
                artist.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFFFFFFF),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
              if (artist.country != null) ...[
                const SizedBox(height: 4),
                Text(
                  artist.country!.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0x73FFFFFF),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.8,
                  ),
                ),
              ],
              if (artist.tags.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final tag in artist.tags.take(2)) _TagChip(tag: tag),
                  ],
                ),
              ],
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.headphones,
                          size: 11, color: Color(0x8CFFFFFF)),
                      const SizedBox(width: 6),
                      Text(
                        formatCount(artist.monthlyListeners.toInt()),
                        style: const TextStyle(
                          color: Color(0xA6FFFFFF),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(9999),
                      gradient: LinearGradient(
                        colors: [
                          accent.withValues(alpha: 0.32),
                          accent.withValues(alpha: 0.05),
                        ],
                      ),
                      border: Border.all(color: accent.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      '↑ ${(artist.popularity * 100).round()}',
                      style: const TextStyle(
                        color: Color(0xFFFFFFFF),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatar(Color accent) {
    final g = gradientForId(artist.id);
    final url = artist.avatarUrl;
    return Container(
      width: 120,
      height: 120,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: g,
        ),
        border: Border.all(color: const Color(0x26FFFFFF)),
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: 0.5), blurRadius: 40, offset: const Offset(0, 18)),
        ],
      ),
      child: url == null
          ? Center(
              child: Text(
                monogramOf(artist.name),
                style: const TextStyle(
                  color: Color(0xF2FFFFFF),
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                ),
              ),
            )
          : Image.network(
              artUrl(url, ArtSize.card),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Center(
                child: Text(
                  monogramOf(artist.name),
                  style: const TextStyle(
                    color: Color(0xF2FFFFFF),
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
    );
  }
}

/// Общая оболочка карточки: тень, скругление, hover scale, клик.
class _CardShell extends StatefulWidget {
  final BorderRadius radius;
  final VoidCallback onTap;
  final Color glow;
  final Widget child;

  const _CardShell({
    required this.radius,
    required this.onTap,
    required this.glow,
    required this.child,
  });

  @override
  State<_CardShell> createState() => _CardShellState();
}

class _CardShellState extends State<_CardShell> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hover ? 1.02 : 1.0,
          duration: ScTokens.dGlass,
          curve: ScTokens.easeApple,
          child: Container(
            width: 280,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: widget.radius,
              border: Border.all(
                color: _hover ? widget.glow.withValues(alpha: 0.5) : const Color(0x1AFFFFFF),
              ),
              boxShadow: [
                const BoxShadow(
                    color: Color(0x8C000000), blurRadius: 60, offset: Offset(0, 30)),
                if (_hover)
                  BoxShadow(color: widget.glow.withValues(alpha: 0.25), blurRadius: 60),
              ],
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Badge({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9999),
        color: const Color(0x73000000),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: const Color(0xF2FFFFFF)),
          const SizedBox(width: 5),
          Text(
            text.toUpperCase(),
            style: const TextStyle(
              color: Color(0xF2FFFFFF),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String tag;

  const _TagChip({required this.tag});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9999),
        color: const Color(0x0FFFFFFF),
        border: Border.all(color: const Color(0x1AFFFFFF)),
      ),
      child: Text(
        tag.toUpperCase(),
        style: const TextStyle(
          color: Color(0xB3FFFFFF),
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
        ),
      ),
    );
  }
}
