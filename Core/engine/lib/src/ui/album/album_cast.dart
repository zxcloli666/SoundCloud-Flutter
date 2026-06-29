import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../providers.dart';
import '../../rust/dto.dart';
import 'album_aura.dart';
import 'album_panel.dart';

const _roleOrder = ['primary', 'featured', 'remixer', 'producer'];
const _roleLabels = {
  'primary': 'Артист',
  'featured': 'При участии',
  'remixer': 'Ремикс',
  'producer': 'Продюсер',
};

String _roleLabel(String? role) => _roleLabels[role] ?? (role ?? 'Участник').toUpperCase();

/// Состав альбома (легаси `AlbumCast`). Артисты сгруппированы по ролям; каждая
/// группа — заголовок + адаптивная сетка карточек (48px аватар → артист).
/// Пусто — панель не рендерится.
class AlbumCast extends StatelessWidget {
  final List<AlbumArtistDto> artists;
  final AlbumAura aura;

  const AlbumCast({super.key, required this.artists, required this.aura});

  @override
  Widget build(BuildContext context) {
    if (artists.isEmpty) return const SizedBox.shrink();

    final groups = <String, List<AlbumArtistDto>>{};
    for (final a in artists) {
      (groups[a.role ?? 'other'] ??= []).add(a);
    }
    final ordered = <MapEntry<String, List<AlbumArtistDto>>>[];
    for (final k in _roleOrder) {
      final items = groups.remove(k);
      if (items != null && items.isNotEmpty) ordered.add(MapEntry(k, items));
    }
    for (final e in groups.entries) {
      if (e.value.isNotEmpty) ordered.add(e);
    }

    return AlbumPanel(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CastHeader(count: artists.length, aura: aura),
          const SizedBox(height: 20),
          for (var i = 0; i < ordered.length; i++) ...[
            if (i > 0) const SizedBox(height: 24),
            _CastRow(role: ordered[i].key, items: ordered[i].value, aura: aura),
          ],
        ],
      ),
    );
  }
}

class _CastHeader extends StatelessWidget {
  final int count;
  final AlbumAura aura;

  const _CastHeader({required this.count, required this.aura});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ScTokens.rButton),
            color: aura.rgba(0.12),
            border: Border.all(color: aura.rgba(0.25)),
          ),
          child: const Icon(Icons.group, size: 14, color: ScTokens.textSecondary),
        ),
        const SizedBox(width: 12),
        const Text(
          'СОСТАВ',
          style: TextStyle(
            color: ScTokens.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.4,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$count',
          style: const TextStyle(color: ScTokens.textTertiary, fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _CastRow extends StatelessWidget {
  final String role;
  final List<AlbumArtistDto> items;
  final AlbumAura aura;

  const _CastRow({required this.role, required this.items, required this.aura});

  @override
  Widget build(BuildContext context) {
    final label = _roleLabel(role);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${label.toUpperCase()} · ${items.length}',
          style: const TextStyle(
            color: ScTokens.textTertiary,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.8,
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, c) {
            final columns = _columnsFor(c.maxWidth);
            const gap = 12.0;
            final itemWidth = (c.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final a in items)
                  SizedBox(
                    width: itemWidth,
                    child: _CastCard(artist: a, roleLabel: label, aura: aura),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Сетка состава: 2/3/4/5/6 колонок (легаси grid-cols-2…xl:6).
int _columnsFor(double width) {
  if (width >= 1100) return 6;
  if (width >= 900) return 5;
  if (width >= 680) return 4;
  if (width >= 440) return 3;
  return 2;
}

class _CastCard extends ConsumerStatefulWidget {
  final AlbumArtistDto artist;
  final String roleLabel;
  final AlbumAura aura;

  const _CastCard({required this.artist, required this.roleLabel, required this.aura});

  @override
  ConsumerState<_CastCard> createState() => _CastCardState();
}

class _CastCardState extends ConsumerState<_CastCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.artist;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => ref.read(routerProvider.notifier).push(ArtistRoute(a.id)),
        child: AnimatedScale(
          scale: _hover ? 1.04 : 1.0,
          duration: ScTokens.dGlass,
          curve: ScTokens.easeApple,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ScTokens.rCard),
              color: const Color(0x08FFFFFF),
              border: Border.all(color: const Color(0x0FFFFFFF)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _hover ? const Color(0x4DFFFFFF) : const Color(0x1AFFFFFF), width: 2),
                    boxShadow: [BoxShadow(color: widget.aura.rgba(0.18), blurRadius: 18, offset: const Offset(0, 8))],
                  ),
                  child: ClipOval(child: Avatar(src: a.avatarUrl, alt: a.name, size: 48)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.roleLabel.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ScTokens.textTertiary,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
