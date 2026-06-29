import 'package:flutter/material.dart';

import 'settings_primitives.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// О приложении: ссылки на сообщество. БЕЗ поля версии — в Tauri-настройках его
/// не было, выдумывать нельзя. (Содержимое будет приведено к 1:1 в фазе страниц.)
class AboutSection extends StatelessWidget {
  const AboutSection({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      title: 'SoundCloud',
      icon: LucideIcons.audioLines,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const _LinkRow(label: 'Discord', value: 'discord.gg/xQcGBP8fGG'),
          const SettingsDivider(),
          const _LinkRow(label: 'Boosty', value: 'boosty.to/lolinamide'),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  final String label;
  final String value;

  const _LinkRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return SettingsRow(
      title: Text(label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(color: Color(0x73FFFFFF), fontSize: 12.5),
          ),
          const SizedBox(width: 6),
          const Icon(LucideIcons.externalLink, size: 13, color: Color(0x59FFFFFF)),
        ],
      ),
    );
  }
}
