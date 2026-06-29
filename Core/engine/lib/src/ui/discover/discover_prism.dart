import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../providers.dart';
import '../../rust/api.dart';
import '../../rust/dto.dart';
import '../search/genre_palette.dart';
import '../search/track_wall.dart';
import 'discover_seed.dart';

/// Призма жанров (легаси §3.3 `DiscoverPrism`): `PrismBand` — полоса-эквалайзер
/// из жанров (ширина ∝ доле, активная во весь рост с glow, прочие — приглушены) —
/// ПЛЮС переиспользованная поисковая «Стена» (cap 24, hero по `isHeroUrn`, без
/// бесконечной догрузки и без «норы»), тонированная под активный/наведённый жанр.
///
/// Источник полос — `discoverTagsProvider`; мозаика берётся из волны
/// рекомендаций (`waveProvider`) — это единственная сидированная пере-тасовка на
/// странице (reshuffle поднимает nonce без рефетча).
class DiscoverPrism extends ConsumerStatefulWidget {
  final String? activeTag;
  final ValueChanged<String?> onTagSelected;
  final void Function(TrackDto track, List<TrackDto> queue) onPlay;

  const DiscoverPrism({
    super.key,
    required this.activeTag,
    required this.onTagSelected,
    required this.onPlay,
  });

  @override
  ConsumerState<DiscoverPrism> createState() => _DiscoverPrismState();
}

class _DiscoverPrismState extends ConsumerState<DiscoverPrism> {
  /// Капа мозаики: щедро, но конечно — занятой жанр не растит десятки рядов.
  static const _trackCap = 24;

  int _nonce = 0;
  String? _hoverTag;

  @override
  Widget build(BuildContext context) {
    final tags = ref.watch(discoverTagsProvider);
    return tags.maybeWhen(
      data: (list) => list.isEmpty ? const SizedBox.shrink() : _body(list),
      loading: () => const Skeleton(height: 64, rounded: SkeletonRound.lg),
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _body(List<TagDto> tags) {
    final accent = ScTheme.paletteOf(context).accent;
    // Тинт следует за наведённой полосой (до коммита), иначе за активной.
    final tintTag = _hoverTag ?? widget.activeTag ?? tags.first.id;
    final tint = genreColor(tintTag, accent);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(tint),
        const SizedBox(height: 16),
        _PrismBand(
          tags: tags,
          activeTag: widget.activeTag,
          onTagSelected: widget.onTagSelected,
          onHover: (id) => setState(() => _hoverTag = id),
        ),
        const SizedBox(height: 16),
        _wallPanel(tint),
      ],
    );
  }

  Widget _header(Color tint) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          AnimatedContainer(
            duration: ScTokens.dGlass,
            curve: ScTokens.easeApple,
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [tint.withValues(alpha: 0.3), tint.withValues(alpha: 0.04)],
              ),
              border: Border.all(color: tint.withValues(alpha: 0.4)),
            ),
            child: const Icon(LucideIcons.compass, size: 15, color: Color(0xD9FFFFFF)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  ref.tr('discover.prismTitle'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xF2FFFFFF),
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  ref.tr('discover.prismSubtitle'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Color(0x59FFFFFF)),
                ),
              ],
            ),
          ),
          _ReshuffleButton(
            tint: tint,
            label: ref.tr('discover.prismShuffle'),
            onPressed: () => setState(() => _nonce++),
          ),
        ],
      ),
    );
  }

  /// Тонированная стеклянная панель с мозаикой призмы.
  Widget _wallPanel(Color tint) {
    return AnimatedContainer(
      duration: ScTokens.dGlass,
      curve: ScTokens.easeApple,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: RadialGradient(
          center: const Alignment(0, -1),
          radius: 1.2,
          colors: [tint.withValues(alpha: 0.16), tint.withValues(alpha: 0.04)],
        ),
        border: Border.all(color: tint.withValues(alpha: 0.18)),
        boxShadow: [
          const BoxShadow(color: Color(0x47000000), blurRadius: 60, offset: Offset(0, 24)),
          BoxShadow(color: tint.withValues(alpha: 0.1), blurRadius: 60),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: _wall(),
    );
  }

  Widget _wall() {
    final async = ref.watch(waveProvider);
    return async.when(
      data: (state) {
        final items = _items(state.items);
        // Капы не хватает — добираем следующую порцию волны (без бесконечного
        // сентинела: один дотяг до капы).
        if (items.length < _trackCap && state.hasMore && !state.loadingMore) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => ref.read(waveProvider.notifier).next());
        }
        if (items.isEmpty) {
          return const Skeleton(height: 180, rounded: SkeletonRound.lg);
        }
        return TrackWall.embedded(
          items: items,
          loading: false,
          onPlay: widget.onPlay,
        );
      },
      loading: () => const TrackWall.embedded(
        items: [],
        loading: true,
        onPlay: _noop,
      ),
      error: (_, __) => const Skeleton(height: 180, rounded: SkeletonRound.lg),
    );
  }

  static void _noop(TrackDto _, List<TrackDto> __) {}

  /// Сидированная пере-тасовка волны → капа → hero по urn. Seed 0 (nonce==0)
  /// сохраняет порядок бэка; reshuffle поднимает nonce (без рефетча).
  List<WallItem> _items(List<WaveItemDto> wave) {
    final urns = [for (final w in wave) 'soundcloud:tracks:${w.id}'];
    final shuffled = seededOrder(urns, reshuffleSeed('prism', _nonce));
    return [
      for (final urn in shuffled.take(_trackCap))
        WallItem.lazy(urn, hero: isHeroUrn(urn)),
    ];
  }
}

class _PrismBand extends StatelessWidget {
  final List<TagDto> tags;
  final String? activeTag;
  final ValueChanged<String?> onTagSelected;
  final ValueChanged<String?> onHover;

  const _PrismBand({
    required this.tags,
    required this.activeTag,
    required this.onTagSelected,
    required this.onHover,
  });

  @override
  Widget build(BuildContext context) {
    final accent = ScTheme.paletteOf(context).accent;
    final wide = MediaQuery.sizeOf(context).width >= 640;
    final total = tags.fold<double>(0, (sum, t) => sum + t.count.toDouble());

    return SizedBox(
      height: wide ? 64 : 48,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final tag in tags)
            Expanded(
              flex: _flex(tag, total),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: _Stripe(
                  tag: tag,
                  color: genreColor(tag.id, accent),
                  active: tag.id == activeTag,
                  onTap: () =>
                      onTagSelected(tag.id == activeTag ? null : tag.id),
                  onHover: onHover,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// flexGrow = max(share, 0.04) из легаси; в целочисленный flex (×1000).
  int _flex(TagDto tag, double total) {
    final share = total <= 0 ? 0.04 : tag.count.toDouble() / total;
    return (share < 0.04 ? 0.04 : share * 1000).round().clamp(40, 1000);
  }
}

class _Stripe extends StatefulWidget {
  final TagDto tag;
  final Color color;
  final bool active;
  final VoidCallback onTap;
  final ValueChanged<String?> onHover;

  const _Stripe({
    required this.tag,
    required this.color,
    required this.active,
    required this.onTap,
    required this.onHover,
  });

  @override
  State<_Stripe> createState() => _StripeState();
}

class _StripeState extends State<_Stripe> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final lit = widget.active || _hover;
    return ScTooltip(
      message: '${widget.tag.label} · ${widget.tag.count}',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) {
          setState(() => _hover = true);
          widget.onHover(widget.tag.id);
        },
        onExit: (_) {
          setState(() => _hover = false);
          widget.onHover(null);
        },
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: lit ? 1.0 : 0.7,
            alignment: Alignment.bottomCenter,
            duration: ScTokens.dGlass,
            curve: ScTokens.easeLabel,
            child: AnimatedOpacity(
              opacity: lit ? 1.0 : 0.4,
              duration: ScTokens.dGlass,
              curve: ScTokens.easeLabel,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      widget.color.withValues(alpha: 0.9),
                      widget.color.withValues(alpha: 0.35),
                    ],
                  ),
                  boxShadow: widget.active
                      ? [BoxShadow(color: widget.color.withValues(alpha: 0.5), blurRadius: 18)]
                      : const [],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Кнопка «Пересобрать» мозаику призмы: иконка крутится на каждый тап (легаси
/// `ReshuffleButton`), тонирована под активный жанр.
class _ReshuffleButton extends StatefulWidget {
  final Color tint;
  final String label;
  final VoidCallback onPressed;

  const _ReshuffleButton({
    required this.tint,
    required this.label,
    required this.onPressed,
  });

  @override
  State<_ReshuffleButton> createState() => _ReshuffleButtonState();
}

class _ReshuffleButtonState extends State<_ReshuffleButton> {
  int _turns = 0;

  @override
  Widget build(BuildContext context) {
    return ScTooltip(
      message: widget.label,
      child: GestureDetector(
        onTap: () {
          setState(() => _turns++);
          widget.onPressed();
        },
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: widget.tint.withValues(alpha: 0.1),
            border: Border.all(color: widget.tint.withValues(alpha: 0.22)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedRotation(
                turns: _turns / 2,
                duration: ScTokens.dGlass,
                curve: ScTokens.easeApple,
                child: const Icon(LucideIcons.shuffle, size: 13, color: Color(0xB3FFFFFF)),
              ),
              if (MediaQuery.sizeOf(context).width >= 640) ...[
                const SizedBox(width: 6),
                Text(
                  widget.label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xB3FFFFFF),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
