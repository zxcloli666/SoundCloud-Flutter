import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../providers.dart';

/// Один чип полоски сущностей: артист / плейлист / юзер над стеной.
class _Entity {
  final String label;
  final String? sub;
  final String? image;
  final bool round;
  final VoidCallback onTap;

  const _Entity({
    required this.label,
    required this.image,
    required this.round,
    required this.onTap,
    this.sub,
  });
}

/// Компактная горизонтальная полоска артистов/плейлистов/юзеров НАД стеной
/// (легаси `EntityStrip`) — никогда не «секция» в столбик. Тянет первые
/// результаты из сущностных провайдеров лениво; пусто — рисует null. Ширина
/// контента ограничена 1100, края гаснут маской.
class SearchEntityStrip extends ConsumerWidget {
  final String query;

  const SearchEntityStrip({super.key, required this.query});

  static const _perKind = 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (query.trim().length < 2) return const SizedBox.shrink();
    final router = ref.read(routerProvider.notifier);
    final items = <_Entity>[
      ...?ref.watch(searchArtistsProvider(query)).value?.items
          .take(_perKind)
          .map((a) => _Entity(
                label: a.name,
                sub: 'Артист',
                image: a.avatarUrl,
                round: true,
                onTap: () => router.push(ArtistRoute(a.id)),
              )),
      ...?ref.watch(searchPlaylistsProvider(query)).value?.items
          .take(_perKind)
          .map((p) => _Entity(
                label: p.title,
                sub: p.isAlbum ? 'Альбом' : 'Плейлист',
                image: p.artworkUrl,
                round: false,
                onTap: () => router.push(PlaylistRoute(p.urn)),
              )),
      ...?ref.watch(searchUsersProvider(query)).value?.items
          .take(_perKind)
          .map((u) => _Entity(
                label: u.username,
                sub: u.followersCount == null
                    ? 'Профиль'
                    : '${formatCount(u.followersCount!.toInt())} подписчиков',
                image: u.avatarUrl,
                round: true,
                onTap: () => router.push(UserRoute(u.urn)),
              )),
    ];
    if (items.isEmpty) return const SizedBox.shrink();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: SizedBox(
          height: 52,
          child: ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              colors: [
                Color(0x00000000),
                Color(0xFF000000),
                Color(0xFF000000),
                Color(0x00000000),
              ],
              stops: [0, 0.02, 0.96, 1],
            ).createShader(rect),
            blendMode: BlendMode.dstIn,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) => _EntityChip(entity: items[i]),
            ),
          ),
        ),
      ),
    );
  }
}

class _EntityChip extends StatefulWidget {
  final _Entity entity;
  const _EntityChip({required this.entity});

  @override
  State<_EntityChip> createState() => _EntityChipState();
}

class _EntityChipState extends State<_EntityChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.entity;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: e.onTap,
        child: AnimatedContainer(
          duration: ScTokens.dFast,
          padding: const EdgeInsets.only(left: 4, right: 14),
          decoration: BoxDecoration(
            color: _hover ? const Color(0x0FFFFFFF) : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0x14FFFFFF), width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _thumb(e),
              const SizedBox(width: 10),
              Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 140),
                    child: Text(
                      e.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: _hover
                            ? Colors.white
                            : const Color(0xCCFFFFFF),
                      ),
                    ),
                  ),
                  if (e.sub != null)
                    Text(
                      e.sub!,
                      style: const TextStyle(
                          fontSize: 10.5, color: Color(0x59FFFFFF)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumb(_Entity e) {
    final radius = e.round
        ? BorderRadius.circular(999)
        : BorderRadius.circular(8);
    final url = e.image;
    return ClipRRect(
      borderRadius: radius,
      child: Container(
        width: 36,
        height: 36,
        color: const Color(0x0DFFFFFF),
        alignment: Alignment.center,
        child: url == null || url.isEmpty
            ? Text(
                e.label.isEmpty ? '?' : e.label.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0x66FFFFFF)),
              )
            : Image(
                image: ScImageProxy.provider(url),
                fit: BoxFit.cover,
                width: 36,
                height: 36,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
      ),
    );
  }
}
