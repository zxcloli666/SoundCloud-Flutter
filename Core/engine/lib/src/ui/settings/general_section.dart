import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import 'call_card.dart';
import 'settings_primitives.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Основные: язык интерфейса и стартовая страница (легаси general → Language +
/// Startup). [language]/[startupPage] проводятся через `settingsProvider`
/// (`setLanguage`/`setStartupTab`); страница мапит id ленты на индекс таб-корня.
class GeneralSection extends ConsumerWidget {
  final String language;
  final ValueChanged<String> onLanguage;
  final String startupPage;
  final ValueChanged<String> onStartupPage;
  final bool dpiBypass;
  final ValueChanged<bool> onDpiBypass;

  const GeneralSection({
    super.key,
    required this.language,
    required this.onLanguage,
    required this.startupPage,
    required this.onStartupPage,
    required this.dpiBypass,
    required this.onDpiBypass,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsCard(
          title: ref.tr('settings.language'),
          icon: LucideIcons.languages,
          // Названия языков — эндонимы, не переводятся.
          child: SettingsSegmented<String>(
            value: language,
            onChanged: onLanguage,
            options: const [
              SegmentedOption('en', 'English'),
              SegmentedOption('ru', 'Русский'),
              SegmentedOption('tr', 'Türkçe'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SettingsCard(
          title: ref.tr('settings.startup'),
          icon: LucideIcons.house,
          description: ref.tr('settings.startupPageDesc'),
          child: SettingsSegmented<String>(
            value: startupPage,
            onChanged: onStartupPage,
            columns: 2,
            options: [
              SegmentedOption('home', ref.tr('nav.home')),
              SegmentedOption('search', ref.tr('nav.search')),
              SegmentedOption('library', ref.tr('nav.library')),
              SegmentedOption('settings', ref.tr('nav.settings')),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SettingsCard(
          title: ref.tr('settings.connection'),
          icon: LucideIcons.shield,
          child: SettingsRow(
            title: Text(ref.tr('settings.dpiBypass')),
            description: ref.tr('settings.dpiBypassDesc'),
            trailing: SettingsToggle(value: dpiBypass, onChanged: onDpiBypass),
          ),
        ),
        const SizedBox(height: 20),
        const CallCard(),
      ],
    );
  }
}
