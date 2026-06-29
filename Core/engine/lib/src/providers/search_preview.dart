import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../rust/api.dart';
import 'player.dart';

/// Контроллер hover-превью стены поиска (легаси `audioPreview`): один сэмпл за
/// раз, дебаунс на наведении, окно 15с, фейд на уход. Никогда не играет поверх
/// активного основного плеера и не сэмплит уже загруженный трек. `state` —
/// urn активного превью (или `null`); [progress] — 0..1 для кольца активной
/// плитки (тикает отдельно, чтобы не ребилдить плитку).
final searchPreviewProvider =
    NotifierProvider<SearchPreviewController, String?>(
  SearchPreviewController.new,
);

const _debounceMs = 400;
const _fadeMs = 500;
const _windowMs = 15000;
const _previewVolumeFactor = 0.85;

class SearchPreviewController extends Notifier<String?> {
  Timer? _debounce;
  Timer? _window;
  Timer? _ticker;
  int _gen = 0;
  final ValueNotifier<double> progress = ValueNotifier(0);

  @override
  String? build() {
    // Основной плеер стартовал / сменил трек → сэмпл недопустим, гасим.
    ref.listen(isPlayingProvider, (_, next) {
      if (next) stop();
    });
    ref.listen(playerProvider, (prev, next) {
      if (prev?.urn != next?.urn) stop();
    });
    ref.onDispose(() {
      _debounce?.cancel();
      _window?.cancel();
      _ticker?.cancel();
      progress.dispose();
    });
    return null;
  }

  bool _canPreview(String urn) {
    if (ref.read(isPlayingProvider)) return false;
    if (ref.read(playerProvider)?.urn == urn) return false;
    return true;
  }

  /// Навели плитку: после дебаунса дожать кэш и стартовать превью (если можно).
  void start(String urn) {
    if (state == urn) return;
    _debounce?.cancel();
    if (!_canPreview(urn)) return;
    final gen = ++_gen;
    _debounce = Timer(const Duration(milliseconds: _debounceMs), () async {
      if (gen != _gen || !_canPreview(urn)) return;
      final vol = (ref.read(volumeProvider) * _previewVolumeFactor).clamp(0.0, 2.0);
      try {
        await audioPreviewPlay(urn: urn, volume: vol);
      } catch (_) {
        return; // не загрузилось — просто не светится
      }
      if (gen != _gen) {
        audioPreviewStop(fadeMs: BigInt.zero);
        return;
      }
      state = urn;
      _runWindow();
    });
  }

  void _runWindow() {
    _window?.cancel();
    _ticker?.cancel();
    progress.value = 0;
    final started = DateTime.now();
    _window = Timer(const Duration(milliseconds: _windowMs), stop);
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final ms = DateTime.now().difference(started).inMilliseconds;
      progress.value = (ms / _windowMs).clamp(0.0, 1.0);
    });
  }

  /// Ушли / быстрый скролл / клик / уход со страницы: плавно гасим превью.
  void stop() {
    _debounce?.cancel();
    _window?.cancel();
    _ticker?.cancel();
    _gen++;
    if (state != null) {
      audioPreviewStop(fadeMs: BigInt.from(_fadeMs));
      state = null;
      progress.value = 0;
    }
  }
}
