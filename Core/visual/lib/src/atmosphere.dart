import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'palette.dart';
import 'perf.dart';
import 'theme.dart';
import 'tokens.dart';
import 'widgets/atmosphere/star_field.dart';

/// Два легаси-источника атмосферы (§2.6) с разной геометрией/таймингом орбов:
///   • [page] — `search/Atmosphere` (Search/Home/Library/Settings/Login):
///     третий орб с белой подмешкой, дрейф 24/30/36s, opacity 0.42/0.24/0.26.
///   • [aura] — `user/AuraField` (User/Artist/Album/Discover): дрейф 22/28/34s,
///     `intense` (= isStar) усиливает орбы до 0.45/0.40/0.32.
enum AtmosphereVariant { page, aura }

/// Атмосферный фон страницы (§2.6): тёмная база + 3 дрейфующих орба-свечения
/// в режиме `screen` позади контента. Орбы большие (62–80% ширины), позиции
/// per-page, цвет — из `tint` (топ-жанры/aura). Скорость дрейфа масштабируется
/// энергией: `k = 1.6 - energy` (выше энергия → быстрее; только [page]-вариант).
///
/// Перф-гейт: light → плоский фон без орбов/анимаций; medium роняет третий орб
/// и переходит на translate-only дрейф (без пере-растеризации блюр-ядра).
/// Контракт совместим с прежним `Atmosphere(child:)`.
class Atmosphere extends StatefulWidget {
  final Widget child;

  /// До 3 цветов-подсветок (top-genre/aura). Меньше — добиваем акцентом/белым.
  final List<Color> tint;

  /// Энергия 0..1: гонит дрейф [page]-варианта. По умолчанию спокойная (0.4).
  final double energy;

  /// Усиливать орбы (звёздные/премиум-страницы — `isStar` в AuraField).
  final bool intense;

  /// Какой легаси-набор орбов воспроизводить.
  final AtmosphereVariant variant;

  /// Интенсивность звёздного поля (легаси `StarField intensity`). null — без
  /// звёзд. В Tauri: Главная 0.7, Настройки 0.6, Логин 0.85, hero 1.0; на
  /// Artist/User/Discover/Album — только для STAR-подписчика.
  final double? stars;

  /// Per-звёздное свечение (beauty). Дешёвые фоны (Главная/Настройки) шлют false.
  final bool starGlow;

  const Atmosphere({
    super.key,
    required this.child,
    this.tint = const [],
    this.energy = 0.4,
    this.intense = false,
    this.variant = AtmosphereVariant.page,
    this.stars,
    this.starGlow = true,
  });

  @override
  State<Atmosphere> createState() => _AtmosphereState();
}

class _AtmosphereState extends State<Atmosphere> {
  AtmosphereConfig get _cfg => AtmosphereConfig(
        tint: widget.tint,
        energy: widget.energy,
        intense: widget.intense,
        variant: widget.variant,
        stars: widget.stars,
        starGlow: widget.starGlow,
      );

  @override
  Widget build(BuildContext context) {
    final cfg = _cfg;
    // Есть хост-оболочка (AppShell) → отдаём ей конфиг, фон рисуется на ВСЁ окно
    // (за сайдбаром/титлбаром), как `fixed inset-0` в легаси; сами — только
    // контент. Нет хоста (встраивание/тесты) → рисуем фон локально.
    final scope = AtmosphereScope.maybeOf(context);
    if (scope != null) {
      if (scope.config.value != cfg) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && scope.config.value != cfg) scope.config.value = cfg;
        });
      }
      return widget.child;
    }

    return Stack(
      // expand: `child` (страница) обязан заполнить площадь, иначе
      // CustomScrollView-страницы (Discover) схлопываются в 0 высоты.
      fit: StackFit.expand,
      children: [
        Positioned.fill(child: IgnorePointer(child: AtmosphereBackdrop(config: cfg))),
        RepaintBoundary(child: widget.child),
      ],
    );
  }
}

/// Конфиг атмосферы страницы — то, что [Atmosphere] отдаёт хосту-оболочке для
/// отрисовки фона на ВСЁ окно (за сайдбаром/титлбаром).
class AtmosphereConfig {
  final List<Color> tint;
  final double energy;
  final bool intense;
  final AtmosphereVariant variant;
  final double? stars;
  final bool starGlow;

  const AtmosphereConfig({
    this.tint = const [],
    this.energy = 0.4,
    this.intense = false,
    this.variant = AtmosphereVariant.page,
    this.stars,
    this.starGlow = true,
  });

  @override
  bool operator ==(Object o) =>
      o is AtmosphereConfig &&
      o.energy == energy &&
      o.intense == intense &&
      o.variant == variant &&
      o.stars == stars &&
      o.starGlow == starGlow &&
      _listEq(o.tint, tint);

  @override
  int get hashCode =>
      Object.hash(energy, intense, variant, stars, starGlow, Object.hashAll(tint));

  static bool _listEq(List<Color> a, List<Color> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Хост атмосферы (оболочка): [Atmosphere] внутри отдаёт сюда [AtmosphereConfig],
/// фон рисуется на всё окно. `getInheritedWidget` (без зависимости) — чтобы
/// страница не ребилдилась от смены конфига.
class AtmosphereScope extends InheritedWidget {
  final ValueNotifier<AtmosphereConfig?> config;

  const AtmosphereScope({super.key, required this.config, required super.child});

  static AtmosphereScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AtmosphereScope>();

  @override
  bool updateShouldNotify(AtmosphereScope old) => old.config != config;
}

/// Фон атмосферы (тёмная база + орбы + звёзды, либо плоский tint в light) БЕЗ
/// контента — для отрисовки на всё окно оболочкой или локально [Atmosphere].
class AtmosphereBackdrop extends StatelessWidget {
  final AtmosphereConfig config;

  /// Прозрачная база вместо тёмной заливки: орбы/звёзды рисуются поверх того, что
  /// под бэкдропом (обои). Композиция «обоина + glow + звёзды» — см. AppShell.
  final bool transparentBase;

  const AtmosphereBackdrop({
    super.key,
    required this.config,
    this.transparentBase = false,
  });

  _OrbSet get _set =>
      config.variant == AtmosphereVariant.aura ? _OrbSet.aura : _OrbSet.page;

  @override
  Widget build(BuildContext context) {
    final perf = ScPerf.of(context);
    final palette = ScTheme.paletteOf(context);

    if (perf == PerfMode.light) {
      return transparentBase
          ? _flatTint(palette)
          : ColoredBox(color: ScTokens.bgRoot, child: _flatTint(palette));
    }

    final colors = _resolveColors(palette);
    // medium роняет третий орб (статичная атмосфера — без покадрового дрейфа).
    final orbs =
        (perf == PerfMode.medium && ScPerf.profileOf(context).particles(3) < 3)
            ? _set.orbs.sublist(0, _set.orbs.length - 1)
            : _set.orbs;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Фон + орбы — статичный CustomPaint под RepaintBoundary (см. перф-коммент
        // в `project_flutter_linux_cpu_vsync`): screen-бленд не кэшируется, поэтому
        // НЕ анимируем; «движение» даёт только мерцание звёзд (дёшево).
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _OrbPainter(
                orbs: orbs,
                colors: colors,
                basePeriodMs: _set.basePeriodMs,
                tinted: config.tint.isNotEmpty,
                intense: config.intense,
                breathe: false,
                t: 0,
                base: transparentBase ? const Color(0x00000000) : ScTokens.bgRoot,
              ),
            ),
          ),
        ),
        if (config.stars != null)
          Positioned.fill(
            child: ScStarField(
              intensity: config.stars!,
              glow: config.starGlow,
              orbs: colors,
            ),
          ),
      ],
    );
  }

  // Tint → ровно 3 цвета: добиваем белым/акцентом если задано меньше.
  List<Color> _resolveColors(ScPalette palette) {
    final out = [...config.tint];
    final defaults = [palette.accent, const Color(0xFFFFFFFF), palette.accent];
    while (out.length < 3) {
      out.add(defaults[out.length]);
    }
    return out.take(3).toList();
  }

  Widget _flatTint(ScPalette palette) {
    final colors = _resolveColors(palette);
    final tinted = config.tint.isNotEmpty;
    if (config.variant == AtmosphereVariant.aura) {
      // AuraField light = двойной плоский радиал (углы 30/20 и 80/80).
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.4, -0.6),
            radius: 1.2,
            colors: [colors[0].withValues(alpha: 0.13), const Color(0x00000000)],
            stops: const [0.0, 0.6],
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0.6, 0.6),
              radius: 1.2,
              colors: [colors[2].withValues(alpha: 0.10), const Color(0x00000000)],
              stops: const [0.0, 0.6],
            ),
          ),
        ),
      );
    }
    // search/Atmosphere light = одиночный плоский радиал (0.12 tinted / 0.08).
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.6, -0.8),
          radius: 1.4,
          colors: [colors[0].withValues(alpha: tinted ? 0.12 : 0.08), const Color(0x00000000)],
          stops: const [0.0, 0.62],
        ),
      ),
    );
  }
}

/// Рисует тёмную базу и орбы-свечения одним проходом по холсту. Каждый орб —
/// радиальный градиент в [BlendMode.screen] (аддитивно, как `mix-blend-screen`),
/// с мягким `MaskFilter.blur` для разлива (легаси `filter: blur(120-160px)`).
/// Позиции/периоды — из [_OrbSpec] (CSS left/top проценты от ширины/высоты).
class _OrbPainter extends CustomPainter {
  final List<_OrbSpec> orbs;
  final List<Color> colors;
  final double basePeriodMs;
  final bool tinted;
  final bool intense;
  final bool breathe;
  final double t; // фаза дрейфа 0..1
  final Color base;

  const _OrbPainter({
    required this.orbs,
    required this.colors,
    required this.basePeriodMs,
    required this.tinted,
    required this.intense,
    required this.breathe,
    required this.t,
    required this.base,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = base);
    const wobble = 0.03; // ±3% дрейфа в долях вьюпорта
    for (final spec in orbs) {
      final color = colors[spec.colorIndex];
      // ×1.45 к легаси-альфам: screen-бленд на тёмном гасит часть яркости, без
      // буста свечение читается «бледно». Клампим, чтобы не пережечь.
      final opacity = ((intense
                  ? spec.opacityIntense
                  : (tinted ? spec.opacityTint : spec.opacityNone)) *
              1.45)
          .clamp(0.0, 0.95);
      final side = size.width * spec.sizeVw;
      final ratio = spec.periodMs / basePeriodMs;
      final phase = t * 2 * math.pi / ratio + spec.phaseShift;
      final dx = wobble * math.sin(phase) * size.width;
      final dy = wobble * math.cos(phase + spec.phaseSeed) * size.height;
      final scale = breathe ? 1 + 0.08 * (0.5 - 0.5 * math.cos(phase)) : 1.0;
      final r = (side / 2) * scale;
      final center = Offset(
        spec.leftPct * size.width + side / 2 + dx,
        spec.topPct * size.height + side / 2 + dy,
      );
      final rect = Rect.fromCircle(center: center, radius: r);
      // Мягкость разлива зашита в МНОГОСТОПОВЫЙ градиент (плавный спад до 0),
      // БЕЗ per-frame MaskFilter.blur — тот рендерился по CPU и пожирал ядро.
      // Градиент-заливка круга — дёшево и на GPU; вид «широкого свечения» тот же.
      final shader = spec.whiteMix
          ? RadialGradient(
              colors: [
                const Color(0xFFFFFFFF).withValues(alpha: opacity * 0.5),
                color.withValues(alpha: opacity),
                color.withValues(alpha: opacity * 0.45),
                color.withValues(alpha: 0),
              ],
              stops: const [0.0, 0.22, 0.5, 1.0],
            ).createShader(rect)
          : RadialGradient(
              colors: [
                color.withValues(alpha: opacity),
                color.withValues(alpha: opacity * 0.5),
                color.withValues(alpha: 0),
              ],
              stops: const [0.0, 0.4, 1.0],
            ).createShader(rect);
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..shader = shader
          ..blendMode = BlendMode.screen,
      );
    }
  }

  @override
  bool shouldRepaint(_OrbPainter old) =>
      old.t != t ||
      old.intense != intense ||
      old.breathe != breathe ||
      old.tinted != tinted ||
      !_sameColors(old.colors, colors) ||
      old.orbs.length != orbs.length;

  bool _sameColors(List<Color> a, List<Color> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Спецификация орба (легаси-числа). [leftPct]/[topPct] — CSS top/left проценты
/// (от ширины/высоты вьюпорта), отрицательные = за кромкой (см. [_OrbSet]).
class _OrbSpec {
  final double leftPct;
  final double topPct;
  final double sizeVw;
  final double blurSigma;
  final double fade; // radial transparent-стоп
  final int colorIndex;
  final bool whiteMix;
  final double opacityTint;
  final double opacityNone;
  final double opacityIntense;
  final double periodMs;
  final double phaseShift;
  final double phaseSeed;

  const _OrbSpec({
    required this.leftPct,
    required this.topPct,
    required this.sizeVw,
    required this.blurSigma,
    required this.colorIndex,
    required this.opacityTint,
    required this.opacityNone,
    required this.opacityIntense,
    required this.periodMs,
    this.fade = 0.65,
    this.whiteMix = false,
    this.phaseShift = 0,
    this.phaseSeed = 0,
  });
}

/// Готовый набор орбов под легаси-вариант.
class _OrbSet {
  final List<_OrbSpec> orbs;
  final double basePeriodMs;

  const _OrbSet(this.orbs, this.basePeriodMs);

  /// `search/Atmosphere`: top-left 78vw, top-right 72vw, bottom 72vw (white-mix).
  /// `-right-24%`/`72vw` → left = 1 + 0.24 - 0.72 = 0.52.
  static const page = _OrbSet([
    _OrbSpec(
      leftPct: -0.12, topPct: -0.22, // -top-22% -left-12%
      sizeVw: 0.78, blurSigma: 60, fade: 0.62, colorIndex: 0,
      opacityTint: 0.42, opacityNone: 0.34, opacityIntense: 0.42,
      periodMs: 24000,
    ),
    _OrbSpec(
      leftPct: 0.52, topPct: -0.06, // -top-6% -right-24%
      sizeVw: 0.72, blurSigma: 75, fade: 0.66, colorIndex: 1,
      opacityTint: 0.24, opacityNone: 0.24, opacityIntense: 0.24,
      periodMs: 30000, phaseShift: -10000 / 24000 * 2 * math.pi, phaseSeed: 2,
    ),
    _OrbSpec(
      leftPct: 0.16, topPct: 0.50, // -bottom-22% left-16% (bottom→top ≈ 1-0.72+ -0.22)
      sizeVw: 0.72, blurSigma: 80, fade: 0.60, colorIndex: 1, whiteMix: true,
      opacityTint: 0.26, opacityNone: 0.16, opacityIntense: 0.26,
      periodMs: 36000, phaseShift: -18000 / 24000 * 2 * math.pi, phaseSeed: 3,
    ),
  ], 24000);

  /// `user/AuraField`: top-left 80vw, top-right 70vw, bottom 62vw. intense=isStar.
  /// `-right-20%`/`70vw` → left = 1 + 0.20 - 0.70 = 0.50.
  static const aura = _OrbSet([
    _OrbSpec(
      leftPct: -0.15, topPct: -0.20, // -top-20% -left-15%
      sizeVw: 0.80, blurSigma: 60, colorIndex: 0,
      opacityTint: 0.22, opacityNone: 0.22, opacityIntense: 0.45,
      periodMs: 22000,
    ),
    _OrbSpec(
      leftPct: 0.50, topPct: 0.05, // top-5% -right-20%
      sizeVw: 0.70, blurSigma: 70, colorIndex: 1,
      opacityTint: 0.18, opacityNone: 0.18, opacityIntense: 0.40,
      periodMs: 28000, phaseShift: -8000 / 22000 * 2 * math.pi, phaseSeed: 1.5,
    ),
    _OrbSpec(
      leftPct: 0.16, topPct: 0.56, // -bottom-18% left-16%
      sizeVw: 0.62, blurSigma: 80, colorIndex: 2,
      opacityTint: 0.14, opacityNone: 0.14, opacityIntense: 0.32,
      periodMs: 34000, phaseShift: -16000 / 22000 * 2 * math.pi, phaseSeed: 3,
    ),
  ], 22000);
}

/// Применяет [BlendMode] к слою через `saveLayer` (для `mix-blend-screen`).
/// ВНИМАНИЕ: composited-дети (ImageFiltered и т.п.) внутри ломают layer-стек
/// sliver-страниц — использовать только на box-страницах (напр. STAR-гало).
class BlendMask extends SingleChildRenderObjectWidget {
  final BlendMode blendMode;

  const BlendMask({super.key, required this.blendMode, required Widget child})
      : super(child: child);

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderBlend(blendMode);

  @override
  void updateRenderObject(BuildContext context, _RenderBlend renderObject) {
    renderObject.blendMode = blendMode;
  }
}

class _RenderBlend extends RenderProxyBox {
  _RenderBlend(this._blendMode);

  BlendMode _blendMode;
  set blendMode(BlendMode value) {
    if (_blendMode == value) return;
    _blendMode = value;
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => child != null;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;
    context.canvas.saveLayer(offset & size, Paint()..blendMode = _blendMode);
    context.paintChild(child!, offset);
    context.canvas.restore();
  }
}
