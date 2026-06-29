import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../providers.dart';
import '../../rust/api.dart';
import '../../rust/dto.dart';

/// Редакционный пик (легаси §3.3 `FeaturedHero`): rounded-3xl `glass-featured`
/// блок с размытой обложкой-подложкой (`scale 1.4 opacity 0.2 blur(80)`),
/// обложкой 160px и play-орбом 56px. Источник — `featuredProvider` (трек/плейлист).
class FeaturedHero extends ConsumerWidget {
  const FeaturedHero({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(featuredProvider);
    return async.maybeWhen(
      data: (f) {
        final view = _FeaturedView.from(f);
        if (view == null) return const SizedBox.shrink();
        return _FeaturedCard(view: view);
      },
      loading: () => const Skeleton(height: 240, rounded: SkeletonRound.lg),
      orElse: () => const SizedBox.shrink(),
    );
  }
}

/// Нормализованный пик: трек или плейлист сведены к общему виду карточки.
class _FeaturedView {
  final String? artworkUrl;
  final String title;
  final String subtitle;
  final String kindLabel;
  final VoidCallback Function(WidgetRef ref, BuildContext context) action;

  const _FeaturedView({
    required this.artworkUrl,
    required this.title,
    required this.subtitle,
    required this.kindLabel,
    required this.action,
  });

  static _FeaturedView? from(FeaturedDto f) {
    final track = f.track;
    if (track != null) {
      return _FeaturedView(
        artworkUrl: track.artworkUrl,
        title: track.title,
        subtitle: track.artistName,
        kindLabel: 'ТРЕК ДНЯ',
        action: (ref, context) => () => _playTrack(ref, context, track),
      );
    }
    final playlist = f.playlist;
    if (playlist != null) {
      return _FeaturedView(
        artworkUrl: playlist.artworkUrl,
        title: playlist.title,
        subtitle: playlist.ownerUsername ?? '',
        kindLabel: playlist.isAlbum ? 'АЛЬБОМ ДНЯ' : 'ПЛЕЙЛИСТ ДНЯ',
        action: (ref, context) => () => ref
            .read(routerProvider.notifier)
            .push(PlaylistRoute(playlist.urn)),
      );
    }
    return null;
  }

  static Future<void> _playTrack(
      WidgetRef ref, BuildContext context, TrackDto track) async {
    final messenger = ToastScope.of(context);
    try {
      await ref.read(playerProvider.notifier).play(track);
    } catch (e) {
      messenger.show('Не удалось воспроизвести: $e', kind: ToastKind.error);
    }
  }
}

class _FeaturedCard extends ConsumerWidget {
  final _FeaturedView view;

  const _FeaturedCard({required this.view});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perf = PerfProfile.of(context);
    final accent = ScTheme.paletteOf(context).accent;
    final radius = BorderRadius.circular(24); // rounded-3xl
    final wide = MediaQuery.sizeOf(context).width >= 768;

    final blur = perf.blur(40);

    return ClipRRect(
      borderRadius: radius,
      child: Stack(
        children: [
          // `glass-featured`: фрост страницы/атмосферы под карточкой.
          if (blur > 0)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: const SizedBox.expand(),
              ),
            ),
          if (view.artworkUrl != null && perf.bloom)
            Positioned.fill(child: _ArtworkBackdrop(url: view.artworkUrl!)),
          _glass(radius),
          Padding(
            padding: EdgeInsets.all(wide ? 24 : 20),
            child: Row(
              children: [
                _cover(wide ? 160 : 120),
                SizedBox(width: wide ? 24 : 16),
                Expanded(child: _meta(accent)),
                const SizedBox(width: 16),
                _PlayOrb(accent: accent, onTap: view.action(ref, context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _glass(BorderRadius radius) {
    // Тинт `glass-featured` поверх фроста+обложки (left→right тёмный, как легаси
    // HeroBlurBg `from-[rgb(8,8,10)]/70 via/50 to/70`).
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xB308080A), Color(0x80080808), Color(0xB308080A)],
          ),
          border: Border.all(color: const Color(0x12FFFFFF)),
        ),
      ),
    );
  }

  Widget _cover(double side) {
    return Container(
      width: side,
      height: side,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ScTokens.rCard),
        boxShadow: const [
          BoxShadow(color: Color(0x73000000), blurRadius: 40, offset: Offset(0, 18)),
        ],
      ),
      child: TrackArtwork(url: view.artworkUrl, size: ArtSize.card),
    );
  }

  Widget _meta(Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          view.kindLabel,
          style: TextStyle(
            color: accent.withValues(alpha: 0.85),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.6,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          view.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFFFFFFFF),
            fontSize: 28,
            height: 1,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.8,
          ),
        ),
        if (view.subtitle.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            view.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0x8CFFFFFF), fontSize: 14),
          ),
        ],
      ],
    );
  }
}

/// Размытая обложка-подложка геро (`scale 1.4 opacity 0.2 blur(80)`).
class _ArtworkBackdrop extends StatelessWidget {
  final String url;

  const _ArtworkBackdrop({required this.url});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.2,
      child: Transform.scale(
        scale: 1.4,
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: TrackArtwork(url: url, size: ArtSize.hero),
        ),
      ),
    );
  }
}

class _PlayOrb extends StatelessWidget {
  final Color accent;
  final VoidCallback onTap;

  const _PlayOrb({required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: ScTheme.paletteOf(context).playGradient,
            boxShadow: [
              BoxShadow(color: accent.withValues(alpha: 0.4), blurRadius: 30, offset: const Offset(0, 8)),
            ],
          ),
          child: const Icon(LucideIcons.play, size: 30, color: Color(0xFF000000)),
        ),
      ),
    );
  }
}
