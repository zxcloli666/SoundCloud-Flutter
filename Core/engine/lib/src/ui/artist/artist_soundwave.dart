import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../providers.dart';
import '../../rust/api.dart';
import '../track_meta.dart';
import 'artist_aura.dart';

/// Саундвейв-блок артиста (§3.9 `ArtistSoundWave`): аура-стеклянная плита
/// `rounded-[1.75rem]` с заголовком (бейдж / EQ-бары когда играет + «Волна» +
/// AI-pill + play + collapse) и горизонтальной полкой рекомендованных треков.
///
/// Полка кормится рекомендательным [artistWaveProvider] (`recommendations/artist`)
/// — кластеры резолвятся в треки лениво. Пока волна грузится / если пуста,
/// показываем `popular_tracks` карточки артиста как фолбэк. Play — queue-aware:
/// шелф уходит в очередь воспроизведения.
class ArtistSoundWave extends ConsumerStatefulWidget {
  final String artistId;
  final String artistName;
  final List<TrackDto> fallbackTracks;
  final ArtistAura aura;

  const ArtistSoundWave({
    super.key,
    required this.artistId,
    required this.artistName,
    required this.fallbackTracks,
    required this.aura,
  });

  @override
  ConsumerState<ArtistSoundWave> createState() => _ArtistSoundWaveState();
}

class _ArtistSoundWaveState extends ConsumerState<ArtistSoundWave> {
  bool _collapsed = false;

  /// Волна → плоский шелф треков; пока грузится/пусто — популярные артиста.
  List<TrackDto> _shelfTracks() {
    final wave = ref.watch(artistWaveProvider(widget.artistId));
    final resolved = wave.maybeWhen(
      data: (clusters) => clusters.expand((c) => c.tracks).toList(),
      orElse: () => const <TrackDto>[],
    );
    return resolved.isNotEmpty ? resolved : widget.fallbackTracks;
  }

  @override
  Widget build(BuildContext context) {
    final tracks = _shelfTracks();
    if (tracks.isEmpty) return const SizedBox.shrink();

    final perf = ScPerf.of(context);
    final blur = PerfProfile.of(context).sigma(24);
    final radius = BorderRadius.circular(28);
    final current = ref.watch(playerProvider);
    final playing = current != null && tracks.any((t) => t.urn == current.urn);

    Widget body = DecoratedBox(
      decoration: BoxDecoration(
        gradient: blur > 0
            ? const LinearGradient(
                begin: Alignment(-0.6, -1),
                end: Alignment(0.6, 1),
                colors: [Color(0x12FFFFFF), Color(0x06FFFFFF)],
              )
            : null,
        color: blur > 0 ? null : const Color(0xD9121216),
        borderRadius: radius,
        border: Border.all(color: const Color(0x1AFFFFFF)),
        boxShadow: perf == PerfMode.beauty
            ? [BoxShadow(color: widget.aura.rgba(0.22), blurRadius: 80)]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(tracks, playing),
          AnimatedSize(
            duration: const Duration(milliseconds: 550),
            curve: ScTokens.easeApple,
            alignment: Alignment.topCenter,
            child: _collapsed ? const SizedBox(width: double.infinity) : _shelf(tracks, current),
          ),
        ],
      ),
    );

    if (blur > 0) {
      body = ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur), child: body),
      );
    }
    return body;
  }

  Widget _header(List<TrackDto> tracks, bool playing) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
      child: Row(
        children: [
          if (playing)
            ClusterBars(
              levels: const [0.5, 0.8, 0.4, 0.95, 0.6],
              playing: true,
              height: 22,
              barWidth: 3,
            )
          else
            _auraBadge(),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'Волна',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFFFFFFF),
                        shadows: [Shadow(color: widget.aura.rgba(0.4), blurRadius: 12)],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _aiPill(),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  widget.artistName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0x73FFFFFF), fontSize: 11),
                ),
              ],
            ),
          ),
          _playButton(tracks),
          const SizedBox(width: 6),
          _collapseChevron(),
        ],
      ),
    );
  }

  Widget _auraBadge() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [widget.aura.rgba(0.55), widget.aura.rgba(0.12)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.aura.rgba(0.4), width: 0.5),
        boxShadow: ScPerf.of(context) == PerfMode.beauty
            ? [BoxShadow(color: widget.aura.rgba(0.2), blurRadius: 22)]
            : null,
      ),
      child: const Icon(LucideIcons.audioLines, size: 18, color: Colors.white),
    );
  }

  Widget _aiPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: widget.aura.rgba(0.16),
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: widget.aura.rgba(0.3), width: 0.5),
      ),
      child: const Text(
        'AI',
        style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.2),
      ),
    );
  }

  Widget _playButton(List<TrackDto> tracks) {
    return GestureDetector(
      onTap: () => _playFirst(tracks),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [widget.aura.primary, widget.aura.rgba(0.7)],
            ),
            borderRadius: BorderRadius.circular(9999),
            boxShadow: [BoxShadow(color: widget.aura.rgba(0.4), blurRadius: 20, offset: const Offset(0, 6))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(LucideIcons.play, size: 18, color: Colors.white),
              SizedBox(width: 6),
              Text('Слушать', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _collapseChevron() {
    return GestureDetector(
      onTap: () => setState(() => _collapsed = !_collapsed),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: SizedBox(
          width: 32,
          height: 32,
          child: AnimatedRotation(
            turns: _collapsed ? 0.5 : 0,
            duration: const Duration(milliseconds: 300),
            child: const Icon(LucideIcons.chevronUp, size: 20, color: Color(0x73FFFFFF)),
          ),
        ),
      ),
    );
  }

  Widget _shelf(List<TrackDto> tracks, TrackDto? current) {
    final shelf = tracks.take(20).toList();
    return SizedBox(
      height: 232,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        itemCount: shelf.length,
        itemBuilder: (context, i) {
          final t = shelf[i];
          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TrackCardTile(
              width: 168,
              data: TrackCardTileData(
                title: t.title,
                artistLine: t.artistName,
                artworkUrl: t.artworkUrl,
                durationMs: t.durationMs.toInt(),
                playbackCount: t.playCount?.toInt(),
                meta: trackScdMeta(t),
                liked: t.userFavorite ?? false,
              ),
              playing: current?.urn == t.urn,
              onPlay: () => _play(t, shelf),
            ),
          );
        },
      ),
    );
  }

  void _playFirst(List<TrackDto> tracks) {
    if (tracks.isNotEmpty) _play(tracks.first, tracks);
  }

  /// Queue-aware: волна-шелф становится контекстом очереди, плеер доигрывает его
  /// прежде, чем продолжить рекомендациями.
  Future<void> _play(TrackDto track, List<TrackDto> queue) async {
    final messenger = ToastScope.of(context);
    try {
      await ref.read(playerProvider.notifier).play(track, queue: queue);
    } catch (error) {
      messenger.show('Не удалось воспроизвести: $error', kind: ToastKind.error);
    }
  }
}
