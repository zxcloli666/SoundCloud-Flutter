import 'package:flutter/material.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../rust/dto.dart';
import 'artist_aura.dart';
import 'tab_states.dart';
import 'year_marker.dart';

/// Вкладка альбомов (§3.9 `ArtistAlbumsTab`): группировка по году, сетка карточек
/// `AlbumCard`, тап → `AlbumRoute`. Бридж даёт лишь id/title/year/role (без
/// обложки/типа) — карточка рисует gradient-fallback по id.
class ArtistAlbumsTab extends StatelessWidget {
  final List<AlbumRefDto> albums;
  final ArtistAura aura;
  final bool isLoading;
  final ValueChanged<String> onOpenAlbum;

  const ArtistAlbumsTab({
    super.key,
    required this.albums,
    required this.aura,
    required this.onOpenAlbum,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const TabLoader();
    if (albums.isEmpty) {
      return const TabEmpty(icon: LucideIcons.disc3, label: 'Альбомов пока нет');
    }

    final buckets = _groupByYear();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final b in buckets) ...[
          _yearGroup(context, b),
          const SizedBox(height: 48),
        ],
      ],
    );
  }

  Widget _yearGroup(BuildContext context, _Bucket b) {
    return YearMarkerRow(
      year: b.year,
      sublabel: b.year != null ? 'Год выхода · ${b.albums.length}' : 'Без даты · ${b.albums.length}',
      aura: aura,
      children: [_grid(context, b.albums)],
    );
  }

  Widget _grid(BuildContext context, List<AlbumRefDto> albums) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 1024
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
      itemCount: albums.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 20,
        crossAxisSpacing: 20,
        childAspectRatio: 0.78,
      ),
      itemBuilder: (context, i) {
        final al = albums[i];
        return AlbumCard(
          data: AlbumCardData(
            id: al.id,
            title: al.title,
            artistName: '',
            kindLabel: _kindLabel(al.role),
            releaseYear: al.releaseYear,
          ),
          accent: aura.primary,
          onTap: () => onOpenAlbum(al.id),
        );
      },
    );
  }

  String _kindLabel(String? role) => role == 'featured' ? 'Участие' : 'Альбом';

  List<_Bucket> _groupByYear() {
    final map = <int?, List<AlbumRefDto>>{};
    for (final a in albums) {
      (map[a.releaseYear] ??= []).add(a);
    }
    final known = map.entries.where((e) => e.key != null).toList()
      ..sort((a, b) => (b.key ?? 0).compareTo(a.key ?? 0));
    final out = [for (final e in known) _Bucket(e.key, e.value)];
    final undated = map[null];
    if (undated != null && undated.isNotEmpty) out.add(_Bucket(null, undated));
    return out;
  }
}

class _Bucket {
  final int? year;
  final List<AlbumRefDto> albums;
  const _Bucket(this.year, this.albums);
}
