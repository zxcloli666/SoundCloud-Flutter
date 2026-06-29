import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import '../providers.dart';
import '../rust/api.dart';
import '../rust/dto_social.dart';
import 'offline/forge_module.dart';
import 'offline/offline_head.dart';
import 'offline/offline_model.dart';
import 'offline/offline_toolbar.dart';
import 'offline/offline_track_list.dart';
import 'offline/storage_module.dart';

/// Офлайн — «Кузница» (легаси §3.6). Промышленный конвейер транскода А→Б
/// (сырьё → ffmpeg-горн → чистые m4a) рядом с датчиком хранилища, над
/// фильтруемым/сортируемым/перетаскиваемым манифестом. Работает офлайн.
///
/// Манифест «Лайки» — из `likedTracksProvider`; «Кэш» — из живого
/// `cacheInventoryProvider` (urn+байты на файл), метаданные строк догружаются
/// лениво по urn. Объём хранилища — из `cacheTotalBytesProvider`. Скачка/удаление
/// идут через [OfflineController]. Кузница (live-статус транскода А→Б и прогресс
/// плавки) — честный простой: канала прогресса из ядра ещё нет.
class OfflinePage extends ConsumerStatefulWidget {
  const OfflinePage({super.key});

  @override
  ConsumerState<OfflinePage> createState() => _OfflinePageState();
}

class _OfflinePageState extends ConsumerState<OfflinePage> {
  OfflineSection _section = OfflineSection.likes;
  SortMode _sort = SortMode.custom;
  String _query = '';

  // Кузница: live-статус bulk-кэша лайков (из [likesCacheProvider]) — incoming
  // = очередь, transcoding = идёт, clean = готово в защищённый кэш.
  final Map<String, double> _downloads = const {};
  final Set<String> _forgingUrns = const {};
  final bool _online = true;
  final _scroll = SmoothScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final likedAsync = ref.watch(likedTracksProvider);
    final likes = likedAsync.value?.items ?? const <TrackDto>[];
    final cachedAsync = ref.watch(cacheInventoryProvider);
    final cache = cachedAsync.value ?? const <CacheEntryDto>[];

    final likesEntries = [
      for (final t in likes) OfflineEntry(urn: t.urn, track: t),
    ];
    final cachedEntries = [
      for (final c in cache)
        OfflineEntry(
          urn: c.urn,
          track: placeholderTrack(c.urn),
          inv: CacheInventoryEntry(
            urn: c.urn,
            bytes: c.bytes.toInt(),
            stage: CacheStage.clean,
          ),
          lazy: true,
        ),
    ];

    final base =
        _section == OfflineSection.likes ? likesEntries : cachedEntries;
    final entries = sortEntries(filterEntries(base, _query), _sort, null);
    final playable = entries.where((e) => e.cached).map((e) => e.track).toList();

    // Перетаскивание — только в кэше; порядок кэша пока не персистится в ядре,
    // поэтому drag-режим выключен (нет reorderCached в мосте).
    const sortable = false;

    return Atmosphere(
      tint: [ScTheme.paletteOf(context).accent, const Color(0xFF6B7A92)],
      energy: 0.4,
      child: SingleChildScrollView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 136),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OfflineHead(online: _online, onTryOnline: _tryOnline),
                const SizedBox(height: 20),
                if (likedAsync.isLoading && likes.isEmpty ||
                    cachedAsync.isLoading && cache.isEmpty)
                  ..._skeleton()
                else ...[
                  _heroDeck(),
                  const SizedBox(height: 20),
                  OfflineToolbar(
                    section: _section,
                    onSection: (s) => setState(() => _section = s),
                    likesCount: likesEntries.length,
                    cachedCount: cachedEntries.length,
                    playableCount: playable.length,
                    onPlayAll: () => _playAll(playable),
                    onShuffle: () => _shuffle(playable),
                    query: _query,
                    onQuery: (q) => setState(() => _query = q),
                    sort: _sort,
                    onSort: (s) => setState(() => _sort = s),
                  ),
                  const SizedBox(height: 20),
                  OfflineTrackList(
                    entries: entries,
                    sortable: sortable,
                    likesSection: _section == OfflineSection.likes,
                    forgingUrns: _forgingUrns,
                    downloads: _downloads,
                    emptyText: _emptyText,
                    onPlay: _play,
                    onDownload: _download,
                    onRemove: _remove,
                    onReorder: _reorder,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _heroDeck() {
    final perf = PerfProfile.of(context);
    final blur = perf.blur(24);
    final deck = LayoutBuilder(
      builder: (context, c) {
        final stacked = c.maxWidth < 900;
        final likes = ref.watch(likesCacheProvider);
        final forge = ForgeModule(
          status: _forgeStatus(likes),
          forgingTitle: _forgingTitle(likes),
        );
        final storage = StorageModule(
          stats: _storageStats(),
          caching: likes.running,
          onStartLikes: _cacheLikes,
          onCancelLikes: () => ref.read(likesCacheProvider.notifier).cancel(),
        );
        if (stacked) {
          return Column(
            children: [forge, _divider(false), storage],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 128, child: forge),
              _divider(true),
              Expanded(flex: 100, child: storage),
            ],
          ),
        );
      },
    );

    const radius = BorderRadius.all(Radius.circular(20));

    // Полупрозрачное стекло деки; блюр сэмплит атмосферу позади (§3.6).
    Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        gradient: blur > 0
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x0BFFFFFF), Color(0x05FFFFFF)],
              )
            : null,
        color: blur > 0 ? null : const Color(0xFF111115),
      ),
      child: Stack(
        children: [
          // Верхняя акцентная линия деки.
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0x00000000),
                    ScTheme.paletteOf(context).accentGlow,
                    const Color(0x00000000),
                  ],
                  stops: const [0.0, 0.18, 0.42],
                ),
              ),
            ),
          ),
          deck,
        ],
      ),
    );

    if (blur > 0) {
      surface = BackdropFilter(
        filter:
            ImageFilter.blur(sigmaX: perf.sigma(24), sigmaY: perf.sigma(24)),
        child: surface,
      );
    }

    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(color: Color(0xCC000000), blurRadius: 60, offset: Offset(0, 24)),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0x17FFFFFF)),
            borderRadius: radius,
          ),
          child: surface,
        ),
      ),
    );
  }

  Widget _divider(bool vertical) {
    final gradient = LinearGradient(
      begin: vertical ? Alignment.topCenter : Alignment.centerLeft,
      end: vertical ? Alignment.bottomCenter : Alignment.centerRight,
      colors: const [Color(0x00FFFFFF), Color(0x1FFFFFFF), Color(0x1FFFFFFF), Color(0x00FFFFFF)],
      stops: const [0.0, 0.3, 0.7, 1.0],
    );
    return vertical
        ? Container(width: 1, decoration: BoxDecoration(gradient: gradient))
        : Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(gradient: gradient),
          );
  }

  List<Widget> _skeleton() => [
        _shimmer(224, 20),
        const SizedBox(height: 20),
        _shimmer(36, 11, widthFactor: 0.66),
        const SizedBox(height: 20),
        _shimmer(480, 18),
      ];

  Widget _shimmer(double h, double r, {double widthFactor = 1}) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: widthFactor,
        child: Container(
          height: h,
          decoration: BoxDecoration(
            color: const Color(0x05FFFFFF),
            borderRadius: BorderRadius.circular(r),
            border: Border.all(color: const Color(0x0FFFFFFF)),
          ),
        ),
      ),
    );
  }

  StorageStats _storageStats() {
    final likes = ref.read(likedTracksProvider).value?.items ?? const [];
    final cache = ref.read(cacheInventoryProvider).value ?? const [];
    final total = ref.watch(cacheTotalBytesProvider).value ?? 0;

    // Покрытие лайков: сколько лайкнутых urn уже лежат в кэше.
    final cachedUrns = {
      for (final c in cache) c.urn.split(':').last,
    };
    final likedCached =
        likes.where((t) => cachedUrns.contains(t.urn.split(':').last)).length;

    // Байты на лайки отдельно не считаем (инвентарь не размечает «лайк vs кэш»);
    // показываем общий объём и число файлов честно.
    return StorageStats(
      totalBytes: total,
      cachedCount: cache.length,
      likedCount: likes.length,
      likedCachedCount: likedCached,
    );
  }

  /// Live-статус кузницы из прогресса bulk-кэша лайков. Простой, если не идёт.
  ForgeStatus _forgeStatus(LikesCacheState likes) {
    if (!likes.running && likes.total == 0) {
      return const ForgeStatus(ffmpeg: FfmpegState.ready);
    }
    final remaining = (likes.total - likes.done).clamp(0, likes.total);
    return ForgeStatus(
      ffmpeg: FfmpegState.ready,
      incoming: remaining,
      transcoding: likes.running ? 1 : 0,
      clean: likes.done,
    );
  }

  /// Подпись плавки: прогресс bulk-кэша лайков (per-urn-канала нет — показываем
  /// счётчик готовности).
  String? _forgingTitle(LikesCacheState likes) {
    if (!likes.running) return null;
    return 'Лайки: ${likes.done}/${likes.total}';
  }

  String get _emptyText {
    if (_query.trim().isNotEmpty) return 'Ничего не найдено';
    return _section == OfflineSection.likes
        ? 'Нет лайкнутых треков'
        : 'Кэш пуст';
  }

  /// Играем из текущего видимого списка как из очереди (queue-continuation):
  /// сначала доигрываем манифест, потом волна. lazy-плейсхолдер кэша резолвим в
  /// реальный трек, чтобы now-playing нёс честные метаданные.
  Future<void> _play(OfflineEntry e) => _playFrom(_currentQueue(), e.track);

  void _playAll(List<TrackDto> playable) {
    if (playable.isEmpty) return;
    _playFrom(playable, playable.first);
  }

  void _shuffle(List<TrackDto> playable) {
    if (playable.isEmpty) return;
    final q = [...playable]..shuffle(math.Random());
    _playFrom(q, q.first);
  }

  Future<void> _playFrom(List<TrackDto> queue, TrackDto start) async {
    final track = await _resolve(start);
    // Подменяем стартовый плейсхолдер в очереди резолвом (совпадение по urn-хвосту),
    // остальные кэш-плейсхолдеры доедут лениво в очереди по urn.
    final tail = track.urn.split(':').last;
    final resolvedQueue = [
      for (final t in queue)
        t.urn.split(':').last == tail ? track : t,
    ];
    await ref.read(playerProvider.notifier).play(track, queue: resolvedQueue);
  }

  /// Реальный трек по urn (lazy-плейсхолдер → метаданные); фолбэк — сам трек.
  Future<TrackDto> _resolve(TrackDto t) async {
    if (t.artistId.isNotEmpty) return t;
    final resolved = await ref.read(trackProvider(t.urn).future);
    return resolved ?? t;
  }

  /// Видимый список текущей вкладки как очередь воспроизведения.
  List<TrackDto> _currentQueue() {
    final likes = ref.read(likedTracksProvider).value?.items ?? const [];
    if (_section == OfflineSection.likes) return likes;
    final cache = ref.read(cacheInventoryProvider).value ?? const [];
    return [for (final c in cache) placeholderTrack(c.urn)];
  }

  Future<void> _download(OfflineEntry e) =>
      ref.read(offlineControllerProvider.notifier).ensure(e.urn);

  Future<void> _remove(String urn) =>
      ref.read(offlineControllerProvider.notifier).remove(urn);

  void _reorder(List<String> urns) {
    // Персист порядка кэша не проброшен в мост (нет reorderCached) — drag-режим
    // выключен на уровне build (sortable=false), сюда не приходит.
  }

  void _cacheLikes() {
    // Bulk-кэш всех лайков в защищённый кэш с живым прогрессом (ядро само
    // пропускает уже закэшированные). Прогресс → кузница/StorageModule.
    final likes = ref.read(likedTracksProvider).value?.items ?? const [];
    if (likes.isEmpty) return;
    ref.read(likesCacheProvider.notifier).start([for (final t in likes) t.urn]);
  }

  void _tryOnline() =>
      ref.read(routerProvider.notifier).selectTab(const HomeRoute());
}
