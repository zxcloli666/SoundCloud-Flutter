import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import '../providers.dart';
import 'settings/about_section.dart';
import 'settings/account_section.dart';
import 'settings/appearance_section.dart';
import 'settings/audio_section.dart';
import 'settings/general_section.dart';
import 'settings/qr_link_sheet.dart';
import 'settings/settings_nav.dart';
import 'settings/settings_primitives.dart';
import 'settings/storage_section.dart';

/// Стартовый раздел (легаси `StartupCard`): id ленты → корень-таб. Индекс совпадает
/// с порядком вкладок сайдбара (`_tabRoots` в `root_shell`), который читает
/// `settingsProvider.startupTab`. «Настройки» — не таб-корень, для него
/// сохраняем сентинел [_settingsStartupTab].
const _startupTabs = <String, int>{
  'home': 0,
  'search': 1,
  'library': 3,
  'settings': _settingsStartupTab,
};
const int _settingsStartupTab = 100;

/// Настройки — star-lit двухпанельная мастерская (легаси §3.13): frosted-рельс
/// категорий слева, карточки активной категории справа, под атмосферой.
///
/// Проводка: громкость → `volumeProvider`, профиль/подписка → `me*`/`meSubscription`,
/// выход → `authProvider.notifier.logout()`, остальные настройки (perf/язык/старт/
/// качество/караоке/нормализация) — `settingsProvider`. «Передать сессию» поднимает
/// QR-лист в push-режиме (`showQrLinkSheet`, `qrLinkControllerProvider`).
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  SettingsCategory _active = SettingsCategory.general;
  final _scroll = SmoothScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Та же звёздная атмосфера, что в легаси SettingsFrame: орбы + звёздное поле
    // под контентом (перф-гейтед — в light не рисуется).
    return Atmosphere(
      energy: 0.32,
      child: Stack(
        children: [
          const Positioned.fill(child: ScStarField(intensity: 0.6, glow: false)),
          _content(),
        ],
      ),
    );
  }

  Widget _content() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Адаптив: на узких окнах рельс прячется (как `hidden md:block` в легаси).
        final showRail = constraints.maxWidth >= 768;
        return ListView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 136),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showRail) ...[
                      SettingsNav(
                        active: _active,
                        onChanged: (c) => setState(() => _active = c),
                      ),
                      const SizedBox(width: 32),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!showRail) _MobileTabs(
                            active: _active,
                            onChanged: (c) => setState(() => _active = c),
                          ),
                          _Header(category: _active),
                          const SizedBox(height: 24),
                          _body(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _body() {
    return switch (_active) {
      SettingsCategory.general => _general(),
      SettingsCategory.appearance => _appearance(),
      SettingsCategory.audio => _audio(),
      SettingsCategory.storage => _storage(),
      SettingsCategory.account => _account(),
      SettingsCategory.about => const AboutSection(),
    };
  }

  Widget _general() {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final startupId = _startupTabs.entries
        .firstWhere(
          (e) => e.value == settings.startupTab,
          orElse: () => const MapEntry('home', 0),
        )
        .key;
    return GeneralSection(
      language: settings.language,
      onLanguage: notifier.setLanguage,
      startupPage: startupId,
      onStartupPage: (id) => notifier.setStartupTab(_startupTabs[id] ?? 0),
      dpiBypass: settings.dpiBypass,
      onDpiBypass: notifier.setDpiBypass,
    );
  }

  Widget _appearance() {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    return AppearanceSection(
      accent: settings.accent,
      onAccent: notifier.setAccent,
      selected: settings.perfMode,
      onSelected: notifier.setPerfMode,
    );
  }

  Widget _storage() {
    final limitMB = ref.watch(settingsProvider.select((s) => s.audioCacheLimitMB));
    final notifier = ref.read(settingsProvider.notifier);
    final totalBytes = ref.watch(cacheTotalBytesProvider).value ?? 0;
    return StorageSection(
      totalBytes: totalBytes,
      limitMB: limitMB,
      onLimit: notifier.setAudioCacheLimitMB,
      onCacheLikes: _cacheLikes,
      onCancelCacheLikes: ref.read(likesCacheProvider.notifier).cancel,
      onClear: _clearCache,
    );
  }

  /// Докачать лайки в защищённый кэш с прогрессом. Уже закэшированные ядро
  /// пропускает само, поэтому отдаём весь загруженный список лайков.
  void _cacheLikes() {
    final likes = ref.read(likedTracksProvider).value?.items ?? const [];
    if (likes.isEmpty) return;
    final urns = [for (final t in likes) t.urn];
    ref.read(likesCacheProvider.notifier).start(urns);
  }

  /// Очистить обычный кэш (защищённый кэш лайков не трогается) + тост.
  Future<void> _clearCache() async {
    await ref.read(offlineControllerProvider.notifier).clearAll();
    if (mounted) {
      ToastScope.of(context).show(ref.tr('settings.cacheCleared'));
    }
  }

  Widget _audio() {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final volume = ref.watch(volumeProvider);
    final isPremium = ref.watch(meSubscriptionProvider).value ?? false;
    return AudioSection(
      volume: volume,
      onVolume: ref.read(volumeProvider.notifier).set,
      isPremium: isPremium,
      highQualityStreaming: settings.highQualityStreaming,
      onHighQualityStreaming: notifier.setHighQualityStreaming,
      lyricsVisualizer: settings.lyricsVisualizer,
      onLyricsVisualizer: notifier.setLyricsVisualizer,
      audioDevice: settings.audioDevice,
      onAudioDevice: notifier.setAudioDevice,
    );
  }

  Widget _account() {
    final me = ref.watch(meProvider).value;
    final isPremium = ref.watch(meSubscriptionProvider).value ?? false;
    return AccountSection(
      username: me?.username ?? '...',
      avatarUrl: me?.avatarUrl,
      isPremium: isPremium,
      // «Передать сессию»: QR в push-режиме — отдаём ТЕКУЩУЮ сессию телефону.
      onTransferSession: () => showQrLinkSheet(context, mode: 'push'),
      onSignOut: () => ref.read(authProvider.notifier).logout(),
    );
  }
}

/// Шапка контента: акцентный icon-тайл 48 + eyebrow + H1 с аура-градиентом
/// (легаси `header`).
class _Header extends StatelessWidget {
  final SettingsCategory category;

  const _Header({required this.category});

  @override
  Widget build(BuildContext context) {
    final palette = ScTheme.paletteOf(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AccentIconTile(icon: category.icon, size: 48, iconSize: 22),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'НАСТРОЙКИ',
                style: TextStyle(
                  color: Color(0x59FFFFFF),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.64, // tracking-[0.24em] @ 11px
                ),
              ),
              const SizedBox(height: 4),
              ShaderMask(
                shaderCallback: (rect) => LinearGradient(
                  colors: [Colors.white, palette.accent],
                ).createShader(rect),
                child: Text(
                  category.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    letterSpacing: -0.6,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Узкое окно: горизонтальная лента вкладок вместо рельса (адаптив).
class _MobileTabs extends StatelessWidget {
  final SettingsCategory active;
  final ValueChanged<SettingsCategory> onChanged;

  const _MobileTabs({required this.active, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: SettingsCategory.values.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final c = SettingsCategory.values[i];
            return _MobileTab(
              category: c,
              active: c == active,
              onTap: () => onChanged(c),
            );
          },
        ),
      ),
    );
  }
}

class _MobileTab extends StatelessWidget {
  final SettingsCategory category;
  final bool active;
  final VoidCallback onTap;

  const _MobileTab({
    required this.category,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ScTheme.paletteOf(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9999),
          color: active ? null : const Color(0x08FFFFFF),
          gradient: active
              ? LinearGradient(colors: [palette.accentGlow, const Color(0x0DFFFFFF)])
              : null,
          border: Border.all(
            color: active ? palette.accent : const Color(0x0FFFFFFF),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              category.icon,
              size: 15,
              color: active ? palette.accent : const Color(0x73FFFFFF),
            ),
            const SizedBox(width: 8),
            Text(
              category.label,
              style: TextStyle(
                color: active ? Colors.white : const Color(0x8CFFFFFF),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
