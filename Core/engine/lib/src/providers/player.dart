import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import '../config.dart';
import '../rust/api.dart';
import '../rust/data_social.dart';
import '../rust/dto.dart';
import '../ui/now_playing_bar/transport_state.dart';
import 'core.dart';
import 'home.dart';
import 'playback_persist.dart';
import 'queue.dart';
import 'settings.dart';

/// Позиция воспроизведения (latest-wins) из ядра. Один стрим на всех слушателей.
final positionStreamProvider = StreamProvider.autoDispose<double>((ref) {
  return positionStream();
});

/// Критические события плеера (Ended/TrackChanged) из ядра.
final playbackEventsProvider =
    StreamProvider.autoDispose<PlaybackEventDto>((ref) {
  return playbackEvents();
});

/// Прогресс скачки текущего трека (доля 0..1) из ядра — для кольца загрузки
/// в NowBar. Событие несёт `urn`: к индикатору применяем только для активного
/// трека (см. [PlayerLoadingNotifier]).
final downloadProgressProvider =
    StreamProvider.autoDispose<DownloadProgressDto>((ref) {
  return downloadProgress();
});

/// Список выходных аудиоустройств (для пикера в настройках). Перечитывается при
/// открытии настроек — устройства подключают/отключают на ходу.
final audioOutputDevicesProvider =
    FutureProvider.autoDispose<List<AudioDeviceDto>>((ref) {
  return audioOutputDevices();
});

/// Громкость 0..1 (источник истины — здесь, ядро её применяет).
final volumeProvider = NotifierProvider<VolumeNotifier, double>(
  VolumeNotifier.new,
);

class VolumeNotifier extends Notifier<double> {
  @override
  double build() => 1.0;

  /// 0..2.0 — за 1.0 (100%) идёт жёсткий буст до 200% (ядро клампит так же).
  Future<void> set(double value) async {
    final v = value.clamp(0.0, 2.0);
    await setVolume(volume: v);
    state = v;
  }
}

/// Играет ли сейчас плеер — синхронный наблюдаемый флаг (источник истины для
/// play/pause-глифа, спина винила и EQ в NowBar). Ядро отдаёт `is_playing` только
/// асинхронно, поэтому состояние держим здесь и флипаем в play/togglePause/stop;
/// конец трека гасит флаг через [playbackEventsProvider].
final isPlayingProvider = NotifierProvider<IsPlayingNotifier, bool>(
  IsPlayingNotifier.new,
);

class IsPlayingNotifier extends Notifier<bool> {
  @override
  bool build() {
    ref.listen(playbackEventsProvider, (_, next) {
      if (next.value is PlaybackEventDto_Ended) state = false;
    });
    return false;
  }

  void set(bool playing) => state = playing;
}

/// Текущий трек. Воспроизведение делегируется ядру через мост.
final playerProvider = NotifierProvider<PlayerNotifier, TrackDto?>(
  PlayerNotifier.new,
);

/// Состояние загрузки трека (скачка+транскод) для индикатора в NowBar.
/// `percent` — null, пока нет точного прогресса (стрим из кэша добавим позже);
/// `loading=true` уже даёт кольцо/вуаль «грузится».
class PlayerLoading {
  final bool loading;
  final double? percent;
  const PlayerLoading({this.loading = false, this.percent});
  static const idle = PlayerLoading();
}

/// Грузится ли сейчас выбранный трек (для NowBar). Ставится сразу на клике, чтобы
/// пользователь видел: трек выбран и качается, а не «непонятно что происходит».
final playerLoadingProvider =
    NotifierProvider<PlayerLoadingNotifier, PlayerLoading>(
  PlayerLoadingNotifier.new,
);

class PlayerLoadingNotifier extends Notifier<PlayerLoading> {
  @override
  PlayerLoading build() {
    // Прогресс скачки из ядра → процент кольца. Только пока грузимся и только
    // для активного трека: события скачки предыдущего трека (urn не совпал)
    // игнорируем, иначе процент бы прыгал между треками.
    ref.listen(downloadProgressProvider, (_, next) {
      final dto = next.value;
      if (dto == null || !state.loading) return;
      final current = ref.read(playerProvider)?.urn;
      if (current == null || !_sameTrackId(current, dto.urn)) return;
      state = PlayerLoading(loading: true, percent: dto.fraction);
    });
    return PlayerLoading.idle;
  }

  void start() => state = const PlayerLoading(loading: true);
  void progress(double p) => state = PlayerLoading(loading: true, percent: p);
  void done() => state = PlayerLoading.idle;
}

/// Сравнение urn по голому id-хвосту: `urn` приходит то URN, то голым id
/// (см. историю багов user_id) — сравниваем хвост после `:`.
bool _sameTrackId(String a, String b) => a.split(':').last == b.split(':').last;

/// Последний запрошенный трек + его очередь — для latest-wins сериализации тыков.
class _PendingPlay {
  final TrackDto track;
  final List<TrackDto>? queue;
  const _PendingPlay(this.track, this.queue);
}

class PlayerNotifier extends Notifier<TrackDto?> {
  @override
  TrackDto? build() => null;

  // Сериализация запусков: быстрые тыки не наслаивают конкурентные playTrack
  // (иначе позже-завершившийся в Rust перетирает выбор). Берём последний намерен.
  _PendingPlay? _pending;
  bool _busy = false;

  // Загружен ли текущий [state] в движок. `false` у восстановленного на старте
  // трека (показан в NowBar, но в Rust ничего нет) — первый play догрузит.
  bool _loaded = false;

  /// Запустить [track]. Если задан [queue] — это пользовательский список
  /// (лайки/альбом/плейлист/поиск), из которого идёт воспроизведение: он
  /// становится активным контекстом очереди, и [PlaybackQueueNotifier] сначала
  /// доигрывает его, ПОТОМ продолжает волной. Без [queue] контекст сбрасывается
  /// (одиночный трек со страницы/NowBar) — очередь сразу падает в волну.
  ///
  /// Latest-wins: пока трек грузится, новый запрос откладывается; по завершении
  /// текущего играем последний запрошенный, промежуточные схлопываются.
  Future<void> play(TrackDto track, {List<TrackDto>? queue}) async {
    _pending = _PendingPlay(track, queue);
    // Сразу переключаем NowBar на кликнутый трек + показываем загрузку (как Tauri),
    // не дожидаясь конца скачки/транскода — иначе «тыкаешь и непонятно что идёт».
    state = track;
    ref.read(playerLoadingProvider.notifier).start();
    // Системные контролы (MPRIS/Discord/трей) переключаем на новый трек СРАЗУ —
    // пока он качается, нельзя показывать старый как играющий.
    final media = ref.read(scConfigProvider).media;
    media?.onNowPlaying?.call(_mediaTrack(track));
    media?.onPlaying?.call(true);
    if (_busy) return;
    _busy = true;
    try {
      while (_pending != null) {
        final req = _pending!;
        _pending = null;
        state = req.track; // показываем последний запрошенный
        try {
          await playTrack(urn: req.track.urn);
        } catch (_) {
          // Ошибку показываем только если это последний намеренный трек.
          if (_pending == null) {
            ref.read(playerLoadingProvider.notifier).done();
            // Откатываем оптимистичный Playing (ставили в начале) — трек не пошёл.
            _loaded = false;
            ref.read(isPlayingProvider.notifier).set(false);
            media?.onPlaying?.call(false);
            rethrow;
          }
          continue;
        }
        // Появился более новый запрос, пока грузились — этот не «закрепляем».
        if (_pending != null) continue;
        _applyEq();
        _enforceCacheLimit();
        _setContext(req.track, req.queue);
        _loaded = true;
        ref.read(isPlayingProvider.notifier).set(true);
        ref.read(playerLoadingProvider.notifier).done();
        _persist();
        _preloadNext();
        // Подтверждаем мету системным контролам по факту старта (req.track —
        // последний закреплённый; мог отличаться от показанного в начале).
        media?.onNowPlaying?.call(_mediaTrack(req.track));
        media?.onPlaying?.call(true);
      }
    } finally {
      _busy = false;
    }
  }

  /// Применить сохранённый эквалайзер к свежезагруженному треку: ядро поднимает
  /// фильтр-цепь на каждый источник, поэтому EQ переустанавливается после старта.
  void _applyEq() {
    final eq = ref.read(settingsProvider);
    setEq(enabled: eq.eqEnabled, gains: eq.eqGains);
  }

  /// Подрезать обычный аудиокэш под лимит после скачки (как Tauri `audio.ts`).
  /// Защищённый кэш лайков не трогается. Fire-and-forget.
  void _enforceCacheLimit() {
    final limit = ref.read(settingsProvider).audioCacheLimitMB;
    if (limit > 0) cacheEnforceLimit(limitMb: BigInt.from(limit));
  }

  void _setContext(TrackDto track, List<TrackDto>? queue) {
    final ctx = ref.read(queueContextProvider.notifier);
    if (queue == null) {
      ctx.clear();
      return;
    }
    final idx = queue.indexWhere((t) => _sameTrackId(t.urn, track.urn));
    ctx.set(queue, idx < 0 ? 0 : idx);
  }

  Future<void> togglePause() async {
    // Восстановленный на старте трек ещё не загружен в движок — первый клик
    // play догружает и запускает его (resume на пустом движке был бы no-op).
    final restored = state;
    if (!_loaded && restored != null) {
      await play(restored, queue: ref.read(queueContextProvider)?.tracks);
      return;
    }
    final wasPlaying = await isPlaying();
    if (wasPlaying) {
      await pause();
    } else {
      await resume();
    }
    ref.read(isPlayingProvider.notifier).set(!wasPlaying);
    ref.read(scConfigProvider).media?.onPlaying?.call(!wasPlaying);
  }

  Future<void> stopPlayback() async {
    await stop();
    state = null;
    _loaded = false;
    ref.read(playbackPersistProvider).clear();
    ref.read(isPlayingProvider.notifier).set(false);
    ref.read(scConfigProvider).media
      ?..onPlaying?.call(false)
      ..onClear?.call();
  }

  Future<void> seekTo(double positionSecs) => seek(positionSecs: positionSecs);

  /// Ядро авто-переехало на другой трек (gapless/предзагрузка) — синхронизируем
  /// now-playing, не дёргая повторный `playTrack`.
  Future<void> adoptCurrent(String urn) async {
    if (state?.urn == urn) return;
    final track = await resolveTrack(urn: urn);
    if (track == null) return;
    state = track;
    _loaded = true;
    ref.read(isPlayingProvider.notifier).set(true);
    _persist();
    final media = ref.read(scConfigProvider).media;
    media?.onNowPlaying?.call(_mediaTrack(track));
    media?.onPlaying?.call(true);
  }

  /// Снимок трека для системных контролов (обложка/длительность/ссылка).
  ScMediaTrack _mediaTrack(TrackDto t) => ScMediaTrack(
        title: t.title,
        artist: t.artistName,
        artworkUrl: t.artworkUrl,
        trackUrl: t.permalinkUrl,
        durationSecs: t.durationMs.toInt() / 1000.0,
      );

  /// Прогреть следующий трек активного списка в фоне (gapless-переход): ядро
  /// качает+транскодит его, пока играет текущий. Без списка/в конце — no-op.
  void _preloadNext() {
    final ctx = ref.read(queueContextProvider);
    if (ctx != null && ctx.hasNext) {
      trackPreload(urn: ctx.tracks[ctx.index + 1].urn);
    }
  }

  /// Сохранить снимок текущего воспроизведения (трек + очередь + транспорт) на
  /// диск — чтобы подхватить при следующем запуске. Зовётся при смене трека.
  void _persist() {
    final track = state;
    if (track == null) return;
    final ctx = ref.read(queueContextProvider);
    final transport = ref.read(nowBarTransportProvider);
    ref.read(playbackPersistProvider).save(PlaybackSnapshot(
          trackUrn: track.urn,
          queueUrns: ctx?.tracks.map((t) => t.urn).toList() ?? const [],
          queueIndex: ctx?.index ?? 0,
          volume: ref.read(volumeProvider),
          shuffle: transport.shuffle,
          repeat: transport.repeat.name,
        ));
  }

  /// Подхватить последнее воспроизведение на старте: показать трек в NowBar на
  /// паузе (как легаси — `isPlaying`/позиция не персистятся), восстановить
  /// очередь/громкость/транспорт. В движок ничего не грузим — первый клик play
  /// догрузит ([togglePause]). Очередь резолвится в фоне: NowBar показывает трек
  /// сразу, не дожидаясь списка.
  Future<void> restore(PlaybackSnapshot snap) async {
    ref.read(nowBarTransportProvider.notifier).hydrate(
          shuffle: snap.shuffle,
          repeat: NowBarRepeat.values.firstWhere(
            (r) => r.name == snap.repeat,
            orElse: () => NowBarRepeat.off,
          ),
        );
    ref.read(volumeProvider.notifier).set(snap.volume);
    final track = await resolveTrack(urn: snap.trackUrn);
    // Пользователь успел что-то запустить, пока резолвился трек — не перетираем.
    if (track == null || state != null || _busy) return;
    state = track;
    _loaded = false;
    if (snap.queueUrns.isEmpty) return;
    final resolved = (await Future.wait(
      snap.queueUrns.map((u) => resolveTrack(urn: u)),
    ))
        .whereType<TrackDto>()
        .toList();
    if (state?.urn == track.urn && resolved.isNotEmpty) {
      ref.read(queueContextProvider.notifier).set(resolved, snap.queueIndex);
    }
  }
}

/// Очередь воспроизведения: что играет ПОСЛЕ текущего трека.
///
/// Инвариант queue-continuation: если активен пользовательский список
/// ([queueContextProvider] — лайки/альбом/плейлист/поиск), сначала доигрываем
/// его до конца, ПОТОМ продолжаем из бесконечной волны ([waveProvider]); хвост
/// волны догружается заранее, чтобы переход был без паузы. Один писатель
/// now-playing — [PlayerNotifier]; здесь только выбор следующего.
final playbackQueueProvider =
    NotifierProvider<PlaybackQueueNotifier, void>(PlaybackQueueNotifier.new);

class PlaybackQueueNotifier extends Notifier<void> {
  @override
  void build() {}

  /// Конец трека: repeat-one перезапускает текущий; иначе берём следующий —
  /// сначала из активного списка, затем (когда список исчерпан) из волны. На
  /// пустой/исчерпанной волне останавливаемся (ядро уже отыграло).
  Future<void> onEnded() async {
    // Идёт пользовательская загрузка трека — авто-продолжение очереди не лезет
    // (иначе наложится на явный выбор и «перепрыгнет» на следующий).
    if (ref.read(playerLoadingProvider).loading) return;
    final repeat = ref.read(nowBarTransportProvider).repeat;
    final player = ref.read(playerProvider.notifier);
    final current = ref.read(playerProvider);

    if (repeat == NowBarRepeat.one && current != null) {
      // Перезапуск в пределах того же контекста — не трогаем указатель списка.
      await player.play(current, queue: _activeQueue());
      return;
    }

    final fromContext = _nextInContext();
    if (fromContext != null) {
      // play() переставит указатель контекста на этот трек (см. _setContext).
      await player.play(fromContext, queue: _activeQueue());
      return;
    }

    // Список доигран — дальше волна (контекст уже не нужен).
    final next = await _resolveNext(current);
    if (next != null) {
      await player.play(next);
    } else if (repeat != NowBarRepeat.all) {
      await player.stopPlayback();
    }
  }

  /// Явный «следующий» (кнопка/трей/MPRIS): следующий в активном списке, иначе
  /// продолжение из волны ([onEnded]).
  Future<void> next() async {
    final ctx = ref.read(queueContextProvider);
    if (ctx != null && ctx.hasNext) {
      await ref
          .read(playerProvider.notifier)
          .play(ctx.tracks[ctx.index + 1], queue: ctx.tracks);
      return;
    }
    await onEnded();
  }

  /// Явный «предыдущий»: предыдущий в активном списке, иначе перемотка текущего
  /// в начало.
  Future<void> previous() async {
    final ctx = ref.read(queueContextProvider);
    final player = ref.read(playerProvider.notifier);
    if (ctx != null && ctx.hasPrev) {
      await player.play(ctx.tracks[ctx.index - 1], queue: ctx.tracks);
      return;
    }
    await player.seekTo(0);
  }

  /// Текущий активный список (для сохранения контекста при play следующего из
  /// него). `null`, если списка нет.
  List<TrackDto>? _activeQueue() => ref.read(queueContextProvider)?.tracks;

  /// Следующий трек в пределах активного списка, либо `null` если списка нет или
  /// он исчерпан (тогда падаем в волну).
  TrackDto? _nextInContext() {
    final ctx = ref.read(queueContextProvider);
    if (ctx == null || !ctx.hasNext) return null;
    return ctx.tracks[ctx.index + 1];
  }

  /// Следующий трек после [current] из волны. Догружает хвост волны, когда тот
  /// заканчивается; `null` — следующего нет.
  Future<TrackDto?> _resolveNext(TrackDto? current) async {
    final wave = ref.read(waveProvider.notifier);
    var items = ref.read(waveProvider).value?.items ?? const [];

    if (current == null) {
      return items.isEmpty ? null : _resolveItem(items.first);
    }

    var index = _indexOf(items, current.urn);
    if (index >= 0 && index + 1 >= items.length) {
      await wave.next();
      items = ref.read(waveProvider).value?.items ?? items;
      index = _indexOf(items, current.urn);
    }

    for (var i = index + 1; i < items.length; i++) {
      final track = await _resolveItem(items[i]);
      if (track != null) return track;
    }
    return null;
  }

  Future<TrackDto?> _resolveItem(WaveItemDto item) =>
      resolveTrack(urn: 'soundcloud:tracks:${item.id}');

  /// Поиск по голому id: `TrackDto.urn` приходит то URN, то голым id (см. историю
  /// багов user_id) — сравниваем хвост после `:`, чтобы формы не расходились.
  int _indexOf(List<WaveItemDto> items, String urn) {
    final bare = urn.split(':').last;
    for (var i = 0; i < items.length; i++) {
      if (items[i].id.toString() == bare) return i;
    }
    return -1;
  }
}
