import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../../providers.dart';
import '../../../rust/api.dart';

/// Эквалайзер NowBar: [EqualizerPanel] поверх состояния [settingsProvider].
/// Любая правка пишется в настройки (persist) и тут же применяется ядром через
/// `setEq(enabled, gains)` — power-тумблер шлёт плоские нули при выключении.
class EqualizerHost extends ConsumerWidget {
  final VoidCallback onClose;

  const EqualizerHost({super.key, required this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return EqualizerPanel(
      title: 'Эквалайзер',
      presetLabel: 'Пресет',
      enabled: settings.eqEnabled,
      activePresetId: settings.eqPreset,
      bands: [
        for (var i = 0; i < eqBandCount; i++)
          EqualizerBand(label: eqBandLabels[i], gain: settings.eqGains[i]),
      ],
      presets: eqPresets,
      onBandChange: (index, gain) {
        notifier.setEqBand(index, gain);
        _apply(ref, settings.eqEnabled, _withBand(settings.eqGains, index, gain));
      },
      onPreset: (id) {
        final preset = eqPresets.firstWhere((p) => p.id == id);
        notifier.setEqGains(preset.gains);
        notifier.setEqPreset(id);
        _apply(ref, settings.eqEnabled, preset.gains);
      },
      onToggleEnabled: () {
        final next = !settings.eqEnabled;
        notifier.setEqEnabled(next);
        _apply(ref, next, settings.eqGains);
      },
      onReset: () {
        notifier.setEqGains(eqFlatGains);
        notifier.setEqPreset('flat');
        _apply(ref, settings.eqEnabled, eqFlatGains);
      },
      onClose: onClose,
    );
  }

  List<double> _withBand(List<double> gains, int index, double gain) =>
      List.of(gains)..[index] = gain;

  void _apply(WidgetRef ref, bool enabled, List<double> gains) {
    setEq(enabled: enabled, gains: gains);
  }
}
