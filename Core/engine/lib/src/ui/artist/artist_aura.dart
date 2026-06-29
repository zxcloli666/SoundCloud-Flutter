import 'package:flutter/widgets.dart';

/// Аура артиста (§5.6). У star-артиста тема берётся из его `custom_hex`
/// (`artistStarProvider.customHex` → [ArtistAura.fromHex]); иначе — от акцента
/// вьюера ([ArtistAura.fromAccent]). Орбы = [base, lighten 0.25, darken 0.35],
/// `nameGradient` — бело-тинт-бело свип для clip-заголовка имени.
///
/// Пресет-аур по `aura_id` (без своего hex) в visual-каталоге пока нет — для
/// них честный фолбэк на акцент вьюера (см. notes страницы).
class ArtistAura {
  /// Базовый цвет (праймери) — основной тинт строк/баров/баджей.
  final Color primary;

  /// Три орба для AuraField/AvatarArtifact (orbs[0..2]).
  final List<Color> orbs;

  const ArtistAura({required this.primary, required this.orbs});

  /// Из базового цвета: orbs = [base, lighten(.25), darken(.35)].
  factory ArtistAura.fromColor(Color base) {
    return ArtistAura(
      primary: base,
      orbs: [base, _lighten(base, 0.25), _darken(base, 0.35)],
    );
  }

  /// Из акцента вьюера (НЕ-star).
  factory ArtistAura.fromAccent(Color accent) => ArtistAura.fromColor(accent);

  /// Из star-`custom_hex` (`#RRGGBB`/`RRGGBB`/`#RGB`). Невалидный hex → null,
  /// чтобы вызвать сторона честно упала на акцент вьюера.
  static ArtistAura? fromHex(String? hex) {
    final c = _parseHex(hex);
    return c == null ? null : ArtistAura.fromColor(c);
  }

  Color rgba(double alpha) => primary.withValues(alpha: alpha);

  /// Бело→тинт→тинт→бело свип для gradient-clipped имени (легаси `nameGradient`).
  LinearGradient get nameGradient {
    final c2 = _lighten(primary, 0.5);
    final c3 = _lighten(primary, 0.25);
    return LinearGradient(
      begin: const Alignment(-1, -0.36),
      end: const Alignment(1, 0.36),
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

Color? _parseHex(String? hex) {
  if (hex == null) return null;
  var h = hex.trim();
  if (h.startsWith('#')) h = h.substring(1);
  if (h.length == 3) h = h.split('').map((d) => '$d$d').join();
  if (h.length != 6) return null;
  final v = int.tryParse(h, radix: 16);
  return v == null ? null : Color(0xFF000000 | v);
}

Color _lighten(Color c, double t) => Color.from(
      alpha: c.a,
      red: c.r + (1 - c.r) * t,
      green: c.g + (1 - c.g) * t,
      blue: c.b + (1 - c.b) * t,
    );

Color _darken(Color c, double t) => Color.from(
      alpha: c.a,
      red: c.r * (1 - t),
      green: c.g * (1 - t),
      blue: c.b * (1 - t),
    );
