import 'package:flutter/material.dart';
import 'package:sc_visual/sc_visual.dart';

/// Карточка куратора — автор как вкус, а не кредит релиза. Аватар + имя + (для
/// чужого плейлиста) Follow + опц. liner-note (описание плейлиста).
class CuratorCard extends StatelessWidget {
  final String username;
  final String? avatarUrl;
  final Color aura;
  final bool isOwner;
  final String? note;
  final VoidCallback onOpenUser;

  const CuratorCard({
    super.key,
    required this.username,
    required this.avatarUrl,
    required this.aura,
    required this.isOwner,
    required this.note,
    required this.onOpenUser,
  });

  @override
  Widget build(BuildContext context) {
    final trimmed = note?.trim();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0x09FFFFFF),
        borderRadius: BorderRadius.circular(22.4), // rounded-[1.4rem]
        border: Border.all(color: const Color(0x12FFFFFF), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: onOpenUser,
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.fromBorderSide(
                        BorderSide(color: Color(0x1AFFFFFF)),
                      ),
                    ),
                    child: Avatar(src: avatarUrl, alt: username, size: 48),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'CURATED BY',
                      style: TextStyle(
                        color: Color(0x59FFFFFF),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: onOpenUser,
                        child: Text(
                          username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xE6FFFFFF),
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (trimmed != null && trimmed.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.only(left: 14),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: aura.withValues(alpha: 0.45), width: 2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'LINER NOTE',
                    style: TextStyle(
                      color: Color(0x4DFFFFFF),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    trimmed,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0x8CFFFFFF),
                      fontSize: 12.5,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
