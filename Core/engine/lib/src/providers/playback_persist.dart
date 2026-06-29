import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core.dart';

/// Снимок последнего воспроизведения (легаси `sc-player` persist-store): чем
/// заняться при следующем запуске. Храним URN'ы, не сами DTO — трек/очередь
/// ре-резолвятся ядром на старте (всегда свежие данные, без хрупкой сериализации
/// сгенерированных мостом структур). Позиция/`isPlaying` НЕ сохраняются: как в
/// легаси, трек подхватывается на паузе с начала.
class PlaybackSnapshot {
  final String trackUrn;
  final List<String> queueUrns;
  final int queueIndex;
  final double volume;
  final bool shuffle;
  final String repeat;

  const PlaybackSnapshot({
    required this.trackUrn,
    this.queueUrns = const [],
    this.queueIndex = 0,
    this.volume = 1,
    this.shuffle = false,
    this.repeat = 'off',
  });

  Map<String, dynamic> toJson() => {
        'trackUrn': trackUrn,
        'queueUrns': queueUrns,
        'queueIndex': queueIndex,
        'volume': volume,
        'shuffle': shuffle,
        'repeat': repeat,
      };

  factory PlaybackSnapshot.fromJson(Map<String, dynamic> j) => PlaybackSnapshot(
        trackUrn: j['trackUrn'] as String? ?? '',
        queueUrns:
            (j['queueUrns'] as List?)?.map((e) => e.toString()).toList() ??
                const [],
        queueIndex: (j['queueIndex'] as num?)?.toInt() ?? 0,
        volume: (j['volume'] as num?)?.toDouble() ?? 1,
        shuffle: j['shuffle'] as bool? ?? false,
        repeat: j['repeat'] as String? ?? 'off',
      );
}

/// Чтение/запись снимка воспроизведения в `<dataDir>/playback.json`. Пишет
/// [PlayerNotifier] при смене трека, читает шелл один раз на старте.
final playbackPersistProvider = Provider<PlaybackPersist>(PlaybackPersist.new);

class PlaybackPersist {
  PlaybackPersist(this._ref);

  final Ref _ref;

  File? _file() {
    final dir = _ref.read(scConfigProvider).dataDir;
    if (dir.isEmpty) return null;
    return File('$dir/playback.json');
  }

  void save(PlaybackSnapshot snapshot) {
    final file = _file();
    if (file == null) return;
    try {
      file.writeAsStringSync(jsonEncode(snapshot.toJson()));
    } catch (_) {}
  }

  void clear() {
    final file = _file();
    if (file == null) return;
    try {
      if (file.existsSync()) file.deleteSync();
    } catch (_) {}
  }

  PlaybackSnapshot? load() {
    final file = _file();
    if (file == null || !file.existsSync()) return null;
    try {
      final snap = PlaybackSnapshot.fromJson(
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
      );
      return snap.trackUrn.isEmpty ? null : snap;
    } catch (_) {
      return null;
    }
  }
}
