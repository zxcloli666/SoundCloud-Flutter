import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import '../providers.dart';
import '../rust/api.dart';
import 'home/archive_station.dart';
import 'home/artist_wire.dart';
import 'home/estuary_deck.dart';
import 'home/river_braid.dart';
import 'home/river_masthead.dart';
import 'home/river_section.dart';
import 'home/shared.dart' hide genreColor;
import 'home/shelves.dart';
import 'home/wave_schedule.dart';
import 'search/genre_palette.dart';

/// Главная — «Течение»: река твоей музыки. Шапка-эфир (приветствие + спектр
/// вкуса), on-air дека с волной, русло рекомендательных кластеров (горизонтальные
/// полки + расписание волны), внизу — архив (лайки + рекомендации).
///
/// Кластеры (`homeRiverProvider`/[ResolvedCluster]) резолвятся пачкой провайдером;
/// тайлы внутри полок не догружаются повторно. Бесконечная волна (`waveProvider`)
/// питает очередь, а не визуал. Featured — редакционный пик в шапке деки.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  // Выбранный в спектре жанр ретинтит всю страницу (атмосфера + шапка).
  String? _selectedGenre;
  final _scroll = SmoothScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(meProvider);
    final likedGenres = ref
        .watch(likedTracksProvider.select((s) => s.value?.items))
        ?.map((t) => t.genre);
    final spectrum =
        likedGenres == null ? const <GenreShare>[] : genreShares(likedGenres, 7);

    // Сброс выбора, если выбранный жанр выпал из спектра (лайки изменились).
    final selected =
        spectrum.any((g) => g.genre == _selectedGenre) ? _selectedGenre : null;

    final palette = ScTheme.paletteOf(context);
    final accent =
        selected == null ? palette.accent : genreColor(selected, palette.accent);
    final energy = selected != null
        ? genreEnergy(selected)
        : (spectrum.isEmpty
            ? 0.45
            : vibeEnergy([for (final g in spectrum) g.genre]));

    return Atmosphere(
      tint: [accent, accent.withValues(alpha: 0.7)],
      energy: energy,
      stars: 0.7,
      starGlow: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1024;
          return SingleChildScrollView(
            controller: _scroll,
            padding: EdgeInsets.fromLTRB(wide ? 32 : 16, 20, wide ? 32 : 16, 136),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1320),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    RiverMasthead(
                      me: me.value,
                      spectrum: spectrum,
                      selected: selected,
                      onSelect: (g) => setState(() => _selectedGenre = g),
                    ),
                    const SizedBox(height: 32),
                    const _RiverFlow(),
                    const SizedBox(height: 56),
                    const ArchiveStation(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Якорный порядок русла: река течёт сверху вниз через эти точки (легаси
/// `ANCHOR_ORDER`). Кластеры берём в этом порядке, остальные id игнорируем.
const _clusterOrder = <String>[
  'wave',
  'top_artists',
  'fresh_drops',
  'same_vibe',
  'adjacent',
  'deep_cuts',
];

/// Заголовок/подпись кластера — из i18n (легаси `soundwave.home.cluster.*`).
String _clusterTitle(WidgetRef ref, String id) =>
    ref.tr('soundwave.home.cluster.$id');

String _clusterWhy(WidgetRef ref, String id) =>
    ref.tr('soundwave.home.cluster.${id}Desc');

/// Русло реки: дека + секции кластеров вдоль SVG-нити. Состояния loading/cold —
/// как в легаси (скелет рядов / приглашающая плашка).
class _RiverFlow extends ConsumerStatefulWidget {
  const _RiverFlow();

  @override
  ConsumerState<_RiverFlow> createState() => _RiverFlowState();
}

class _RiverFlowState extends ConsumerState<_RiverFlow> {
  final _anchors = <String, RiverAnchorSlot>{};

  void _registerAnchor(String id, RiverAnchorSlot? slot) {
    if (slot == null) {
      _anchors.remove(id);
    } else {
      _anchors[id] = slot;
    }
  }

  @override
  Widget build(BuildContext context) {
    final river = ref.watch(homeRiverProvider);
    final wave = ref.watch(waveProvider);
    final current = ref.watch(playerProvider);

    // Дека НЕ внутри loading-ветки: переключение фильтров волны пере-запрашивает
    // реку, но дека должна оставаться на месте (как в легаси — ре-рендерится всё,
    // КРОМЕ деки). Кластеры держат прежние данные (valueOrNull) на время догрузки.
    final clusters = river.value ?? const <ResolvedCluster>[];
    final byId = {for (final c in clusters) c.id: c};
    final ordered = [
      for (final id in _clusterOrder)
        if (byId[id] != null && byId[id]!.tracks.isNotEmpty) byId[id]!,
    ];

    final deckTrack = current ?? _firstTrack(ordered);
    final isCurrent = current != null && deckTrack?.urn == current.urn;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EstuaryDeck(
          track: deckTrack,
          isCurrent: isCurrent,
          refreshing: wave.isLoading || river.isLoading,
          onRefresh: () => ref.read(waveProvider.notifier).refresh(),
          onPlayWave: deckTrack == null ? null : () => _play(ref, deckTrack),
        ),
        const SizedBox(height: 48),
        _channel(river, ordered, current),
      ],
    );
  }

  /// Русло под декой: скелет/пусто/ошибка — только когда данных ещё нет; иначе
  /// сами секции (на догрузке держим прежние, не моргаем скелетом).
  Widget _channel(
    AsyncValue<List<ResolvedCluster>> river,
    List<ResolvedCluster> ordered,
    TrackDto? current,
  ) {
    if (ordered.isEmpty) {
      if (river.isLoading) {
        return const Padding(
          padding: EdgeInsets.only(top: 40),
          child: ClusterSkeleton(rows: 3, itemsPerRow: 6),
        );
      }
      if (river.hasError) {
        return const Padding(
          padding: EdgeInsets.only(top: 40),
          child: EmptyState(
            icon: Icon(LucideIcons.cloudOff),
            title: 'Не удалось собрать реку',
          ),
        );
      }
      return const Padding(
        padding: EdgeInsets.only(top: 40),
        child: EmptyState(
          icon: Icon(LucideIcons.sparkles),
          title: 'Эфир пока пуст — послушай пару треков, и река потечёт',
        ),
      );
    }
    return _RiverChannel(
      clusters: ordered,
      anchors: _anchors,
      registerAnchor: _registerAnchor,
      currentUrn: current?.urn,
    );
  }

  TrackDto? _firstTrack(List<ResolvedCluster> clusters) {
    for (final c in clusters) {
      if (c.tracks.isNotEmpty) return c.tracks.first;
    }
    return null;
  }

  Future<void> _play(WidgetRef ref, TrackDto track) async {
    final messenger = ToastScope.of(context);
    try {
      await ref.read(playerProvider.notifier).play(track);
    } catch (error) {
      messenger.show('Не удалось воспроизвести: $error', kind: ToastKind.error);
    }
  }
}

/// Русло с притоками: SVG-река под контентом + колонка секций. Двухколоночные
/// связки (top_artists|fresh_drops, same_vibe|adjacent) на широких экранах,
/// в одну колонку — на узких.
class _RiverChannel extends ConsumerWidget {
  final List<ResolvedCluster> clusters;
  final Map<String, RiverAnchorSlot> anchors;
  final void Function(String, RiverAnchorSlot?) registerAnchor;
  final String? currentUrn;

  const _RiverChannel({
    required this.clusters,
    required this.anchors,
    required this.registerAnchor,
    required this.currentUrn,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final byId = {for (final c in clusters) c.id: c};
    final wide = MediaQuery.sizeOf(context).width >= 1024;
    final layoutKey = _clusterOrder.where(byId.containsKey).join('|');

    return RiverBraid(
      anchors: anchors,
      layoutKey: layoutKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final entry in _rows(ref, byId, wide)) ...[
            entry,
            const SizedBox(height: 48),
          ],
          _Anchor(
            id: 'delta',
            kind: RiverAnchorKind.delta,
            register: registerAnchor,
            child: const _DeltaNote(),
          ),
        ],
      ),
    );
  }

  List<Widget> _rows(WidgetRef ref, Map<String, ResolvedCluster> byId, bool wide) {
    final rows = <Widget>[];

    final wave = byId['wave'];
    if (wave != null) {
      rows.add(_section(
        ref,
        'wave',
        RiverAnchorKind.node,
        WaveSchedule(tracks: wave.tracks, currentUrn: currentUrn),
      ));
    }

    rows.add(_pair(
      ref,
      byId,
      'top_artists',
      'fresh_drops',
      wide,
      (c) => ArtistWire(cluster: c, currentUrn: currentUrn),
      (c) => ReleaseBrook(tracks: c.tracks, currentUrn: currentUrn),
      rightTone: RiverSectionTone.panel,
    ));

    rows.add(_pair(
      ref,
      byId,
      'same_vibe',
      'adjacent',
      wide,
      (c) => VibeShelf(tracks: c.tracks, currentUrn: currentUrn),
      (c) => ArtistWire(cluster: c, currentUrn: currentUrn),
      rightTone: RiverSectionTone.panel,
    ));

    final deep = byId['deep_cuts'];
    if (deep != null) {
      rows.add(_section(
        ref,
        'deep_cuts',
        RiverAnchorKind.node,
        DeepShelf(tracks: deep.tracks, currentUrn: currentUrn),
        tone: RiverSectionTone.deep,
      ));
    }

    return rows.where((w) => w is! SizedBox).toList();
  }

  Widget _pair(
    WidgetRef ref,
    Map<String, ResolvedCluster> byId,
    String leftId,
    String rightId,
    bool wide,
    Widget Function(ResolvedCluster) leftBody,
    Widget Function(ResolvedCluster) rightBody, {
    required RiverSectionTone rightTone,
  }) {
    final left = byId[leftId];
    final right = byId[rightId];
    if (left == null && right == null) return const SizedBox.shrink();

    final leftWidget = left == null
        ? null
        : _section(ref, leftId, RiverAnchorKind.node, leftBody(left));
    final rightWidget = right == null
        ? null
        : _section(
            ref,
            rightId,
            left != null ? RiverAnchorKind.branch : RiverAnchorKind.node,
            rightBody(right),
            tone: rightTone,
          );

    if (!wide || leftWidget == null || rightWidget == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (leftWidget != null) leftWidget,
          if (leftWidget != null && rightWidget != null)
            const SizedBox(height: 48),
          if (rightWidget != null) rightWidget,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 7, child: leftWidget),
        const SizedBox(width: 32),
        Expanded(flex: 5, child: rightWidget),
      ],
    );
  }

  Widget _section(
    WidgetRef ref,
    String id,
    RiverAnchorKind kind,
    Widget body, {
    RiverSectionTone tone = RiverSectionTone.open,
  }) {
    return _Anchor(
      id: id,
      kind: kind,
      register: registerAnchor,
      child: RiverSection(
        title: _clusterTitle(ref, id),
        why: _clusterWhy(ref, id),
        tone: tone,
        child: body,
      ),
    );
  }
}

/// Обёртка-якорь: репортит свою геометрию реке через [RiverAnchorSlot] (позиция
/// и размер после лэйаута). RiverBraid строит путь по этим точкам.
class _Anchor extends StatefulWidget {
  final String id;
  final RiverAnchorKind kind;
  final void Function(String, RiverAnchorSlot?) register;
  final Widget child;

  const _Anchor({
    required this.id,
    required this.kind,
    required this.register,
    required this.child,
  });

  @override
  State<_Anchor> createState() => _AnchorState();
}

class _AnchorState extends State<_Anchor> {
  final _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
  }

  @override
  void dispose() {
    widget.register(widget.id, null);
    super.dispose();
  }

  // Слот (key + kind) сам по себе не меняется — RiverBraid читает геометрию по
  // ключу. Перерепорт нужен только когда секция меняет размер (контент дозагрузился,
  // обложки растянулись), чтобы река пересняла путь. Каждый кадр — лишняя работа.
  void _report() {
    if (!mounted) return;
    widget.register(
      widget.id,
      RiverAnchorSlot(key: _key, kind: widget.kind),
    );
  }

  bool _onSizeChanged(SizeChangedLayoutNotification _) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: _onSizeChanged,
      child: SizeChangedLayoutNotifier(
        child: KeyedSubtree(key: _key, child: widget.child),
      ),
    );
  }
}

/// Дельта — эпилог реки: пунктирная плашка «течение продолжается».
class _DeltaNote extends ConsumerWidget {
  const _DeltaNote();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DottedRiverBox(
      child: Text(
        ref.tr('soundwave.river.deltaNote'),
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0x66FFFFFF),
          fontSize: 12,
          letterSpacing: 0.48,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

