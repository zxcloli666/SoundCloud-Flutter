import 'package:flutter/widgets.dart';

import '../../rust/dto_social.dart';

/// Тема альбома (легаси `Aura`). Управляет цветом всего экрана: ринг обложки,
/// градиент play-кнопки, подсветка активной строки, бейджи.
///
/// Источник истины — premium-аура звёздного артиста (`artistStarProvider`):
/// именованная палитра по `auraId`, либо производная от `customHex`. Если артист
/// не премиум — падаем на акцент зрителя (легаси «viewer aura» путь).
class AlbumAura {
  /// База ауры (акцент). Все производные — из неё.
  final Color seed;

  /// Три орба для звёздного ринга (конический градиент).
  final List<Color> orbs;

  /// Аура пришла от премиум-артиста (а не от акцента зрителя) — включает
  /// звёздное оформление обложки/шапки.
  final bool isStar;

  const AlbumAura({required this.seed, required this.orbs, this.isStar = false});

  /// Аура зрителя: монохромный ринг из акцента (звёздного оформления нет).
  factory AlbumAura.fromAccent(Color accent) {
    return AlbumAura(
      seed: accent,
      orbs: [accent, _shiftHue(accent, 0.10), _shiftHue(accent, -0.10)],
    );
  }

  /// Аура из STAR-профиля артиста (легаси `resolveAura`). Премиум → именованная
  /// палитра / `customHex`; иначе — аура зрителя ([viewerAccent]).
  factory AlbumAura.fromStar(ArtistStarDto? star, Color viewerAccent) {
    if (star == null || !star.premium) return AlbumAura.fromAccent(viewerAccent);

    final id = star.auraId;
    if (id == 'custom') {
      final custom = _fromHex(star.customHex);
      if (custom != null) return custom;
    }
    final preset = id == null ? null : _auras[id];
    if (preset != null) {
      return AlbumAura(seed: preset.seed, orbs: preset.orbs, isStar: true);
    }
    // Премиум без валидной ауры — дефолтная (легаси `DEFAULT_AURA` = aurora).
    final fallback = _auras['aurora']!;
    return AlbumAura(seed: fallback.seed, orbs: fallback.orbs, isStar: true);
  }

  Color rgba(double opacity) => seed.withValues(alpha: opacity);
  Color get rgb => seed;

  /// Светлая аура → контрастный текст чёрный (легаси `isLight`,
  /// `lum = 0.299r+0.587g+0.114b > 0.62`).
  bool get isLight {
    final l = 0.299 * seed.r + 0.587 * seed.g + 0.114 * seed.b;
    return l > 0.62;
  }

  Color get contrast => isLight ? const Color(0xFF000000) : const Color(0xFFFFFFFF);

  /// Градиент заголовка для звёздного альбома (легаси `aura.nameGradient`).
  LinearGradient get nameGradient => LinearGradient(
        colors: [
          _shiftHue(seed, 0.06),
          seed,
          _shiftHue(seed, -0.06),
        ],
      );
}

/// Именованные премиум-ауры (легаси `AURAS`): seed = accent-rgb, orbs — тройка.
const _auras = <String, ({Color seed, List<Color> orbs})>{
  'aurora': (
    seed: Color(0xFFA855F7),
    orbs: [Color(0xFF7C3AED), Color(0xFF06B6D4), Color(0xFFEC4899)],
  ),
  'magma': (
    seed: Color(0xFFFF5500),
    orbs: [Color(0xFFFF5500), Color(0xFFFF0080), Color(0xFFFF8A00)],
  ),
  'cyber': (
    seed: Color(0xFF06B6D4),
    orbs: [Color(0xFF06B6D4), Color(0xFF3B82F6), Color(0xFF10B981)],
  ),
  'void': (
    seed: Color(0xFFD4D4DC),
    orbs: [Color(0xFF3F3F46), Color(0xFF52525B), Color(0xFF71717A)],
  ),
  'sunset': (
    seed: Color(0xFFFB7185),
    orbs: [Color(0xFFF97316), Color(0xFFFB7185), Color(0xFFA855F7)],
  ),
  'forest': (
    seed: Color(0xFF10B981),
    orbs: [Color(0xFF10B981), Color(0xFF84CC16), Color(0xFF065F46)],
  ),
  'ocean': (
    seed: Color(0xFF0EA5E9),
    orbs: [Color(0xFF0EA5E9), Color(0xFF06B6D4), Color(0xFF1E3A8A)],
  ),
};

/// Аура из `#rrggbb` (легаси `auraFromHex`): seed + lighten(.25)/darken(.35) орбы.
AlbumAura? _fromHex(String? hex) {
  final rgb = _hexToColor(hex);
  if (rgb == null) return null;
  return AlbumAura(
    seed: rgb,
    orbs: [rgb, _lighten(rgb, 0.25), _darken(rgb, 0.35)],
    isStar: true,
  );
}

Color? _hexToColor(String? hex) {
  if (hex == null) return null;
  final cleaned = hex.replaceFirst('#', '');
  if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(cleaned)) return null;
  return Color(0xFF000000 | int.parse(cleaned, radix: 16));
}

Color _lighten(Color c, double amt) => Color.from(
      alpha: 1,
      red: c.r + (1 - c.r) * amt,
      green: c.g + (1 - c.g) * amt,
      blue: c.b + (1 - c.b) * amt,
    );

Color _darken(Color c, double amt) => Color.from(
      alpha: 1,
      red: c.r * (1 - amt),
      green: c.g * (1 - amt),
      blue: c.b * (1 - amt),
    );

/// Лёгкий поворот тона вокруг seed-цвета без потери насыщенности.
Color _shiftHue(Color c, double delta) {
  final hsl = HSLColor.fromColor(c);
  final hue = (hsl.hue + delta * 360) % 360;
  return hsl.withHue(hue < 0 ? hue + 360 : hue).toColor();
}
