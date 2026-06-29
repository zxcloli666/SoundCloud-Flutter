import 'package:flutter/material.dart';
import 'package:sc_visual/sc_visual.dart';

import 'settings_primitives.dart';

/// Аккаунт: профиль текущего пользователя (аватар + ник + STAR-бейдж), кнопки
/// «Передать сессию» и выход (легаси `AccountCard`). Открывается только за гейтом
/// входа — своего logged-out состояния нет. Действия — через колбэки страницы.
class AccountSection extends StatelessWidget {
  final String username;
  final String? avatarUrl;
  final bool isPremium;
  final VoidCallback onTransferSession;
  final VoidCallback onSignOut;

  const AccountSection({
    super.key,
    required this.username,
    required this.avatarUrl,
    required this.isPremium,
    required this.onTransferSession,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      title: 'Аккаунт',
      icon: LucideIcons.user,
      action: isPremium ? const StarBadge(size: StarBadgeSize.sm) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Avatar(src: avatarUrl, alt: username, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xEBFFFFFF),
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      isPremium ? 'STAR-подписка активна' : 'Бесплатный аккаунт',
                      style: const TextStyle(color: Color(0x8CFFFFFF), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _GhostButton(
            icon: LucideIcons.smartphone,
            label: 'Передать сессию',
            onTap: onTransferSession,
          ),
          const SizedBox(height: 10),
          _GhostButton(
            icon: LucideIcons.logOut,
            label: 'Выйти',
            danger: true,
            onTap: onSignOut,
          ),
        ],
      ),
    );
  }
}

/// Ghost-кнопка строки действий аккаунта: нейтральная или опасная (выход).
class _GhostButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool danger;
  final VoidCallback onTap;

  const _GhostButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  @override
  State<_GhostButton> createState() => _GhostButtonState();
}

class _GhostButtonState extends State<_GhostButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final danger = widget.danger;
    final fg = danger ? const Color(0xFFF87171) : const Color(0xBFFFFFFF);
    final bg = danger
        ? (_hover ? const Color(0x33EF4444) : const Color(0x1AEF4444))
        : (_hover ? const Color(0x14FFFFFF) : const Color(0x0AFFFFFF));
    final border = danger
        ? (_hover ? const Color(0x33EF4444) : const Color(0x1AEF4444))
        : (_hover ? const Color(0x1FFFFFFF) : const Color(0x0FFFFFFF));

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: ScTokens.dSidebar,
          curve: ScTokens.easeApple,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 14, color: fg),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(color: fg, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
