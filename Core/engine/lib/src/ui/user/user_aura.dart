import 'package:flutter/widgets.dart';

/// Аура профиля (легаси `lib/aura.ts`): 3 цвета-орба + акцент + признак светлоты.
/// Star-профили выбирают пресет владельца; обычные — тема из акцента смотрящего
/// (§5.6 «viewer aura»).
class UserAura {
  /// orbs[0..2] — для кольца аватара, атмосферы, name-gradient.
  final List<Color> orbs;

  /// Базовый цвет ауры (легаси `auraRgb`): подсветка строк/пилюль/теней.
  final Color accent;

  const UserAura({required this.orbs, required this.accent});

  /// Аура из акцента смотрящего: orbs = [hex, lighten .25, darken .35].
  factory UserAura.viewer(Color accent) => UserAura.fromBase(accent);

  /// Аура из одного базового цвета: orbs = [base, lighten .25, darken .35].
  factory UserAura.fromBase(Color base) => UserAura(
        orbs: [base, _lighten(base, 0.25), _darken(base, 0.35)],
        accent: base,
      );

  /// Аура star-владельца (легаси `resolveAura`): id пресета или custom-hex. На
  /// неизвестном id / отсутствии — дефолтная Aurora; не-star зовёт [viewer].
  factory UserAura.preset(String? auraId, String? customHex) {
    if (auraId == 'custom' && customHex != null) {
      final c = _parseHex(customHex);
      if (c != null) return UserAura.fromBase(c);
    }
    final preset = _presets[auraId] ?? _presets['aurora']!;
    return UserAura(orbs: preset.$1, accent: preset.$2);
  }

  /// `isLight` (легаси): относительная яркость > 0.78 → играем чёрной иконкой.
  bool get isLight {
    final l = (0.299 * accent.r + 0.587 * accent.g + 0.114 * accent.b);
    return l > 0.78;
  }

  Color rgba(double alpha) => accent.withValues(alpha: alpha);

  /// Name-gradient (легаси пресет): белый → tint → белый sweep для clipped-имени.
  LinearGradient get nameGradient {
    final c2 = _lighten(accent, 0.5);
    final c3 = _lighten(accent, 0.25);
    return LinearGradient(
      begin: const Alignment(-1, -0.35),
      end: const Alignment(1, 0.35),
      colors: [
        const Color(0xFFFFFFFF),
        const Color(0xFFFFFFFF),
        c2,
        c3,
        const Color(0xFFFFFFFF),
        const Color(0xFFFFFFFF),
      ],
      stops: const [0.0, 0.28, 0.45, 0.58, 0.75, 1.0],
    );
  }
}

/// Star-пресеты ауры (легаси `AURAS`): (orbs[0..2], accent).
const _presets = <String, (List<Color>, Color)>{
  'aurora': ([Color(0xFF7C3AED), Color(0xFF06B6D4), Color(0xFFEC4899)], Color(0xFFA855F7)),
  'magma': ([Color(0xFFFF5500), Color(0xFFFF0080), Color(0xFFFF8A00)], Color(0xFFFF5500)),
  'cyber': ([Color(0xFF06B6D4), Color(0xFF3B82F6), Color(0xFF10B981)], Color(0xFF06B6D4)),
  'void': ([Color(0xFF3F3F46), Color(0xFF52525B), Color(0xFF71717A)], Color(0xFFD4D4DC)),
  'sunset': ([Color(0xFFF97316), Color(0xFFFB7185), Color(0xFFA855F7)], Color(0xFFFB7185)),
  'forest': ([Color(0xFF10B981), Color(0xFF84CC16), Color(0xFF065F46)], Color(0xFF10B981)),
  'ocean': ([Color(0xFF0EA5E9), Color(0xFF06B6D4), Color(0xFF1E3A8A)], Color(0xFF0EA5E9)),
};

/// `#rrggbb` → Color (легаси `hexToRgb`). null — невалидный.
Color? _parseHex(String hex) {
  final m = RegExp(r'^([0-9a-fA-F]{6})$').firstMatch(hex.replaceAll('#', ''));
  if (m == null) return null;
  return Color(0xFF000000 | int.parse(m.group(1)!, radix: 16));
}

Color _lighten(Color c, double amount) => Color.from(
      alpha: c.a,
      red: c.r + (1 - c.r) * amount,
      green: c.g + (1 - c.g) * amount,
      blue: c.b + (1 - c.b) * amount,
    );

Color _darken(Color c, double amount) => Color.from(
      alpha: c.a,
      red: c.r * (1 - amount),
      green: c.g * (1 - amount),
      blue: c.b * (1 - amount),
    );
