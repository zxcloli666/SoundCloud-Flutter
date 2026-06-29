import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../providers.dart';
import 'user_aura.dart';

/// Кнопка подписки (легаси `FollowBtn`): не-подписан → белый градиент, чёрный
/// текст, аура-тень, sheen на hover; подписан → стеклянная белая.
///
/// Состояние подписки выводится из `meFollowingsProvider` (список моих подписок);
/// тап оптимистично переключает флаг и пишет через `socialController` (единый
/// писатель в нашу БД), на ошибке — откат и инвалидация списка.
class UserFollowButton extends ConsumerStatefulWidget {
  final String urn;
  final UserAura aura;

  const UserFollowButton({super.key, required this.urn, required this.aura});

  @override
  ConsumerState<UserFollowButton> createState() => _UserFollowButtonState();
}

class _UserFollowButtonState extends ConsumerState<UserFollowButton> {
  /// Оптимистичный оверрайд: пока null — читаем из `meFollowingsProvider`.
  bool? _override;
  bool _hover = false;
  bool _busy = false;

  String get _bareUrn => widget.urn.split(':').last;

  bool _followsFromList() {
    final list = ref.watch(meFollowingsProvider).value;
    if (list == null) return false;
    return list.items.any((u) => u.urn.split(':').last == _bareUrn);
  }

  Future<void> _toggle(bool following) async {
    if (_busy) return;
    final next = !following;
    setState(() {
      _override = next;
      _busy = true;
    });
    final social = ref.read(socialControllerProvider);
    try {
      if (next) {
        await social.followUser(widget.urn);
      } else {
        await social.unfollowUser(widget.urn);
      }
      ref.invalidate(meFollowingsProvider);
    } catch (_) {
      if (mounted) setState(() => _override = following); // откат
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final following = _override ?? _followsFromList();
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => _toggle(following),
        child: AnimatedScale(
          scale: !following && _hover ? 1.03 : 1.0,
          duration: ScTokens.dGlass,
          curve: ScTokens.easeLabel,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 28),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: following ? const Color(0x0FFFFFFF) : null,
                gradient: following
                    ? null
                    : const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFFFFFFF), Color(0xFFE5E7EB)],
                      ),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: following ? const Color(0x1FFFFFFF) : const Color(0x66FFFFFF),
                  width: 0.5,
                ),
                boxShadow: following
                    ? null
                    : [BoxShadow(color: widget.aura.rgba(0.28), blurRadius: 32, offset: const Offset(0, 12))],
              ),
              child: Text(
                following ? 'Following' : 'Follow',
                style: TextStyle(
                  color: following ? const Color(0xCCFFFFFF) : const Color(0xFF000000),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
