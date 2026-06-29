import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../rust/dto_social.dart' show WebProfileDto;
import '../artist/artist_socials.dart';

/// Ряд соц-ссылок профиля (легаси `IdentityHub` web-profiles): стеклянные пилюли
/// с глифом сети + подписью; тап открывает ссылку во внешнем браузере.
class UserWebProfiles extends StatelessWidget {
  final List<WebProfileDto> profiles;
  final WrapAlignment align;

  const UserWebProfiles({super.key, required this.profiles, required this.align});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: align,
      spacing: 8,
      runSpacing: 8,
      children: [for (final p in profiles) _ProfilePill(profile: p)],
    );
  }
}

class _ProfilePill extends StatefulWidget {
  final WebProfileDto profile;

  const _ProfilePill({required this.profile});

  @override
  State<_ProfilePill> createState() => _ProfilePillState();
}

class _ProfilePillState extends State<_ProfilePill> {
  bool _hover = false;

  String get _label {
    final p = widget.profile;
    final raw = p.title ?? p.network ?? p.username;
    if (raw != null && raw.isNotEmpty) return raw;
    return socialLabel(p.network ?? '');
  }

  Future<void> _open() async {
    final uri = Uri.tryParse(widget.profile.url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final meta = socialMeta(widget.profile.network ?? '');
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: _open,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: _hover ? const Color(0x14FFFFFF) : const Color(0x0AFFFFFF),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: _hover ? const Color(0x33FFFFFF) : const Color(0x14FFFFFF),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(meta.icon, size: 13, color: _hover ? const Color(0xE6FFFFFF) : const Color(0x99FFFFFF)),
              const SizedBox(width: 7),
              Text(
                _label,
                style: TextStyle(
                  color: _hover ? const Color(0xF2FFFFFF) : const Color(0xB3FFFFFF),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
