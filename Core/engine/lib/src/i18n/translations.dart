import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// Все локали разом в памяти (три JSON ~130 КБ) — переключение языка мгновенное
/// и синхронное, без async в `build`. Ключи — дерево как в легаси i18next.
class I18nStore {
  final Map<String, Map<String, dynamic>> _byLanguage;

  const I18nStore(this._byLanguage);

  static const supported = ['ru', 'en', 'tr'];
  static const fallback = 'en';

  static Future<I18nStore> load() async {
    final byLanguage = <String, Map<String, dynamic>>{};
    for (final language in supported) {
      final raw = await rootBundle
          .loadString('packages/sc_engine/assets/i18n/$language.json');
      byLanguage[language] = jsonDecode(raw) as Map<String, dynamic>;
    }
    return I18nStore(byLanguage);
  }

  Map<String, dynamic>? forLanguage(String language) => _byLanguage[language];
}

/// Перевод по активному языку с фолбэком на en. i18next-совместимо: dot-ключи,
/// `{{var}}`-интерполяция, плюрализация по `count` (ru: one/few/many, en: one/
/// other, tr: other). Нет ключа — возвращаем сам ключ (видно недопереведённое).
class Translations {
  final String language;
  final Map<String, dynamic> _active;
  final Map<String, dynamic> _fallback;

  const Translations(this.language, this._active, this._fallback);

  factory Translations.from(I18nStore store, String language) {
    final lang =
        I18nStore.supported.contains(language) ? language : I18nStore.fallback;
    return Translations(
      lang,
      store.forLanguage(lang) ?? const {},
      store.forLanguage(I18nStore.fallback) ?? const {},
    );
  }

  String t(String key, [Map<String, Object?> args = const {}]) {
    final pluralKey = _withPlural(key, args);
    final raw = _resolve(_active, pluralKey) ??
        _resolve(_fallback, pluralKey) ??
        _resolve(_active, key) ??
        _resolve(_fallback, key);
    if (raw == null) return key;
    return _interpolate(raw, args);
  }

  String? _resolve(Map<String, dynamic> root, String key) {
    dynamic node = root;
    for (final part in key.split('.')) {
      if (node is Map<String, dynamic> && node.containsKey(part)) {
        node = node[part];
      } else {
        return null;
      }
    }
    return node is String ? node : null;
  }

  /// Ключ с суффиксом множественного числа, если в args есть `count`.
  String _withPlural(String key, Map<String, Object?> args) {
    final count = args['count'];
    if (count is! num) return key;
    return '${key}_${_pluralCategory(count.toInt())}';
  }

  String _pluralCategory(int n) {
    switch (language) {
      case 'ru':
        final mod10 = n % 10;
        final mod100 = n % 100;
        if (mod10 == 1 && mod100 != 11) return 'one';
        if (mod10 >= 2 && mod10 <= 4 && !(mod100 >= 12 && mod100 <= 14)) {
          return 'few';
        }
        return 'many';
      case 'tr':
        return 'other';
      default:
        return n == 1 ? 'one' : 'other';
    }
  }

  String _interpolate(String template, Map<String, Object?> args) {
    if (args.isEmpty || !template.contains('{{')) return template;
    return template.replaceAllMapped(RegExp(r'\{\{(\w+)\}\}'), (match) {
      final name = match.group(1)!;
      return args[name]?.toString() ?? match.group(0)!;
    });
  }
}
