import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../providers.dart';
import '../../rust/api.dart';
import 'track_aura.dart';

/// Оборот конверта пластинки: обзорная статистика, описание от артиста, кредиты-
/// как-типографика (альбом / выпущено / язык / ISRC), состав участников (продюсеры
/// / фиты) и теги. Альбом ведёт на [AlbumRoute].
class LinerNotes extends ConsumerStatefulWidget {
  final TrackDto track;
  final TrackAura aura;

  const LinerNotes({super.key, required this.track, required this.aura});

  @override
  ConsumerState<LinerNotes> createState() => _LinerNotesState();
}

class _LinerNotesState extends ConsumerState<LinerNotes> {
  static const _descClamp = 280;

  bool _descExpanded = false;

  @override
  Widget build(BuildContext context) {
    final track = widget.track;
    final aura = widget.aura;

    final desc = track.description?.trim();
    final credits = _credits();

    return GlassPanel(
      radius: ScTokens.rHero,
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _StatOrb(value: track.playCount?.toInt(), label: 'прослушиваний', glow: aura.glow),
              _StatOrb(value: track.likesCount?.toInt(), label: 'лайков', glow: aura.glow),
              if (track.repostsCount != null)
                _StatOrb(value: track.repostsCount!.toInt(), label: 'репостов', glow: aura.glow),
            ],
          ),
          if (desc != null && desc.isNotEmpty) ...[
            const SizedBox(height: 24),
            _Description(
              text: desc,
              expanded: _descExpanded,
              onToggle: () => setState(() => _descExpanded = !_descExpanded),
            ),
          ],
          if (credits.isNotEmpty) ...[
            const SizedBox(height: 24),
            Wrap(
              spacing: 32,
              runSpacing: 16,
              children: [for (final c in credits) _Credit(label: c.$1, value: c.$2, onTap: c.$3)],
            ),
          ],
          if (track.album != null) ...[
            const SizedBox(height: 24),
            _AlbumRow(album: track.album!, glow: aura.glow),
          ],
          if (track.participants.isNotEmpty) ...[
            const SizedBox(height: 24),
            _Participants(people: track.participants),
          ],
          if (track.tags.isNotEmpty) ...[
            const SizedBox(height: 24),
            _Tags(tags: track.tags),
          ],
        ],
      ),
    );
  }

  /// Кредиты-в-строку (label, value, tap?). Альбом и состав показываем отдельными
  /// блоками, тут — скалярная мета.
  List<(String, String, VoidCallback?)> _credits() {
    final track = widget.track;
    final out = <(String, String, VoidCallback?)>[];
    if (track.genre != null && track.genre!.isNotEmpty) {
      out.add(('Жанр', track.genre!, null));
    }
    if (track.releaseYear != null) out.add(('Выпущено', '${track.releaseYear}', null));
    out.add(('Длительность', formatDurationLong(track.durationMs.toInt()), null));
    if (track.language != null && track.language!.isNotEmpty) {
      out.add(('Язык', track.language!, null));
    }
    if (track.isrc != null && track.isrc!.isNotEmpty) out.add(('ISRC', track.isrc!, null));
    if (track.uploaderUsername != null) out.add(('Загрузил', track.uploaderUsername!, null));
    return out;
  }
}

class _Description extends StatelessWidget {
  final String text;
  final bool expanded;
  final VoidCallback onToggle;

  const _Description({required this.text, required this.expanded, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final long = text.length > _LinerNotesState._descClamp;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Описание'),
        const SizedBox(height: 10),
        Text(
          text,
          maxLines: !expanded && long ? 4 : null,
          overflow: !expanded && long ? TextOverflow.ellipsis : TextOverflow.clip,
          style: const TextStyle(fontSize: 13.5, height: 1.55, color: Color(0x8CFFFFFF)),
        ),
        if (long) ...[
          const SizedBox(height: 8),
          _ExpandToggle(expanded: expanded, onTap: onToggle),
        ],
      ],
    );
  }
}

class _ExpandToggle extends StatefulWidget {
  final bool expanded;
  final VoidCallback onTap;

  const _ExpandToggle({required this.expanded, required this.onTap});

  @override
  State<_ExpandToggle> createState() => _ExpandToggleState();
}

class _ExpandToggleState extends State<_ExpandToggle> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final color = _hover ? const Color(0x99FFFFFF) : const Color(0x59FFFFFF);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
              size: 15,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              widget.expanded ? 'Свернуть' : 'Читать дальше',
              style: TextStyle(fontSize: 11, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlbumRow extends ConsumerStatefulWidget {
  final TrackAlbumDto album;
  final Color glow;

  const _AlbumRow({required this.album, required this.glow});

  @override
  ConsumerState<_AlbumRow> createState() => _AlbumRowState();
}

class _AlbumRowState extends ConsumerState<_AlbumRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final album = widget.album;
    final subtitle = album.year != null ? 'Альбом · ${album.year}' : 'Альбом';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => ref.read(routerProvider.notifier).push(AlbumRoute(album.id)),
        child: AnimatedContainer(
          duration: ScTokens.dFast,
          curve: ScTokens.easeApple,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _hover ? const Color(0x0DFFFFFF) : const Color(0x06FFFFFF),
            borderRadius: BorderRadius.circular(ScTokens.rCard),
            border: Border.all(color: const Color(0x12FFFFFF), width: 0.5),
          ),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(ScTokens.rButton),
                  boxShadow: [BoxShadow(color: widget.glow, blurRadius: 20, spreadRadius: -10)],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(ScTokens.rButton),
                  child: TrackArtwork(url: album.coverUrl, size: ArtSize.row),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      subtitle.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        color: Color(0x4DFFFFFF),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      album.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _hover ? const Color(0xFFFFFFFF) : const Color(0xE6FFFFFF),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                LucideIcons.chevronRight,
                size: 20,
                color: _hover ? const Color(0x99FFFFFF) : const Color(0x40FFFFFF),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Participants extends StatelessWidget {
  final List<TrackParticipantDto> people;

  const _Participants({required this.people});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Состав'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final p in people) _PersonChip(person: p)],
        ),
      ],
    );
  }
}

class _PersonChip extends StatelessWidget {
  final TrackParticipantDto person;

  const _PersonChip({required this.person});

  @override
  Widget build(BuildContext context) {
    final role = person.role?.trim();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x08FFFFFF),
        borderRadius: BorderRadius.circular(ScTokens.rButton),
        border: Border.all(color: const Color(0x0DFFFFFF), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (role != null && role.isNotEmpty)
            Text(
              role.toUpperCase(),
              style: const TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
                color: Color(0x59FFFFFF),
              ),
            ),
          if (role != null && role.isNotEmpty) const SizedBox(height: 3),
          Text(
            person.name,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xCCFFFFFF),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tags extends StatelessWidget {
  final List<String> tags;

  const _Tags({required this.tags});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Padding(
          padding: EdgeInsets.only(right: 2),
          child: Icon(Icons.tag_rounded, size: 13, color: Color(0x33FFFFFF)),
        ),
        for (final tag in tags) _TagChip(tag: tag),
      ],
    );
  }
}

class _TagChip extends StatefulWidget {
  final String tag;

  const _TagChip({required this.tag});

  @override
  State<_TagChip> createState() => _TagChipState();
}

class _TagChipState extends State<_TagChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: ScTokens.dFast,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _hover ? const Color(0x12FFFFFF) : const Color(0x0AFFFFFF),
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(color: const Color(0x0DFFFFFF), width: 0.5),
        ),
        child: Text(
          widget.tag,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: _hover ? const Color(0x99FFFFFF) : const Color(0x66FFFFFF),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 2.2,
        color: Color(0x4DFFFFFF),
      ),
    );
  }
}

class _StatOrb extends StatelessWidget {
  final int? value;
  final String label;
  final Color glow;

  const _StatOrb({required this.value, required this.label, required this.glow});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0x08FFFFFF),
        borderRadius: BorderRadius.circular(ScTokens.rCard),
        border: Border.all(color: const Color(0x0DFFFFFF), width: 0.5),
        boxShadow: [BoxShadow(color: glow, blurRadius: 24, spreadRadius: -8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatCount(value ?? 0),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xF2FFFFFF),
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0x73FFFFFF)),
          ),
        ],
      ),
    );
  }
}

class _Credit extends StatefulWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _Credit({required this.label, required this.value, this.onTap});

  @override
  State<_Credit> createState() => _CreditState();
}

class _CreditState extends State<_Credit> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final tappable = widget.onTap != null;
    final valueColor = tappable && _hover
        ? const Color(0xFFFFFFFF)
        : const Color(0xB3FFFFFF);

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SectionLabel(widget.label),
        const SizedBox(height: 4),
        Text(
          widget.value,
          style: TextStyle(fontSize: 13, color: valueColor),
        ),
      ],
    );

    if (!tappable) return body;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(onTap: widget.onTap, child: body),
    );
  }
}
