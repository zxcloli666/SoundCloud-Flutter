import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../rust/api.dart' show AudioDeviceDto;
import 'settings_primitives.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Звук: громкость (реально проводится через `volumeProvider`) + переключатели
/// воспроизведения (легаси `PlaybackCard`). Качество HQ-стриминга — премиум-гейт:
/// без подписки показывает Star-бейдж + locked-переключатель.
class AudioSection extends ConsumerWidget {
  final double volume;
  final ValueChanged<double> onVolume;
  final bool isPremium;

  final bool highQualityStreaming;
  final ValueChanged<bool> onHighQualityStreaming;
  final bool lyricsVisualizer;
  final ValueChanged<bool> onLyricsVisualizer;
  final String? audioDevice;
  final ValueChanged<String?> onAudioDevice;

  const AudioSection({
    super.key,
    required this.volume,
    required this.onVolume,
    required this.isPremium,
    required this.highQualityStreaming,
    required this.onHighQualityStreaming,
    required this.lyricsVisualizer,
    required this.onLyricsVisualizer,
    required this.audioDevice,
    required this.onAudioDevice,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsCard(
          title: 'Громкость',
          icon: LucideIcons.volume2,
          description: 'Общий уровень воспроизведения.',
          action: Text(
            '${(volume * 100).round()}%',
            style: const TextStyle(
              color: Color(0xCCFFFFFF),
              fontSize: 13,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          child: SettingsSlider(
            value: volume,
            divisions: 100,
            onChanged: onVolume,
          ),
        ),
        const SizedBox(height: 20),
        SettingsCard(
          title: ref.tr('settings.playback'),
          icon: LucideIcons.headphones,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SettingsRow(
                title: Text(ref.tr('settings.lyricsVisualizer')),
                description: ref.tr('settings.lyricsVisualizerDesc'),
                trailing: SettingsToggle(
                  value: lyricsVisualizer,
                  onChanged: onLyricsVisualizer,
                ),
              ),
              const SettingsDivider(),
              SettingsRow(
                title: Text(ref.tr('settings.highQualityStreaming')),
                description: ref.tr('settings.highQualityStreamingDesc'),
                trailing: isPremium
                    ? SettingsToggle(
                        value: highQualityStreaming,
                        onChanged: onHighQualityStreaming,
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          PremiumLockBadge(),
                          SizedBox(width: 8),
                          LockedToggle(),
                        ],
                      ),
              ),
              const SettingsDivider(),
              SettingsRow(
                title: Text(ref.tr('settings.audioDevice')),
                trailing: _DevicePicker(
                  devices: ref.watch(audioOutputDevicesProvider).value ?? const [],
                  selected: audioDevice,
                  defaultLabel: ref.tr('settings.audioDeviceDefault'),
                  onSelected: onAudioDevice,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Пикер аудиовыхода: текущее устройство + выпадающий список (включая «системный
/// по умолчанию» = `null`). Имена устройств не переводятся.
class _DevicePicker extends StatelessWidget {
  final List<AudioDeviceDto> devices;
  final String? selected;
  final String defaultLabel;
  final ValueChanged<String?> onSelected;

  const _DevicePicker({
    required this.devices,
    required this.selected,
    required this.defaultLabel,
    required this.onSelected,
  });

  /// Человекочитаемое имя текущего выбора: описание устройства по сохранённому
  /// `name`, иначе «по умолчанию».
  String get _currentLabel {
    if (selected == null) return defaultLabel;
    for (final d in devices) {
      if (d.name == selected) return d.description;
    }
    return selected!;
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String?>(
      tooltip: '',
      color: const Color(0xFF1A1A1F),
      position: PopupMenuPosition.under,
      onSelected: onSelected,
      itemBuilder: (context) => [
        PopupMenuItem<String?>(value: null, child: Text(defaultLabel)),
        for (final d in devices)
          PopupMenuItem<String?>(value: d.name, child: Text(d.description)),
      ],
      child: Container(
        constraints: const BoxConstraints(maxWidth: 220),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0x08FFFFFF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0x14FFFFFF)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                _currentLabel,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xCCFFFFFF),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(LucideIcons.chevronDown, size: 16, color: Color(0x99FFFFFF)),
          ],
        ),
      ),
    );
  }
}
