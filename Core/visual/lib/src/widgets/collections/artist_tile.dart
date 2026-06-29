import 'package:flutter/material.dart';

import '../../image_proxy.dart';
import '../../tokens.dart';
import 'collection_art.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Данные круглого тайла артиста (легаси `library/ArtistMiniCard`).
/// `followersLabel` форматируется вызовом (легаси `fc()`).
class ArtistTileData {
  final String username;
  final String? avatarUrl;
  final String? followersLabel;

  const ArtistTileData({required this.username, this.avatarUrl, this.followersLabel});
}

/// Компактный круглый тайл артиста для рейлов хаба (легаси `ArtistMiniCard`):
/// 112px колонка, 88px круглый аватар (ring white/8 → hover white/20 + scale
/// 1.04), имя 13px и счётчик подписчиков.
class ArtistTile extends StatefulWidget {
  final ArtistTileData data;
  final VoidCallback? onTap;

  const ArtistTile({super.key, required this.data, this.onTap});

  @override
  State<ArtistTile> createState() => _ArtistTileState();
}

class _ArtistTileState extends State<ArtistTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: SizedBox(
          width: 112,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _avatar(),
              const SizedBox(height: 10),
              Text(
                widget.data.username,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _hover ? const Color(0xFFFFFFFF) : const Color(0xD9FFFFFF),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (widget.data.followersLabel != null) ...[
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.group, size: 9, color: Color(0x4DFFFFFF)),
                    const SizedBox(width: 4),
                    Text(
                      widget.data.followersLabel!,
                      style: const TextStyle(color: Color(0x4DFFFFFF), fontSize: 10.5),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatar() {
    final url = upscaleArtwork(widget.data.avatarUrl, size: 't200x200');
    final placeholder = const ColoredBox(
      color: Color(0x0DFFFFFF),
      child: Center(child: Icon(LucideIcons.user, size: 26, color: Color(0x33FFFFFF))),
    );
    // PERF: аватар рендерится 88px — декодируем в 88×DPR, а не полный t200x200
    // ARGB (тайл живёт в горизонтальных рейлах; см. TrackArtwork).
    final cacheW = (88 * MediaQuery.devicePixelRatioOf(context)).round();
    final img = (url == null)
        ? placeholder
        : Image(
            image: ResizeImage(ScImageProxy.provider(url), width: cacheW),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => placeholder);

    return AnimatedScale(
      scale: _hover ? 1.04 : 1.0,
      duration: const Duration(milliseconds: 400),
      curve: ScTokens.easeApple,
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: _hover ? const Color(0x33FFFFFF) : const Color(0x14FFFFFF)),
          boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 14, offset: Offset(0, 6))],
        ),
        child: ClipOval(child: img),
      ),
    );
  }
}
