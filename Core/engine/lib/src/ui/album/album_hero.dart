import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../providers.dart';
import '../../rust/api.dart';
import '../../rust/dto.dart';
import 'album_aura.dart';
import 'album_cover_artifact.dart';
import 'album_hero_chips.dart';
import 'album_play_button.dart';
import 'album_track_list.dart';

/// Шапка альбома (легаси `AlbumHero` внутри `GlassHeroPanel`). Слева —
/// обложка-артефакт; справа — kind/verified бейджи, заголовок, чипы артистов,
/// инфо-чипы (год/треки/длительность/доступность) и play-кнопка.
class AlbumHero extends StatelessWidget {
  final AlbumDetailDto album;
  final bool hasStar;
  final AlbumAura aura;

  const AlbumHero({super.key, required this.album, required this.hasStar, required this.aura});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1024;

    var totalMs = 0;
    final playable = <TrackDto>[];
    for (final t in album.tracks) {
      if (!isWanted(t)) {
        playable.add(t);
        totalMs += t.durationMs.toInt();
      }
    }

    final cover = AlbumCoverArtifact(
      title: album.title,
      coverUrl: album.coverUrl,
      hasStar: hasStar,
      aura: aura,
    );

    final info = _HeroInfo(
      album: album,
      aura: aura,
      hasStar: hasStar,
      totalMs: totalMs,
      indexedCount: playable.length,
      playable: playable,
    );

    return _HeroShell(
      hasStar: hasStar,
      aura: aura,
      child: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [cover, const SizedBox(width: 48), Expanded(child: info)],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [cover, const SizedBox(height: 32), info],
            ),
    );
  }
}

/// Стеклянный hero-контейнер (легаси `GlassHeroPanel`): `rounded-[2.5rem]`,
/// специальный градиент, аура-тень у звёздного.
class _HeroShell extends StatelessWidget {
  final bool hasStar;
  final AlbumAura aura;
  final Widget child;

  const _HeroShell({required this.hasStar, required this.aura, required this.child});

  @override
  Widget build(BuildContext context) {
    final blur = PerfProfile.of(context).blur(ScTokens.blurBeautyNormal);
    const radius = BorderRadius.all(Radius.circular(40)); // 2.5rem

    final body = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: blur > 0
            ? const LinearGradient(
                begin: Alignment(-0.6, -1),
                end: Alignment(0.6, 1),
                colors: [Color(0x0FFFFFFF), Color(0x05FFFFFF), Color(0x0AFFFFFF)],
                stops: [0, 0.5, 1],
              )
            : null,
        color: blur > 0 ? null : const Color(0xD114141C),
        border: Border.all(color: const Color(0x14FFFFFF)),
        boxShadow: [
          BoxShadow(
            color: hasStar ? aura.rgba(0.28) : const Color(0x59000000),
            blurRadius: 80,
            offset: const Offset(0, 30),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(MediaQuery.sizeOf(context).width >= 768 ? 40 : 24),
        child: child,
      ),
    );

    final clipped = blur > 0
        ? ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blur / 2, sigmaY: blur / 2),
              child: body,
            ),
          )
        : ClipRRect(borderRadius: radius, child: body);

    // Specular hairline (легаси): тонкая светлая полоса по верхней кромке.
    return Stack(
      children: [
        clipped,
        const Positioned(
          left: 32,
          right: 32,
          top: 0,
          child: SizedBox(
            height: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0x00FFFFFF), Color(0x59FFFFFF), Color(0x00FFFFFF)],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Правая колонка: бейджи, заголовок, артисты, инфо, play.
class _HeroInfo extends ConsumerWidget {
  final AlbumDetailDto album;
  final AlbumAura aura;
  final bool hasStar;
  final int totalMs;
  final int indexedCount;
  final List<TrackDto> playable;

  const _HeroInfo({
    required this.album,
    required this.aura,
    required this.hasStar,
    required this.totalMs,
    required this.indexedCount,
    required this.playable,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.sizeOf(context).width >= 1024;
    final align = wide ? CrossAxisAlignment.start : CrossAxisAlignment.center;
    final wrapAlign = wide ? WrapAlignment.start : WrapAlignment.center;

    final featured = album.artists.where((a) => a.role != 'primary').toList();

    return Column(
      crossAxisAlignment: align,
      children: [
        AlbumKindBadges(album: album, aura: aura, hasStar: hasStar, align: wrapAlign),
        const SizedBox(height: 20),
        Text(
          album.title,
          textAlign: wide ? TextAlign.left : TextAlign.center,
          style: TextStyle(
            color: hasStar ? null : const Color(0xFFFFFFFF),
            foreground: hasStar ? (Paint()..shader = _titleShader(aura)) : null,
            fontSize: MediaQuery.sizeOf(context).width >= 768 ? 64 : 44,
            fontWeight: FontWeight.w900,
            height: 0.85,
            letterSpacing: -1.5,
            shadows: const [Shadow(color: Color(0x80000000), blurRadius: 24, offset: Offset(0, 8))],
          ),
        ),
        if (album.primaryArtist.name.isNotEmpty || featured.isNotEmpty) ...[
          const SizedBox(height: 20),
          AlbumArtistChips(
            primary: album.primaryArtist,
            featured: featured,
            aura: aura,
            align: wrapAlign,
            onTap: (id) => ref.read(routerProvider.notifier).push(ArtistRoute(id)),
          ),
        ],
        const SizedBox(height: 20),
        AlbumInfoChips(
          album: album,
          aura: aura,
          totalMs: totalMs,
          indexedCount: indexedCount,
          align: wrapAlign,
        ),
        const SizedBox(height: 24),
        Align(
          alignment: wide ? Alignment.centerLeft : Alignment.center,
          child: AlbumPlayButton(playable: playable, aura: aura),
        ),
      ],
    );
  }
}

Shader _titleShader(AlbumAura aura) => aura.nameGradient.createShader(
      const Rect.fromLTWH(0, 0, 400, 80),
    );
