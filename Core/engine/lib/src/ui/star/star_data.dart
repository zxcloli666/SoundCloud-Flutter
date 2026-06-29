import 'package:flutter/material.dart';

import '../../rust/dto_pay.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Шаги покупки STAR PASS (легаси `meta.ts` `Step`).
enum StarStep { overview, method, pay, success, redeem, manage }

/// Фаза заказа (легаси `PayStatus` `PayPhase`).
enum PayPhase { waiting, granted, failed }

/// Тариф подписки (легаси `Plan`). Данные приходят из `pay`-моста
/// ([PlanDto] через `payPlansProvider`); этот тип — презентационная проекция,
/// чтобы панели/readout жили на одном словаре.
class StarPlan {
  final String id;
  final int months;
  final int priceRub;
  final int savingsPct;

  const StarPlan({
    required this.id,
    required this.months,
    required this.priceRub,
    required this.savingsPct,
  });

  /// Проекция планового DTO моста в презентационный тариф.
  factory StarPlan.fromDto(PlanDto dto) => StarPlan(
        id: dto.id,
        months: dto.months.toInt(),
        priceRub: dto.priceRub.toInt(),
        savingsPct: dto.savingsPct.toInt(),
      );

  /// Тариф с лучшей выгодой — авто-выбор при входе (легаси `bestId`).
  static StarPlan? best(List<StarPlan> plans) {
    StarPlan? b;
    for (final p in plans) {
      if (b == null || p.savingsPct > b.savingsPct) b = p;
    }
    return b;
  }

  /// Ярлык длительности (легаси `monthsKey`): year / quarter / month.
  String get termLabel =>
      months >= 12 ? 'Год' : months >= 3 ? '3 месяца' : 'Месяц';

  int get perMonthRub => months == 0 ? priceRub : (priceRub / months).round();
}

/// Способ активации (легаси `providers.ts` `ActivationKind`). Плоский матч на
/// шесть конкретных опций концепта; `recurring` — только tgStars.
enum ActivationKind { sbp, cardRu, cardIntl, cryptoPlatega, cryptoBot, tgStars }

class ActivationOption {
  final ActivationKind kind;
  final String title;
  final String tag;
  final bool recurring;

  /// Провайдер чекаута (`pay_checkout` provider) — platega|cryptobot|tgstars.
  final String provider;

  /// Суб-метод platega (`pay_checkout` method): sbp|card_ru|card_intl|crypto.
  /// null для cryptobot/tgstars (у них один путь).
  final String? method;

  const ActivationOption({
    required this.kind,
    required this.title,
    required this.tag,
    required this.recurring,
    required this.provider,
    this.method,
  });

  /// Порядок/теги + матч provider×method из легаси `providers.ts` (`ORDER`,
  /// `TAGS`, `toCheckout`). Плоский матч шести опций концепта на бэкенд.
  static const List<ActivationOption> all = [
    ActivationOption(
        kind: ActivationKind.sbp,
        title: 'СБП',
        tag: 'NSPK',
        recurring: false,
        provider: 'platega',
        method: 'sbp'),
    ActivationOption(
        kind: ActivationKind.cardRu,
        title: 'Карта РФ',
        tag: '3-D SECURE',
        recurring: false,
        provider: 'platega',
        method: 'card_ru'),
    ActivationOption(
        kind: ActivationKind.cardIntl,
        title: 'Зарубежная карта',
        tag: 'USD / EUR',
        recurring: false,
        provider: 'platega',
        method: 'card_intl'),
    ActivationOption(
        kind: ActivationKind.cryptoPlatega,
        title: 'Криптовалюта',
        tag: 'ON-CHAIN',
        recurring: false,
        provider: 'platega',
        method: 'crypto'),
    ActivationOption(
        kind: ActivationKind.cryptoBot,
        title: 'CryptoBot',
        tag: '@CryptoBot',
        recurring: false,
        provider: 'cryptobot'),
    ActivationOption(
        kind: ActivationKind.tgStars,
        title: 'Telegram Stars',
        tag: '★',
        recurring: true,
        provider: 'tgstars'),
  ];

  bool get isSbp => kind == ActivationKind.sbp;
}

/// Энтайтлмент с самым поздним концом — определяет активное окно подписки и
/// источник для отмены (легаси `meta.ts` `primaryEntitlement`).
EntitlementDto? primaryEntitlement(List<EntitlementDto> ents) {
  EntitlementDto? best;
  for (final e in ents) {
    if (best == null || e.endsAt > best.endsAt) best = e;
  }
  return best;
}

/// Перки членства (легаси `PERKS`) — иконка + заголовок.
class StarPerk {
  final IconData icon;
  final String title;
  const StarPerk(this.icon, this.title);

  static const List<StarPerk> all = [
    StarPerk(LucideIcons.music, 'SoundCloud Go+'),
    StarPerk(Icons.dns_rounded, 'Наш сервер'),
    StarPerk(LucideIcons.audioLines, 'HQ-качество'),
    StarPerk(LucideIcons.globe, 'Белый список'),
    StarPerk(LucideIcons.sparkles, 'Волна без границ'),
    StarPerk(Icons.favorite_rounded, 'Поддержка проекта'),
  ];
}

/// Стабильный короткий серийник «SC-XXXX-XXXX» из seed (легаси `passSerial`,
/// FNV-1a 32-bit + два 5-битных блока).
String passSerial(String seed) {
  var h = 2166136261;
  for (final code in seed.codeUnits) {
    h ^= code;
    h = (h * 16777619) & 0xFFFFFFFF;
  }
  const alpha = 'ABCDEFGHJKLMNPQRSTUVWXYZ0123456789';
  String block(int n) {
    final sb = StringBuffer();
    for (var i = 0; i < 4; i++) {
      sb.write(alpha[((n >> (i * 5)) & 0xFFFFFFFF) % alpha.length]);
    }
    return sb.toString();
  }

  final h2 = ((h ^ 0x9e3779b9) * 2654435761) & 0xFFFFFFFF;
  return 'SC-${block(h)}-${block(h2)}';
}

/// Unix-секунды → «21.07.2027» (легаси `passDate`, всегда dd.mm.yyyy).
String passDate(int? epochSec) {
  if (epochSec == null || epochSec == 0) return '—';
  final d = DateTime.fromMillisecondsSinceEpoch(epochSec * 1000);
  String p(int n) => n.toString().padLeft(2, '0');
  return '${p(d.day)}.${p(d.month)}.${d.year}';
}

/// Целые дни до дедлайна, не меньше нуля (легаси `daysUntil`).
int daysUntil(int? epochSec) {
  if (epochSec == null || epochSec == 0) return 0;
  final ms = epochSec * 1000 - DateTime.now().millisecondsSinceEpoch;
  if (ms <= 0) return 0;
  return (ms / 86400000).ceil();
}

/// Множественное «день/дня/дней» для русского.
String daysLeftLabel(int n) {
  final mod10 = n % 10;
  final mod100 = n % 100;
  final word = (mod10 == 1 && mod100 != 11)
      ? 'день'
      : (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14))
          ? 'дня'
          : 'дней';
  return '$n $word';
}

/// Код активации «STAR-XXXX-XXXX-XXXX-XXXX» (легаси `redeem-code.ts`).
final RegExp starCodeRe = RegExp(r'^STAR(-[0-9A-Z]{4}){4}$');

/// Чистим до букв/цифр, срезаем ведущий STAR, кап 16 символов тела.
String normalizeCodeBody(String raw) {
  var s = raw.toUpperCase().replaceAll(RegExp('[^0-9A-Z]'), '');
  if (s.startsWith('STAR')) s = s.substring(4);
  return s.length > 16 ? s.substring(0, 16) : s;
}

/// Тело (≤16) → «STAR-XXXX-XXXX-XXXX-XXXX» с прогрессивными дефисами.
String formatCode(String body) {
  final groups = <String>[];
  for (var i = 0; i < body.length; i += 4) {
    groups.add(body.substring(i, i + 4 > body.length ? body.length : i + 4));
  }
  return ['STAR', ...groups].join('-');
}
