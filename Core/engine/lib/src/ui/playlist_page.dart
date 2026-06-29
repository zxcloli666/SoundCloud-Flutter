import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import '../providers.dart';
import '../rust/api.dart';
import '../rust/dto.dart';
import 'playlist/crate_ledger.dart';
import 'playlist/more_crates.dart';
import 'playlist/playlist_aura.dart';
import 'playlist/playlist_hero.dart';
import 'playlist/sequence_list.dart';
import 'playlist/set_ribbon.dart';

/// Страница плейлиста — «The Crate». Шапка (веер обложек + заголовок/мета/
/// действия + куратор) → реестр фактов → лента-сет (>1 трек) → секвенция
/// (виртуализированный треклист, владельцу — удаление) → ещё ящики куратора.
/// За контентом — атмосфера, тонированная топ-жанрами.
class PlaylistPage extends ConsumerStatefulWidget {
  final String urn;

  const PlaylistPage({super.key, required this.urn});

  @override
  ConsumerState<PlaylistPage> createState() => _PlaylistPageState();
}

class _PlaylistPageState extends ConsumerState<PlaylistPage> {
  final _scroll = SmoothScrollController();

  /// Оптимистичный лайк-флаг этой страницы. `null` — берём из `summary`; иначе
  /// показываем последнее намерение пользователя, не дожидаясь перечитки.
  bool? _likedOverride;

  @override
  void initState() {
    super.initState();
    // Параметризованный нотифаер: грузим треклист этого urn после первого кадра.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(playlistTracksProvider.notifier).load(widget.urn);
    });
    _scroll.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant PlaylistPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.urn != widget.urn) {
      _likedOverride = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(playlistTracksProvider.notifier).load(widget.urn);
      });
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 600) {
      ref.read(playlistTracksProvider.notifier).more();
    }
  }

  /// Играть [index] из плейлиста, передав весь треклист как контекст очереди:
  /// сначала доигрывается сет, потом — волна (инвариант queue-continuation).
  Future<void> _play(List<TrackDto> tracks, int index) async {
    if (index < 0 || index >= tracks.length) return;
    final messenger = ToastScope.of(context);
    try {
      await ref.read(playerProvider.notifier).play(tracks[index], queue: tracks);
    } catch (e) {
      messenger.show('Не удалось воспроизвести: $e', kind: ToastKind.error);
    }
  }

  /// Оптимистичный тоггл лайка плейлиста через [socialControllerProvider]
  /// (единый писатель в нашу БД). Падение — откат флага + снек.
  Future<void> _toggleLike(bool next) async {
    final messenger = ToastScope.maybeOf(context);
    setState(() => _likedOverride = next);
    final social = ref.read(socialControllerProvider);
    try {
      if (next) {
        await social.likePlaylist(widget.urn);
      } else {
        await social.unlikePlaylist(widget.urn);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _likedOverride = !next);
      messenger?.show('Не удалось обновить лайк: $e', kind: ToastKind.error);
    }
  }

  /// Убрать трек из плейлиста (владелец). Нотифаер делает оптимизм + откат;
  /// здесь только показываем снек при падении.
  Future<void> _removeTrack(String trackUrn) async {
    final messenger = ToastScope.maybeOf(context);
    try {
      await ref.read(playlistTracksProvider.notifier).removeTrack(trackUrn);
    } catch (e) {
      messenger?.show('Не удалось убрать трек: $e', kind: ToastKind.error);
    }
  }

  /// Удалить плейлист (владелец): подтверждение → мутация → возврат с экрана.
  Future<void> _confirmDelete() async {
    final messenger = ToastScope.maybeOf(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF14141A),
        title: const Text('Удалить плейлист?'),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFF87171)),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(playlistTracksProvider.notifier).delete();
      if (mounted) ref.read(routerProvider.notifier).pop();
    } catch (e) {
      messenger?.show('Не удалось удалить плейлист: $e', kind: ToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(playlistTracksProvider);
    final state = asyncState.value;
    final viewerAccent = ScTheme.paletteOf(context).accent;

    // Состояние нотифаера могло относиться к прошлому urn (он один на всех) —
    // пока не догрузился наш, показываем загрузку.
    final ready = state != null && state.urn == widget.urn && state.summary != null;

    if (asyncState.hasError && (state == null || state.urn != widget.urn)) {
      return _scaffold(const [], 0.5, _error(asyncState.error));
    }
    if (!ready) {
      return _scaffold(const [], 0.5, const _HeroSkeleton());
    }

    final summary = state.summary!;
    final tracks = state.tracks;
    final aura = PlaylistAura.resolve(tracks, viewerAccent);

    final current = ref.watch(playerProvider);
    final isAudioPlaying = ref.watch(isPlayingProvider);
    final trackUrns = tracks.map((t) => t.urn).toSet();
    // «Играет этот плейлист» = текущий трек из него И транспорт не на паузе.
    final fromHere = current != null && trackUrns.contains(current.urn);
    final playing = fromHere && isAudioPlaying;

    final me = ref.watch(meProvider).value;
    final isOwner = me != null && _sameUser(me.urn, summary.ownerId);
    final trackCount = summary.trackCount > 0 ? summary.trackCount : tracks.length;
    final liked = _likedOverride ?? summary.userFavorite ?? false;

    // «Ещё ящики этого куратора» — из плейлистов владельца плейлиста (для любого
    // куратора, не только моих). Подгружаем по ownerId после первого кадра.
    final ownerId = summary.ownerId;
    final List<PlaylistSummaryDto> moreCrates;
    if (ownerId != null && ownerId.isNotEmpty) {
      final ownerPlaylists = ref.watch(userPlaylistsProvider);
      final ownerState = ownerPlaylists.value;
      if (ownerState == null || ownerState.urn != ownerId) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(userPlaylistsProvider.notifier).load(ownerId);
        });
      }
      moreCrates = (ownerState != null && ownerState.urn == ownerId
              ? ownerState.items
              : const <PlaylistSummaryDto>[])
          .where((p) => p.urn != summary.urn)
          .take(12)
          .toList();
    } else {
      moreCrates = const <PlaylistSummaryDto>[];
    }

    return _scaffold(
      aura.tint,
      playing ? math.min(1.0, aura.energy + 0.12) : aura.energy,
      ListView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 136),
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1320),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _backButton(),
                  const SizedBox(height: 16),
                  PlaylistHero(
                    summary: summary,
                    tracks: tracks,
                    aura: aura,
                    isOwner: isOwner,
                    playing: playing,
                    isPinned: ref.watch(settingsProvider
                        .select((s) => s.pinnedPlaylists.any((p) => p.urn == summary.urn))),
                    liked: liked,
                    trackCount: trackCount,
                    onPlayAll: () => _play(tracks, 0),
                    onShuffle: () =>
                        _play(tracks, tracks.isEmpty ? 0 : math.Random().nextInt(tracks.length)),
                    onToggleLike: _toggleLike,
                    // Закреп в «Быстром доступе» (персист, только вручную).
                    onTogglePin: () => ref.read(settingsProvider.notifier).togglePinnedPlaylist(
                          PinnedPlaylist(
                            urn: summary.urn,
                            title: summary.title,
                            artworkUrl: summary.artworkUrl,
                          ),
                        ),
                    onDelete: _confirmDelete,
                    onOpenCurator: () {
                      final id = summary.ownerId;
                      if (id != null && id.isNotEmpty) {
                        ref.read(routerProvider.notifier).push(UserRoute(id));
                      }
                    },
                  ),
                  const SizedBox(height: 28),
                  CrateLedger(
                    tracks: tracks,
                    trackCount: trackCount,
                    durationMs: summary.durationMs?.toInt() ?? 0,
                    accentGlow: aura.glow,
                  ),
                  if (tracks.length > 1) ...[
                    const SizedBox(height: 28),
                    _setPanel(tracks),
                  ],
                  const SizedBox(height: 28),
                  SequenceList(
                    tracks: tracks,
                    isOwner: isOwner,
                    currentUrn: current?.urn,
                    playing: playing,
                    hasMore: state.hasMore,
                    loadingMore: state.loadingMore,
                    onPlayAt: (i) => _play(tracks, i),
                    onRemove: isOwner ? _removeTrack : (_) {},
                    onReorder: isOwner
                        ? (urns) =>
                            ref.read(playlistTracksProvider.notifier).reorder(urns)
                        : null,
                  ),
                  if (moreCrates.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    MoreCrates(
                      curatorName: summary.ownerUsername ?? '',
                      playlists: moreCrates,
                      onOpen: (urn) =>
                          ref.read(routerProvider.notifier).push(PlaylistRoute(urn)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scaffold(List<Color> tint, double energy, Widget content) {
    return Atmosphere(
      tint: tint,
      energy: energy,
      child: Align(alignment: Alignment.topCenter, child: content),
    );
  }

  Widget _setPanel(List<TrackDto> tracks) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0x06FFFFFF),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: ScTokens.glassBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'THE SET',
            style: TextStyle(
              color: Color(0x73FFFFFF),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.4,
            ),
          ),
          const SizedBox(height: 16),
          SetRibbon(tracks: tracks, onJump: (i) => _play(tracks, i)),
        ],
      ),
    );
  }

  Widget _backButton() {
    return Align(
      alignment: Alignment.centerLeft,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => ref.read(routerProvider.notifier).pop(),
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: const BoxDecoration(shape: BoxShape.circle),
            child: const Icon(LucideIcons.chevronLeft, size: 22, color: Color(0x8CFFFFFF)),
          ),
        ),
      ),
    );
  }

  Widget _error(Object? error) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1320),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: EmptyState(
          icon: const Icon(LucideIcons.circleAlert),
          title: 'Не удалось загрузить плейлист',
          body: '$error',
          cta: 'Назад',
          ctaIcon: const Icon(LucideIcons.arrowLeft),
          onAction: () => ref.read(routerProvider.notifier).pop(),
        ),
      ),
    );
  }
}

/// Сравнение владельца: user_id раздвоен URN vs голый — матчим по совпадению
/// или общему хвосту после двоеточия (`soundcloud:users:123` ↔ `123`).
bool _sameUser(String a, String? b) {
  if (b == null || b.isEmpty) return false;
  if (a == b) return true;
  String bare(String s) => s.contains(':') ? s.split(':').last : s;
  return bare(a) == bare(b);
}

/// Скелет шапки на время загрузки (legacy `HeroSkeleton`).
class _HeroSkeleton extends StatelessWidget {
  const _HeroSkeleton();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1320),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: GlassPanel(
          variant: GlassVariant.featured,
          radius: ScTokens.rHero,
          padding: const EdgeInsets.all(40),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Skeleton(width: 200, height: 200, rounded: SkeletonRound.lg),
              const SizedBox(width: 48),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Skeleton(width: 120, height: 16, rounded: SkeletonRound.full),
                    SizedBox(height: 16),
                    Skeleton(width: 320, height: 56, rounded: SkeletonRound.lg),
                    SizedBox(height: 24),
                    Skeleton(width: 280, height: 44, rounded: SkeletonRound.full),
                    SizedBox(height: 16),
                    Skeleton(width: double.infinity, height: 96, rounded: SkeletonRound.lg),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
