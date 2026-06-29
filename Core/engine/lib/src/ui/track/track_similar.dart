import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../providers.dart';
import '../../rust/api.dart';
import '../track_meta.dart';
import 'track_aura.dart';

/// «По волне» — горизонтальный ряд квадратных карточек из ядра-рекомендаций
/// (`recommendationsSimilarProvider`): кластеры id → зарезолвленные треки,
/// схлопнутые в один ряд. Тап → играть, акцент = текущий. Виртуализируется
/// (ListView.builder рендерит только видимые карточки). Молча скрывается, пока
/// рекомендации грузятся или пусты — блок необязательный.
class TrackSimilar extends ConsumerWidget {
  final TrackDto track;
  final TrackAura aura;

  const TrackSimilar({super.key, required this.track, required this.aura});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scId = track.urn.split(':').last;
    final similar = ref.watch(recommendationsSimilarProvider(scId));

    final tracks = similar.value
            ?.expand((c) => c.tracks)
            .where((t) => t.urn != track.urn)
            .toList(growable: false) ??
        const <TrackDto>[];
    if (tracks.isEmpty) return const SizedBox.shrink();

    final currentUrn = ref.watch(playerProvider)?.urn;

    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: GlassPanel(
        variant: GlassVariant.featured,
        radius: ScTokens.rHero,
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
        child: _body(tracks, currentUrn, context, ref),
      ),
    );
  }

  Widget _body(
    List<TrackDto> tracks,
    String? currentUrn,
    BuildContext context,
    WidgetRef ref,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(LucideIcons.audioLines, size: 16, color: aura.accent),
            const SizedBox(width: 10),
            const Text(
              'ПО ВОЛНЕ',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.8,
                color: Color(0x99FFFFFF),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 224,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: tracks.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, i) {
              final t = tracks[i];
              return SizedBox(
                width: 164,
                child: TrackCardTile(
                  data: TrackCardTileData(
                    title: t.title,
                    artistLine: t.artistName,
                    artworkUrl: t.artworkUrl,
                    durationMs: t.durationMs.toInt(),
                    playbackCount: t.playCount?.toInt(),
                    meta: trackScdMeta(t),
                    liked: t.userFavorite ?? false,
                  ),
                  width: 164,
                  playing: t.urn == currentUrn,
                  onPlay: () => _play(ref, context, t),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _play(WidgetRef ref, BuildContext context, TrackDto t) async {
    final messenger = ToastScope.of(context);
    try {
      await ref.read(playerProvider.notifier).play(t);
    } catch (e) {
      messenger.show('Не удалось воспроизвести: $e', kind: ToastKind.error);
    }
  }
}
