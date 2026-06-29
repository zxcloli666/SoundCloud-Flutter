import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import '../providers.dart';
import '../rust/dto.dart';
import 'album/album_aura.dart';
import 'album/album_cast.dart';
import 'album/album_hero.dart';
import 'album/album_track_list.dart';

/// Экран альбома (легаси `AlbumPage`, blueprint §3.9). Контейнер `max-w 1480`,
/// за `AuraField`-атмосферой. Аура звёздного артиста (`artistStarProvider`)
/// управляет цветом всего экрана; не премиум — выводим из акцента зрителя.
class AlbumPage extends ConsumerWidget {
  final String id;

  const AlbumPage({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final album = ref.watch(albumDetailProvider(id));

    return album.when(
      loading: () => const _Centered(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (error, _) => const _Centered(
        child: Text('Не удалось загрузить альбом', style: TextStyle(color: ScTokens.textSecondary, fontSize: 14)),
      ),
      data: (data) => _AlbumBody(album: data),
    );
  }
}

/// Тело экрана: резолвит ауру первичного артиста и отрисовывает шапку/состав/
/// треклист. Аура async — пока грузится/ошибка, держим viewer-fallback, чтобы
/// контент не моргал и не блокировался.
class _AlbumBody extends ConsumerStatefulWidget {
  final AlbumDetailDto album;

  const _AlbumBody({required this.album});

  @override
  ConsumerState<_AlbumBody> createState() => _AlbumBodyState();
}

class _AlbumBodyState extends ConsumerState<_AlbumBody> {
  final _scroll = SmoothScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final album = widget.album;
    final viewerAccent = ScTheme.paletteOf(context).accent;
    final star = album.primaryArtist.id.isEmpty
        ? null
        : ref.watch(artistStarProvider(album.primaryArtist.id)).value;
    final aura = AlbumAura.fromStar(star, viewerAccent);

    return Atmosphere(
      variant: AtmosphereVariant.aura,
      tint: aura.orbs,
      child: SingleChildScrollView(
        controller: _scroll,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1480),
            child: Padding(
              padding: _contentPadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AlbumHero(album: album, hasStar: aura.isStar, aura: aura),
                  const SizedBox(height: 32),
                  AlbumCast(artists: album.artists, aura: aura),
                  if (album.artists.isNotEmpty) const SizedBox(height: 32),
                  AlbumTrackList(tracks: album.tracks, aura: aura),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

EdgeInsets _contentPadding(BuildContext context) {
  final wide = MediaQuery.sizeOf(context).width >= 768;
  return EdgeInsets.fromLTRB(wide ? 32 : 16, wide ? 64 : 40, wide ? 32 : 16, 128);
}

class _Centered extends StatelessWidget {
  final Widget child;

  const _Centered({required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: double.infinity, height: double.infinity, child: Center(child: child));
  }
}
