import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings.dart';
import 'translations.dart';

export 'translations.dart' show I18nStore, Translations;

/// Однократная загрузка всех локалей. Шелл ждёт её в boot-гейте, чтобы [tr] был
/// готов синхронно к первому кадру.
final i18nStoreProvider = FutureProvider<I18nStore>((ref) => I18nStore.load());

/// Активные переводы: язык из настроек, фолбэк en. Реактивно — смена языка в
/// настройках перестраивает зависимые виджеты. До загрузки локалей — echo-ключи.
final translationsProvider = Provider<Translations>((ref) {
  final store = ref.watch(i18nStoreProvider).value;
  final language = ref.watch(settingsProvider.select((s) => s.language));
  if (store == null) return Translations(language, const {}, const {});
  return Translations.from(store, language);
});

/// Короткий доступ в виджетах: `ref.tr('group.key')` — реактивно к смене языка.
extension I18nRef on WidgetRef {
  String tr(String key, [Map<String, Object?> args = const {}]) =>
      watch(translationsProvider).t(key, args);
}
