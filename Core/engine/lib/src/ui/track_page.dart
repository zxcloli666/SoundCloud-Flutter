import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import '../providers.dart';
import '../rust/api.dart';
import 'track/liner_notes.dart';
import 'track/room_hero.dart';
import 'track/room_sleeve.dart';
import 'track/room_voices_host.dart';
import 'track/track_aura.dart';
import 'track/track_lyrics.dart';
import 'track/track_similar.dart';

/// Страница трека — «комната» (легаси §3.7). Атмосфера тонируется жанром,
/// контент — стеклянный hero (обложка + волна), оборот конверта со статистикой,
/// панель лирики по запросу и колонка похожего. Рендерит [TrackRoute].
class TrackPage extends ConsumerStatefulWidget {
  final String urn;

  const TrackPage({super.key, required this.urn});

  @override
  ConsumerState<TrackPage> createState() => _TrackPageState();
}

class _TrackPageState extends ConsumerState<TrackPage> {
  bool _lyricsOpen = false;

  /// Оптимистичный флаг лайка поверх серверного [TrackDto.userFavorite]: флипаем
  /// сразу, а мутацию ([socialControllerProvider]) шлём в фон; на ошибке —
  /// откатываем (легаси делает оптимистично).
  bool? _likedOverride;

  @override
  Widget build(BuildContext context) {
    final track = ref.watch(trackProvider(widget.urn));

    return track.when(
      loading: () => _Shell(tint: null, child: const _HeroSkeleton()),
      error: (_, __) => _Shell(tint: null, child: _ErrorState(onBack: _pop)),
      data: (t) {
        if (t == null) return _Shell(tint: null, child: _ErrorState(onBack: _pop));
        return _content(t);
      },
    );
  }

  Widget _content(TrackDto track) {
    final viewerAccent = ScTheme.paletteOf(context).accent;
    final aura = TrackAura.resolve(track.genre, viewerAccent);
    final currentUrn = ref.watch(playerProvider)?.urn;
    final isCurrent = currentUrn == track.urn;
    // Этот трек звучит = он текущий И плеер не на паузе ([isPlayingProvider]).
    final isPlaying = isCurrent && ref.watch(isPlayingProvider);
    final liked = _likedOverride ?? (track.userFavorite ?? false);

    return _Shell(
      tint: aura.hasGenre ? [aura.accent] : null,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 160),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _BackRow(onBack: _pop, roomFor: aura.hasGenre ? track.genre : null),
                const SizedBox(height: 20),
                RoomHero(
                  track: track,
                  aura: aura,
                  isCurrent: isCurrent,
                  isPlaying: isPlaying,
                  liked: liked,
                  onPlay: () => _play(track),
                  onToggleLike: (v) => _toggleLike(track, v),
                  onLyrics: () => setState(() => _lyricsOpen = !_lyricsOpen),
                  onOpenArtist: () =>
                      ref.read(routerProvider.notifier).push(ArtistRoute(track.artistId)),
                ),
                if (_lyricsOpen) ...[
                  const SizedBox(height: 28),
                  TrackLyrics(urn: track.urn),
                ],
                const SizedBox(height: 28),
                LinerNotes(track: track, aura: aura),
                TrackSimilar(track: track, aura: aura),
                const SizedBox(height: 32),
                RoomVoicesHost(urn: track.urn),
                const SizedBox(height: 28),
                _Floor(track: track, aura: aura),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleLike(TrackDto track, bool next) async {
    final messenger = ToastScope.of(context);
    final social = ref.read(socialControllerProvider);
    setState(() => _likedOverride = next);
    try {
      if (next) {
        await social.likeTrack(track.urn);
      } else {
        await social.unlikeTrack(track.urn);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _likedOverride = !next);
      messenger.show('Не удалось обновить лайк: $e', kind: ToastKind.error);
    }
  }

  Future<void> _play(TrackDto track) async {
    final messenger = ToastScope.of(context);
    final notifier = ref.read(playerProvider.notifier);
    if (ref.read(playerProvider)?.urn == track.urn) {
      await notifier.togglePause();
      return;
    }
    try {
      await notifier.play(track);
    } catch (e) {
      messenger.show('Не удалось воспроизвести: $e', kind: ToastKind.error);
    }
  }

  void _pop() => ref.read(routerProvider.notifier).pop();
}

/// Низ комнаты: на широком — две колонки (пусто-под-комменты | sleeve 340px),
/// на узком — sleeve во всю ширину. Комментарии мост пока не отдаёт, поэтому
/// похожее (sleeve) — основной «куда дальше» блок.
class _Floor extends StatelessWidget {
  final TrackDto track;
  final TrackAura aura;

  const _Floor({required this.track, required this.aura});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sleeve = RoomSleeve(track: track, aura: aura);
        if (constraints.maxWidth >= 900) {
          return Align(
            alignment: Alignment.topRight,
            child: SizedBox(width: 340, child: sleeve),
          );
        }
        return sleeve;
      },
    );
  }
}

class _Shell extends StatefulWidget {
  final List<Color>? tint;
  final Widget child;

  const _Shell({required this.tint, required this.child});

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  final _scroll = SmoothScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Atmosphere(
      tint: widget.tint ?? const [],
      energy: 0.5,
      child: SingleChildScrollView(controller: _scroll, child: widget.child),
    );
  }
}

class _BackRow extends StatelessWidget {
  final VoidCallback onBack;
  final String? roomFor;

  const _BackRow({required this.onBack, required this.roomFor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _BackButton(onBack: onBack),
        if (roomFor != null)
          Text(
            'КОМНАТА ДЛЯ ${roomFor!.toUpperCase()}',
            style: const TextStyle(
              fontSize: 10,
              letterSpacing: 2.4,
              color: Color(0x33FFFFFF),
            ),
          ),
      ],
    );
  }
}

class _BackButton extends StatefulWidget {
  final VoidCallback onBack;

  const _BackButton({required this.onBack});

  @override
  State<_BackButton> createState() => _BackButtonState();
}

class _BackButtonState extends State<_BackButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onBack,
        child: AnimatedContainer(
          duration: ScTokens.dFast,
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _hover ? const Color(0x0FFFFFFF) : const Color(0x00000000),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(
            LucideIcons.chevronLeft,
            size: 22,
            color: _hover ? const Color(0xFFFFFFFF) : const Color(0x8CFFFFFF),
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onBack;

  const _ErrorState({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 480,
      child: Center(
        child: EmptyState(
          icon: const Icon(LucideIcons.circleAlert),
          title: 'Не удалось загрузить трек',
          body: 'Трек недоступен или не найден.',
          cta: 'Назад',
          ctaIcon: const Icon(LucideIcons.chevronLeft),
          onAction: onBack,
        ),
      ),
    );
  }
}

class _HeroSkeleton extends StatelessWidget {
  const _HeroSkeleton();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1320),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 56, 20, 160),
          child: GlassPanel(
            variant: GlassVariant.featured,
            radius: ScTokens.rHero,
            padding: const EdgeInsets.all(28),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 720;
                final cover = const Skeleton(width: 220, height: 220, rounded: SkeletonRound.lg);
                final info = Column(
                  crossAxisAlignment:
                      wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                  children: const [
                    Skeleton(width: 160, height: 16, rounded: SkeletonRound.full),
                    SizedBox(height: 16),
                    Skeleton(width: 280, height: 48),
                    SizedBox(height: 16),
                    Skeleton(width: 180, height: 20, rounded: SkeletonRound.full),
                    SizedBox(height: 24),
                    Skeleton(width: 260, height: 44, rounded: SkeletonRound.full),
                  ],
                );
                return Column(
                  children: [
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [cover, const SizedBox(width: 32), Expanded(child: info)],
                      )
                    else
                      Column(children: [cover, const SizedBox(height: 24), info]),
                    const SizedBox(height: 32),
                    const Skeleton(height: 96, rounded: SkeletonRound.md),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
