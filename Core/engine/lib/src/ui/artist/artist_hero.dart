import 'package:flutter/material.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../rust/dto.dart';
import 'artist_aura.dart';
import 'artist_hero_chips.dart';

/// Геро артиста (§3.9 `ArtistHero`): стеклянная featured-плита, аватар-артефакт,
/// имя (gradient-clip при ауре), сворачиваемое био, чипы соц-сетей + SC-аккаунтов,
/// колонка стат-орбов (lg+) / компактная полоса (narrow).
class ArtistHero extends StatefulWidget {
  final ArtistDetailDto artist;
  final bool hasStar;
  final ArtistAura aura;
  final ValueChanged<String> onOpenUser;

  const ArtistHero({
    super.key,
    required this.artist,
    required this.hasStar,
    required this.aura,
    required this.onOpenUser,
  });

  @override
  State<ArtistHero> createState() => _ArtistHeroState();
}

class _ArtistHeroState extends State<ArtistHero> {
  bool _bioExpanded = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.artist;
    final wide = MediaQuery.sizeOf(context).width >= 1024;

    return GlassPanel(
      variant: GlassVariant.featured,
      radius: 40, // rounded-[2.5rem]
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.all(wide ? 40 : 24),
            child: wide ? _wideBody(a) : _narrowBody(a),
          ),
          if (!wide) _compactStats(a),
        ],
      ),
    );
  }

  Widget _wideBody(ArtistDetailDto a) {
    // IntrinsicHeight даёт Row конечную высоту: без неё `stretch` в безграничной
    // высоте скролл-вьюпорта растягивает детей до бесконечности и гасит контент
    // (та же гоча, что чинит DiscoverHero/OfflinePage).
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AvatarArtifact(
            username: a.name,
            avatarUrl: a.avatarUrl,
            hasStar: widget.hasStar,
            auraOrbs: widget.aura.orbs,
          ),
          const SizedBox(width: 40),
          Expanded(child: _info(a, center: false)),
          const SizedBox(width: 32),
          SizedBox(width: 188, child: _statColumn(a)),
        ],
      ),
    );
  }

  Widget _narrowBody(ArtistDetailDto a) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AvatarArtifact(
          username: a.name,
          avatarUrl: a.avatarUrl,
          hasStar: widget.hasStar,
          auraOrbs: widget.aura.orbs,
        ),
        const SizedBox(height: 32),
        _info(a, center: true),
      ],
    );
  }

  Widget _info(ArtistDetailDto a, {required bool center}) {
    final align = center ? CrossAxisAlignment.center : CrossAxisAlignment.start;
    final textAlign = center ? TextAlign.center : TextAlign.start;
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: align,
      children: [
        _topChips(a, center: center),
        const SizedBox(height: 20),
        _name(a, textAlign),
        if (a.bio != null && a.bio!.isNotEmpty) ...[
          const SizedBox(height: 20),
          _bio(a.bio!, center: center),
        ],
        if (a.socials.isNotEmpty || a.scAccounts.isNotEmpty) ...[
          const SizedBox(height: 20),
          _socials(a, center: center),
        ],
      ],
    );
  }

  Widget _topChips(ArtistDetailDto a, {required bool center}) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: center ? WrapAlignment.center : WrapAlignment.start,
      children: [
        if (a.confidence >= 0.7) const VerifiedBadge(),
        if (a.country != null && a.country!.isNotEmpty)
          InfoChip(icon: LucideIcons.globe, label: a.country!),
        const InfoChip(icon: LucideIcons.mic, label: 'Артист'),
      ],
    );
  }

  Widget _name(ArtistDetailDto a, TextAlign textAlign) {
    final wide = MediaQuery.sizeOf(context).width >= 768;
    final style = TextStyle(
      fontSize: wide ? 72 : 48,
      fontWeight: FontWeight.w900,
      height: 0.85,
      letterSpacing: -2,
      color: const Color(0xFFFFFFFF),
      shadows: const [Shadow(color: Color(0x80000000), blurRadius: 24, offset: Offset(0, 8))],
    );
    final text = Text(a.name, textAlign: textAlign, style: style);
    if (!widget.hasStar) return text;
    // Star: gradient-clip имени аурой.
    return ShaderMask(
      shaderCallback: (bounds) => widget.aura.nameGradient.createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: Text(a.name, textAlign: textAlign, style: style.copyWith(color: const Color(0xFFFFFFFF))),
    );
  }

  Widget _bio(String bio, {required bool center}) {
    return GestureDetector(
      onTap: () => setState(() => _bioExpanded = !_bioExpanded),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Column(
          crossAxisAlignment: center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 672), // max-w-2xl
              child: Text(
                bio,
                maxLines: _bioExpanded ? null : 2,
                overflow: _bioExpanded ? TextOverflow.clip : TextOverflow.ellipsis,
                textAlign: center ? TextAlign.center : TextAlign.start,
                style: const TextStyle(
                  color: Color(0xA6FFFFFF), // white/65
                  fontSize: 15,
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedRotation(
                  turns: _bioExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 500),
                  child: const Icon(LucideIcons.chevronDown, size: 14, color: Color(0x4DFFFFFF)),
                ),
                const SizedBox(width: 4),
                Text(
                  _bioExpanded ? 'СВЕРНУТЬ' : 'ПОДРОБНЕЕ',
                  style: const TextStyle(
                    color: Color(0x4DFFFFFF),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _socials(ArtistDetailDto a, {required bool center}) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: center ? WrapAlignment.center : WrapAlignment.start,
      children: [
        for (final acc in a.scAccounts)
          ScAccountChip(account: acc, onTap: () => widget.onOpenUser('soundcloud:users:${acc.scUserId}')),
        for (final s in a.socials) SocialChip(social: s),
      ],
    );
  }

  Widget _statColumn(ArtistDetailDto a) {
    final tint = widget.aura.rgba(0.18);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StatOrb(value: a.trackCountPrimary, label: 'Треки', accent: tint),
        const SizedBox(height: 12),
        StatOrb(value: a.trackCountFeatured, label: 'Участие', accent: tint),
        const SizedBox(height: 12),
        StatOrb(value: a.albumCount, label: 'Альбомы', accent: tint),
        const SizedBox(height: 12),
        StatOrb(value: a.relatedArtists.length, label: 'Похожие', accent: tint),
      ],
    );
  }

  Widget _compactStats(ArtistDetailDto a) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          CompactStat(icon: LucideIcons.music, value: a.trackCountPrimary, label: 'Треки'),
          CompactStat(icon: LucideIcons.mic, value: a.trackCountFeatured, label: 'Участие'),
          CompactStat(icon: LucideIcons.listMusic, value: a.albumCount, label: 'Альбомы'),
          CompactStat(icon: LucideIcons.users, value: a.relatedArtists.length, label: 'Похожие'),
        ],
      ),
    );
  }
}
