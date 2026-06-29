import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../providers.dart';
import '../../rust/api.dart';
import '../../rust/dto.dart';
import 'track_aura.dart';

/// Конверт: кто это сделал и куда пойти дальше — карточка артиста (→ArtistRoute),
/// стопка «кто вайбит» (лайкнувшие, `trackFavoritersProvider`) и список похожих
/// треков (`trackRelatedProvider`, тап → играть + TrackRoute).
class RoomSleeve extends ConsumerWidget {
  final TrackDto track;
  final TrackAura aura;

  const RoomSleeve({super.key, required this.track, required this.aura});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final related = ref.watch(trackRelatedProvider(track.urn));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ArtistCard(track: track, aura: aura),
        const SizedBox(height: 20),
        _WhoVibes(urn: track.urn, aura: aura),
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'ПОХОЖЕЕ',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
              color: Color(0x66FFFFFF),
            ),
          ),
        ),
        related.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0x26FFFFFF)),
              ),
            ),
          ),
          error: (_, __) => const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Text('Пока ничего похожего', style: TextStyle(fontSize: 12, color: Color(0x40FFFFFF))),
          ),
          data: (tracks) {
            final list = tracks.where((t) => t.urn != track.urn).take(10).toList();
            if (list.isEmpty) {
              return const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Text('Пока ничего похожего', style: TextStyle(fontSize: 12, color: Color(0x40FFFFFF))),
              );
            }
            return Column(
              children: [for (final t in list) _RelatedRow(track: t)],
            );
          },
        ),
      ],
    );
  }
}

/// Стопка «кто вайбит»: перекрытые аватары лайкнувших трек ([trackFavoritersProvider]).
/// Молча скрывается, пока порция грузится / пуста — блок необязательный.
class _WhoVibes extends ConsumerWidget {
  final String urn;
  final TrackAura aura;

  const _WhoVibes({required this.urn, required this.aura});

  static const _max = 6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoriters = ref.watch(trackFavoritersProvider(urn));
    final users = favoriters.value?.items ?? const <UserDto>[];
    if (users.isEmpty) return const SizedBox.shrink();

    final shown = users.take(_max).toList();
    final extra = users.length - shown.length;

    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'КТО ВАЙБИТ',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.8,
                color: Color(0x66FFFFFF),
              ),
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < shown.length; i++)
                Transform.translate(
                  offset: Offset(i * -12.0, 0),
                  child: _VibeAvatar(user: shown[i]),
                ),
              if (extra > 0)
                Transform.translate(
                  offset: Offset(shown.length * -12.0 + 6, 0),
                  child: Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0x0FFFFFFF),
                      borderRadius: BorderRadius.circular(9999),
                      border: Border.all(color: const Color(0x14FFFFFF), width: 0.5),
                    ),
                    child: Text(
                      '+$extra',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0x99FFFFFF),
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VibeAvatar extends ConsumerStatefulWidget {
  final UserDto user;

  const _VibeAvatar({required this.user});

  @override
  ConsumerState<_VibeAvatar> createState() => _VibeAvatarState();
}

class _VibeAvatarState extends ConsumerState<_VibeAvatar> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    return ScTooltip(
      message: u.username,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: () => ref.read(routerProvider.notifier).push(UserRoute(u.urn)),
          child: AnimatedScale(
            duration: ScTokens.dFast,
            curve: ScTokens.easeApple,
            scale: _hover ? 1.08 : 1.0,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _hover ? const Color(0x59FFFFFF) : const Color(0xFF111114),
                  width: 2,
                ),
              ),
              child: Avatar(src: u.avatarUrl, alt: u.username, size: 34),
            ),
          ),
        ),
      ),
    );
  }
}

class _ArtistCard extends ConsumerStatefulWidget {
  final TrackDto track;
  final TrackAura aura;

  const _ArtistCard({required this.track, required this.aura});

  @override
  ConsumerState<_ArtistCard> createState() => _ArtistCardState();
}

class _ArtistCardState extends ConsumerState<_ArtistCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.track;
    final avatar = t.artistAvatarUrl ?? t.uploaderAvatarUrl;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => ref.read(routerProvider.notifier).push(ArtistRoute(t.artistId)),
        child: AnimatedContainer(
          duration: ScTokens.dSidebar,
          curve: ScTokens.easeApple,
          transform: Matrix4.translationValues(0, _hover ? -2 : 0, 0),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0x09FFFFFF),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0x12FFFFFF), width: 0.5),
          ),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: widget.aura.glow, blurRadius: 36, spreadRadius: -6)],
                ),
                child: Avatar(src: avatar, alt: t.artistName, size: 80),
              ),
              const SizedBox(height: 14),
              Text(
                t.artistName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _hover ? const Color(0xFFFFFFFF) : const Color(0xE6FFFFFF),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RelatedRow extends ConsumerStatefulWidget {
  final TrackDto track;

  const _RelatedRow({required this.track});

  @override
  ConsumerState<_RelatedRow> createState() => _RelatedRowState();
}

class _RelatedRowState extends ConsumerState<_RelatedRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.track;
    final current = ref.watch(playerProvider)?.urn == t.urn;
    final accent = ScTheme.paletteOf(context).accent;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => ref.read(routerProvider.notifier).push(TrackRoute(t.urn)),
        child: AnimatedContainer(
          duration: ScTokens.dSidebar,
          curve: ScTokens.easeApple,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: current
                ? accent.withValues(alpha: 0.06)
                : (_hover ? const Color(0x0AFFFFFF) : const Color(0x00000000)),
            borderRadius: BorderRadius.circular(ScTokens.rCard),
            border: current ? Border.all(color: accent.withValues(alpha: 0.20)) : null,
          ),
          child: Row(
            children: [
              _RelatedCover(track: t, current: current, hover: _hover),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      t.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xE6FFFFFF),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t.artistName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: Color(0x73FFFFFF)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatDuration(t.durationMs.toInt()),
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0x4DFFFFFF),
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RelatedCover extends ConsumerWidget {
  final TrackDto track;
  final bool current;
  final bool hover;

  const _RelatedCover({required this.track, required this.current, required this.hover});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showPlay = current || hover;
    return GestureDetector(
      onTap: () async {
        final messenger = ToastScope.of(context);
        try {
          await ref.read(playerProvider.notifier).play(track);
        } catch (e) {
          messenger.show('Не удалось воспроизвести: $e', kind: ToastKind.error);
        }
      },
      child: SizedBox(
        width: 44,
        height: 44,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(ScTokens.rButton),
              child: TrackArtwork(url: track.artworkUrl, size: ArtSize.row),
            ),
            if (showPlay)
              Container(
                decoration: BoxDecoration(
                  color: const Color(0x59000000),
                  borderRadius: BorderRadius.circular(ScTokens.rButton),
                ),
                alignment: Alignment.center,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(color: Color(0xFFFFFFFF), shape: BoxShape.circle),
                  child: Icon(
                    current ? LucideIcons.pause : LucideIcons.play,
                    size: 16,
                    color: const Color(0xFF08080A),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
