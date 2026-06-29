import 'package:flutter/material.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../rust/dto.dart' show UserDto;

/// Сетка карточек-связей (легаси `UserConnectionsTab`): VirtualGrid `itemHeight
/// 220 minColumnWidth 200 gap 20`, карточка `p-6 rounded-3xl hover:scale-1.02`,
/// круглый аватар 80px + имя + счётчик подписчиков. Тап открывает профиль.
class UserConnectionGrid extends StatelessWidget {
  final List<UserDto> users;
  final void Function(UserDto user) onOpen;

  const UserConnectionGrid({super.key, required this.users, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return VirtualGrid<UserDto>(
      items: users,
      itemHeight: 220,
      minColumnWidth: 200,
      gap: 20,
      overscan: 3,
      getItemKey: (u, _) => ValueKey(u.urn),
      renderItem: (context, u, _) =>
          _ConnectionCard(user: u, onTap: () => onOpen(u)),
    );
  }
}

class _ConnectionCard extends StatefulWidget {
  final UserDto user;
  final VoidCallback onTap;

  const _ConnectionCard({required this.user, required this.onTap});

  @override
  State<_ConnectionCard> createState() => _ConnectionCardState();
}

class _ConnectionCardState extends State<_ConnectionCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final blurred = PerfProfile.of(context).sigma(20) > 0;
    final u = widget.user;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hover ? 1.02 : 1.0,
          duration: ScTokens.dGlass,
          curve: ScTokens.easeApple,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: _flatGlass(
              translucent: blurred,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Avatar(url: u.avatarUrl, ring: _hover ? const Color(0x4DFFFFFF) : const Color(0x1AFFFFFF)),
                    const SizedBox(height: 12),
                    Text(
                      u.username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _hover ? Colors.white : const Color(0xE6FFFFFF),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (u.followersCount != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${formatCount(u.followersCount!.toInt())} FOLLOWERS',
                        style: const TextStyle(
                          color: Color(0x4DFFFFFF),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Карточки лежат над Atmosphere страницы — отдельный BackdropFilter на каждую
  // в виртуализированной сетке = N перекрывающихся saveLayer+blur за кадр. Берём
  // плоскую полупрозрачную заливку: визуально читается тем же стеклом, без блюра.
  Widget _flatGlass({required bool translucent, required Widget child}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: translucent ? const Color(0x66181820) : const Color(0xD9181820),
        border: Border.all(color: const Color(0x0FFFFFFF), width: 0.5),
      ),
      child: child,
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? url;
  final Color ring;

  const _Avatar({required this.url, required this.ring});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ring, width: 2),
        color: const Color(0x14FFFFFF),
      ),
      clipBehavior: Clip.antiAlias,
      child: url != null && url!.isNotEmpty
          ? Image(
              image: ScImageProxy.provider(url!),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _fallback,
            )
          : _fallback,
    );
  }

  static const _fallback =
      Icon(LucideIcons.user, size: 32, color: Color(0x4DFFFFFF));
}
