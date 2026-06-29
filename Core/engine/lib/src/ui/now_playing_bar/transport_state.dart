import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

/// UI-состояние транспорта NowBar, которого нет в ядре: shuffle / repeat /
/// AB-петля / мьют (legacy player-store §2.4). Держим его здесь, чтобы кнопки
/// пилюли отражали реальные переключения пользователя, а не были декорацией.
class NowBarTransport {
  final bool shuffle;
  final NowBarRepeat repeat;
  final double? abLoopA;
  final double? abLoopB;
  final bool muted;
  final double volumeBeforeMute;

  const NowBarTransport({
    this.shuffle = false,
    this.repeat = NowBarRepeat.off,
    this.abLoopA,
    this.abLoopB,
    this.muted = false,
    this.volumeBeforeMute = 1,
  });

  bool get abLoopAwaitingB => abLoopA != null && abLoopB == null;

  NowBarTransport copyWith({
    bool? shuffle,
    NowBarRepeat? repeat,
    double? Function()? abLoopA,
    double? Function()? abLoopB,
    bool? muted,
    double? volumeBeforeMute,
  }) {
    return NowBarTransport(
      shuffle: shuffle ?? this.shuffle,
      repeat: repeat ?? this.repeat,
      abLoopA: abLoopA != null ? abLoopA() : this.abLoopA,
      abLoopB: abLoopB != null ? abLoopB() : this.abLoopB,
      muted: muted ?? this.muted,
      volumeBeforeMute: volumeBeforeMute ?? this.volumeBeforeMute,
    );
  }
}

final nowBarTransportProvider =
    NotifierProvider<NowBarTransportNotifier, NowBarTransport>(
  NowBarTransportNotifier.new,
);

class NowBarTransportNotifier extends Notifier<NowBarTransport> {
  @override
  NowBarTransport build() => const NowBarTransport();

  void toggleShuffle() => state = state.copyWith(shuffle: !state.shuffle);

  void cycleRepeat() {
    const order = [NowBarRepeat.off, NowBarRepeat.all, NowBarRepeat.one];
    final next = order[(order.indexOf(state.repeat) + 1) % order.length];
    state = state.copyWith(repeat: next);
  }

  /// AB-петля: первый клик ставит точку A на [positionSecs], второй — точку B
  /// (с минимальным зазором), третий — сбрасывает.
  void cycleAbLoop(double positionSecs) {
    const minGap = 0.2;
    if (state.abLoopA == null) {
      state = state.copyWith(abLoopA: () => positionSecs, abLoopB: () => null);
    } else if (state.abLoopB == null) {
      final a = state.abLoopA!;
      final b = positionSecs > a + minGap ? positionSecs : a + minGap;
      state = state.copyWith(abLoopB: () => b);
    } else {
      state = state.copyWith(abLoopA: () => null, abLoopB: () => null);
    }
  }

  /// Переключить мьют. Возвращает целевую громкость для ядра: 0 при мьюте,
  /// либо запомненную до-мьютную при размьюте.
  double toggleMute(double currentVolume) {
    if (state.muted) {
      final restore = state.volumeBeforeMute;
      state = state.copyWith(muted: false);
      return restore;
    }
    state = state.copyWith(muted: true, volumeBeforeMute: currentVolume);
    return 0;
  }

  /// Восстановить shuffle/repeat из сохранённого снимка (старт приложения).
  void hydrate({required bool shuffle, required NowBarRepeat repeat}) =>
      state = state.copyWith(shuffle: shuffle, repeat: repeat);
}
