import 'package:flutter/material.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../rust/dto.dart';
import 'artist_aura.dart';
import 'artist_socials.dart';

/// Вкладка «О себе» (§3.9 `ArtistAboutTab`): био-карточка (2 колонки на широких)
/// + сайдбар с SC-аккаунтами и ссылками. SC-аккаунт → `UserRoute`.
class ArtistAboutTab extends StatelessWidget {
  final ArtistDetailDto artist;
  final ArtistAura aura;
  final ValueChanged<String> onOpenUser;

  const ArtistAboutTab({
    super.key,
    required this.artist,
    required this.aura,
    required this.onOpenUser,
  });

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1024;
    final bio = _bioCard();
    final side = _sideColumn();

    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [bio, const SizedBox(height: 24), ...side],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 2, child: bio),
        const SizedBox(width: 24),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: side),
        ),
      ],
    );
  }

  Widget _bioCard() {
    final hasBio = artist.bio != null && artist.bio!.isNotEmpty;
    return GlassPanel(
      radius: 24,
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(LucideIcons.mic, 'О АРТИСТЕ', const Color(0x66FFFFFF)),
          const SizedBox(height: 16),
          if (hasBio)
            SelectionArea(
              child: Text(
                artist.bio!,
                style: const TextStyle(color: Color(0xBFFFFFFF), fontSize: 15, height: 1.6),
              ),
            )
          else
            const Text('Описание не указано',
                style: TextStyle(color: Color(0x4DFFFFFF), fontSize: 13, fontStyle: FontStyle.italic)),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (artist.country != null && artist.country!.isNotEmpty)
                _stat(LucideIcons.globe, 'Страна', artist.country!),
              _stat(LucideIcons.check, 'Уверенность', '${(artist.confidence * 100).round()}%', iconColor: const Color(0xFF34D399)),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _sideColumn() {
    return [
      if (artist.scAccounts.isNotEmpty) _scAccountsCard(),
      if (artist.scAccounts.isNotEmpty && artist.socials.isNotEmpty) const SizedBox(height: 24),
      if (artist.socials.isNotEmpty) _linksCard(),
    ];
  }

  Widget _scAccountsCard() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment(-0.5, -1),
          end: Alignment(0.5, 1),
          colors: [Color(0x14FF5500), Color(0x05FFFFFF)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x2EFF5500), width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(LucideIcons.cloud, 'SC АККАУНТЫ', const Color(0xCCFFB088)),
            const SizedBox(height: 12),
            for (final acc in artist.scAccounts) _scAccountRow(acc),
          ],
        ),
      ),
    );
  }

  Widget _scAccountRow(ScAccountDto acc) {
    final role = acc.role ?? '';
    final label = role == 'main'
        ? 'Основной'
        : role == 'demo'
            ? 'Демо'
            : role;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => onOpenUser('soundcloud:users:${acc.scUserId}'),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0x14FF5500),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x29FF5500), width: 0.5),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0x0AFFFFFF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(LucideIcons.cloud, size: 14, color: Color(0xFFFFB088)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Color(0xD9FFFFFF), fontSize: 12, fontWeight: FontWeight.w600)),
                      Text('ID ${acc.scUserId}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0x59FFFFFF),
                            fontSize: 10,
                            fontFeatures: [FontFeature.tabularFigures()],
                          )),
                    ],
                  ),
                ),
                if (acc.verified) const Icon(LucideIcons.check, size: 12, color: Color(0xFF34D399)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _linksCard() {
    return GlassPanel(
      radius: 24,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(null, 'ССЫЛКИ', const Color(0x66FFFFFF)),
          const SizedBox(height: 12),
          for (final s in artist.socials) _linkRow(s),
        ],
      ),
    );
  }

  Widget _linkRow(SocialDto s) {
    final meta = socialMeta(s.kind);
    return ScTooltip(
      message: s.url,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(meta.icon, size: 13, color: const Color(0x73FFFFFF)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(meta.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 12, fontWeight: FontWeight.w500)),
              ),
              if (s.source != null && s.source!.isNotEmpty)
                Text(s.source!.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0x33FFFFFF),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.6,
                    )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(IconData? icon, String label, Color color) {
    return Row(
      children: [
        if (icon != null) ...[Icon(icon, size: 11, color: color), const SizedBox(width: 8)],
        Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2.2)),
      ],
    );
  }

  Widget _stat(IconData icon, String label, String value, {Color iconColor = const Color(0x73FFFFFF)}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x0AFFFFFF),
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: const Color(0x14FFFFFF), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: iconColor),
          const SizedBox(width: 8),
          Text(label.toUpperCase(),
              style: const TextStyle(color: Color(0x66FFFFFF), fontSize: 10, letterSpacing: 1.8)),
          const SizedBox(width: 8),
          Text(value, style: const TextStyle(color: Color(0xD9FFFFFF), fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
