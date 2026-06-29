import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../rust/dto.dart';
import 'artist_aura.dart';
import 'tab_states.dart';

/// Вкладка похожих артистов (§3.9 `ArtistRelatedTab`): адаптивная сетка карточек
/// 2/3/4/5/6 колонок, круглый аватар 80px, бар аффинности
/// `max(0.08, weight/max) · 100%`, тап → `ArtistRoute`.
class ArtistRelatedTab extends StatelessWidget {
  final List<RelatedArtistDto> related;
  final ArtistAura aura;
  final ValueChanged<String> onOpenArtist;

  const ArtistRelatedTab({
    super.key,
    required this.related,
    required this.aura,
    required this.onOpenArtist,
  });

  @override
  Widget build(BuildContext context) {
    if (related.isEmpty) {
      return const TabEmpty(icon: LucideIcons.users, label: 'Похожих артистов нет');
    }
    final maxWeight = related.fold<double>(1, (m, r) => r.weight > m ? r.weight : m);
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 1280
        ? 6
        : width >= 1024
            ? 5
            : width >= 768
                ? 4
                : width >= 640
                    ? 3
                    : 2;
    return GridView.builder(
      shrinkWrap: true,
      primary: false,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: related.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 20,
        crossAxisSpacing: 20,
        childAspectRatio: 0.74,
      ),
      itemBuilder: (context, i) => _RelatedCard(
        item: related[i],
        aura: aura,
        maxWeight: maxWeight,
        onTap: () => onOpenArtist(related[i].id),
      ),
    );
  }
}

class _RelatedCard extends StatefulWidget {
  final RelatedArtistDto item;
  final ArtistAura aura;
  final double maxWeight;
  final VoidCallback onTap;

  const _RelatedCard({
    required this.item,
    required this.aura,
    required this.maxWeight,
    required this.onTap,
  });

  @override
  State<_RelatedCard> createState() => _RelatedCardState();
}

class _RelatedCardState extends State<_RelatedCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final pct = (widget.item.weight / widget.maxWeight).clamp(0.08, 1.0);
    final perf = ScPerf.of(context);
    final blur = perf == PerfMode.light ? 0.0 : (perf == PerfMode.medium ? 5.0 : 10.0);

    Widget card = Stack(
      children: [
        if (perf == PerfMode.beauty)
          Positioned(
            left: -48,
            right: -48,
            top: -80,
            height: 176,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _hover ? 0.9 : 0.5,
                duration: const Duration(milliseconds: 700),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [widget.aura.rgba(0.4), const Color(0x00000000)],
                      stops: const [0.0, 0.7],
                    ),
                  ),
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _hover ? const Color(0x4DFFFFFF) : const Color(0x1AFFFFFF), width: 2),
                  boxShadow: [BoxShadow(color: widget.aura.rgba(0.25), blurRadius: 30, offset: const Offset(0, 12))],
                ),
                child: ClipOval(child: Avatar(src: widget.item.avatarUrl, alt: widget.item.name, size: 80)),
              ),
              const SizedBox(height: 12),
              Text(
                widget.item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 13, fontWeight: FontWeight.w600),
              ),
              if (widget.item.country != null && widget.item.country!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.globe, size: 9, color: Color(0x59FFFFFF)),
                    const SizedBox(width: 4),
                    Text(widget.item.country!, style: const TextStyle(color: Color(0x59FFFFFF), fontSize: 10)),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              _affinityBar(pct.toDouble()),
              const SizedBox(height: 8),
              Text(
                'СОВПАДЕНИЕ ${(pct * 100).round()}%',
                style: const TextStyle(
                  color: Color(0x4DFFFFFF),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    Widget body = DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x08FFFFFF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x0FFFFFFF), width: 0.5),
      ),
      child: card,
    );
    if (blur > 0) {
      body = ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur), child: body),
      );
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hover ? 1.03 : 1.0,
          duration: const Duration(milliseconds: 500),
          curve: ScTokens.easeApple,
          child: body,
        ),
      ),
    );
  }

  Widget _affinityBar(double pct) {
    return LayoutBuilder(
      builder: (context, c) => ClipRRect(
        borderRadius: BorderRadius.circular(9999),
        child: Container(
          height: 4,
          color: const Color(0x0AFFFFFF),
          alignment: Alignment.centerLeft,
          child: Container(
            width: c.maxWidth * pct,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [widget.aura.primary, widget.aura.rgba(0.3)]),
              borderRadius: BorderRadius.circular(9999),
              boxShadow: [BoxShadow(color: widget.aura.rgba(0.5), blurRadius: 10)],
            ),
          ),
        ),
      ),
    );
  }
}
