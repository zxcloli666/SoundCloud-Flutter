import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../offline/offline_model.dart' show formatBytes;
import 'settings_primitives.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Хранилище (легаси CacheCard): объём кэша + защищённый кэш лайков, докачка
/// лайков с прогрессом, потолок аудиокэша и очистка. Данные — через
/// `cacheTotalBytesProvider`/`cacheLikedBytesProvider`; докачка — `likesCacheProvider`.
class StorageSection extends ConsumerWidget {
  final int totalBytes;
  final int limitMB;
  final ValueChanged<int> onLimit;
  final VoidCallback onCacheLikes;
  final VoidCallback onCancelCacheLikes;
  final VoidCallback onClear;

  const StorageSection({
    super.key,
    required this.totalBytes,
    required this.limitMB,
    required this.onLimit,
    required this.onCacheLikes,
    required this.onCancelCacheLikes,
    required this.onClear,
  });

  static const int _maxMB = 8192;
  static const int _stepMB = 256;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likedBytes = ref.watch(cacheLikedBytesProvider).value ?? 0;
    final likes = ref.watch(likesCacheProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsCard(
          title: ref.tr('settings.cache'),
          icon: LucideIcons.hardDrive,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SettingsRow(
                title: Text(ref.tr('settings.total')),
                trailing: _value(formatBytes(totalBytes)),
              ),
              const SettingsDivider(),
              SettingsRow(
                title: Text(ref.tr('settings.likedCacheSize')),
                trailing: _value(formatBytes(likedBytes)),
              ),
              const SettingsDivider(),
              SettingsRow(
                title: Text(ref.tr('settings.cacheLikes')),
                description: ref.tr('settings.cacheLikesDesc'),
                trailing: _CacheLikesButton(
                  state: likes,
                  label: likes.running
                      ? ref.tr('settings.cacheLikesProgress',
                          {'done': likes.done, 'total': likes.total})
                      : ref.tr('settings.cacheLikes'),
                  onTap: likes.running ? onCancelCacheLikes : onCacheLikes,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SettingsCard(
          title: ref.tr('settings.audioCacheLimit'),
          icon: Icons.data_usage_rounded,
          description: ref.tr('settings.audioCacheLimitDesc'),
          action: _value(limitMB == 0 ? ref.tr('settings.unlimited') : '$limitMB МБ'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SettingsSlider(
                value: limitMB.toDouble(),
                min: 0,
                max: _maxMB.toDouble(),
                divisions: _maxMB ~/ _stepMB,
                onChanged: (v) => onLimit((v / _stepMB).round() * _stepMB),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: _ClearButton(
                  label: ref.tr('settings.clearCache'),
                  onTap: onClear,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _value(String text) => Text(
        text,
        style: const TextStyle(
          color: Color(0xCCFFFFFF),
          fontSize: 13,
          fontWeight: FontWeight.w700,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      );
}

/// Кнопка докачки лайков: показывает прогресс `{{done}}/{{total}}` пока идёт
/// (тап отменяет), иначе запускает.
class _CacheLikesButton extends StatefulWidget {
  final LikesCacheState state;
  final String label;
  final VoidCallback onTap;

  const _CacheLikesButton({
    required this.state,
    required this.label,
    required this.onTap,
  });

  @override
  State<_CacheLikesButton> createState() => _CacheLikesButtonState();
}

class _CacheLikesButtonState extends State<_CacheLikesButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final running = widget.state.running;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _hover ? const Color(0x14FFFFFF) : const Color(0x08FFFFFF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0x14FFFFFF)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                running ? LucideIcons.x : LucideIcons.download,
                size: 14,
                color: const Color(0xB3FFFFFF),
              ),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: const TextStyle(
                  color: Color(0xCCFFFFFF),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Кнопка очистки обычного кэша (защищённый кэш лайков не трогается).
class _ClearButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _ClearButton({required this.label, required this.onTap});

  @override
  State<_ClearButton> createState() => _ClearButtonState();
}

class _ClearButtonState extends State<_ClearButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _hover ? const Color(0x1AFF5252) : const Color(0x0DFF5252),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0x26FF5252)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.trash2,
                  size: 14, color: Color(0xCCFF8A80)),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: const TextStyle(
                  color: Color(0xE6FF8A80),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
