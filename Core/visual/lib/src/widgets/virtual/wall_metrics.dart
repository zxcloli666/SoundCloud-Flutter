import '../collections/collection_art.dart' show fnv1a;

/// Раскладка мозаики обложек («Стена» поиска/Discover) — load-bearing (§3.2/§4).
///
/// Это ДРУГАЯ формула, чем у [GridMetrics] (каталог по minColumnWidth): здесь
/// сначала по ширине viewport выбирается целевая сторона тайла, затем число
/// колонок зажимается в [minColumns]..[maxColumns]. Гэп фиксированный — 12px.
///
/// ```
/// target  = width≥2200 ? 252 : ≥1600 ? 224 : ≥1100 ? 198 : 172
/// columns = clamp(2, 10, floor((width + 12) / (target + 12)))
/// cellPx  = (width - 12*(columns-1)) / columns
/// ```
/// Геро-тайл занимает `span 2 / span 2` (4 ячейки).
class WallMetrics {
  static const double gap = 12;
  static const int minColumns = 2;
  static const int maxColumns = 10;

  /// Потолок DOM-окна: при >150 видимых рендерим последние 150 + спейсер.
  static const int retainCap = 150;

  final int columns;
  final double cellPx;

  const WallMetrics({required this.columns, required this.cellPx});

  factory WallMetrics.resolve(double width) {
    final target = _targetEdge(width);
    final columns =
        ((width + gap) / (target + gap)).floor().clamp(minColumns, maxColumns);
    final cellPx = (width - gap * (columns - 1)) / columns;
    return WallMetrics(columns: columns, cellPx: cellPx);
  }

  static double _targetEdge(double width) {
    if (width >= 2200) return 252;
    if (width >= 1600) return 224;
    if (width >= 1100) return 198;
    return 172;
  }

  /// Высота спейсера (в строках), скрывающего обрезанные DOM-окном тайлы.
  /// `droppedCells` = Σ (hero ? 4 : 1) по выпавшим элементам.
  int spacerRows(int droppedCells) =>
      droppedCells <= 0 ? 0 : (droppedCells / columns).ceil();
}

/// `hashStr` легаси = FNV-1a 32-bit unsigned (тот же [fnv1a]).
int hashStr(String s) => fnv1a(s);

/// Геро по urn (woven text mode): `hashStr(urn) % 9 === 4` (~1/9, стабильно
/// между пере-сборками ленты).
bool isHeroUrn(String urn) => hashStr(urn) % 9 == 4;

/// Геро по позиции (append-only: landing/vibe/dive): `i%10==2 || i%10==7`
/// (~2 на 10).
bool isHeroPos(int index) => index % 10 == 2 || index % 10 == 7;

/// Геро в скелетоне: `index>0 && (index+4)%9===0`.
bool isHeroIndex(int index) => index > 0 && (index + 4) % 9 == 0;
