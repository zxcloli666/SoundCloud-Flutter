import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:sc_visual/sc_visual.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../rust/dto.dart';
import 'artist_socials.dart';

/// Стат-орб геро (легаси `StatOrb`): крупное число + лейбл на акцентном тинте.
class StatOrb extends StatelessWidget {
  final int value;
  final String label;
  final Color accent;

  const StatOrb({super.key, required this.value, required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: const Alignment(-0.7, -1),
          end: const Alignment(0.7, 1),
          colors: [accent, const Color(0x0AFFFFFF)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x14FFFFFF), width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.8,
                color: Color(0x59FFFFFF),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Компактный стат (легаси `CompactStat`) — для узкой раскладки геро.
class CompactStat extends StatelessWidget {
  final IconData icon;
  final int value;
  final String label;

  const CompactStat({super.key, required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x0AFFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x14FFFFFF), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Icon(icon, size: 12, color: const Color(0x66FFFFFF)),
          const SizedBox(width: 8),
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
              color: Color(0x59FFFFFF),
            ),
          ),
        ],
      ),
    );
  }
}

/// Verified-бейдж (синий круг с галочкой, легаси `VerifiedBadge`).
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0x33FFFFFF), width: 2),
      ),
      child: const Icon(LucideIcons.check, size: 13, color: Colors.white),
    );
  }
}

/// Стеклянный info-pill (легаси `InfoChip`): иконка + uppercase-лейбл.
class InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const InfoChip({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x0AFFFFFF),
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: const Color(0x14FFFFFF), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: const Color(0x8CFFFFFF)),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.6,
              color: Color(0x8CFFFFFF),
            ),
          ),
        ],
      ),
    );
  }
}

/// Чип внешней соц-ссылки (легаси `SocialChip`). Открытие URL платформо-зависимо;
/// движок без url_launcher — показываем url тултипом.
class SocialChip extends StatelessWidget {
  final SocialDto social;

  const SocialChip({super.key, required this.social});

  @override
  Widget build(BuildContext context) {
    final meta = socialMeta(social.kind);
    return ScTooltip(
      message: social.url,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => _open(social.url),
          child: GlassChip(icon: meta.icon, label: meta.label),
        ),
      ),
    );
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// Чип SC-аккаунта артиста (легаси `ScAccountChip`) — оранжевый тинт, навигация
/// на профиль пользователя.
class ScAccountChip extends StatelessWidget {
  final ScAccountDto account;
  final VoidCallback onTap;

  const ScAccountChip({super.key, required this.account, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final role = account.role ?? '';
    final label = role == 'main'
        ? 'Основной'
        : role == 'demo'
            ? 'Демо'
            : role;
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0x29FF5500), Color(0x0FFF0080)],
            ),
            borderRadius: BorderRadius.circular(9999),
            border: Border.all(color: const Color(0x40FF5500), width: 0.5),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.cloud, size: 13, color: Color(0xFFFFB088)),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xD9FFB088)),
                ),
                if (account.verified) ...[
                  const SizedBox(width: 6),
                  const Icon(LucideIcons.check, size: 11, color: Color(0xFF34D399)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Лёгкий glass-tint pill (легаси blur(16) под бьюти) — основа [SocialChip].
class GlassChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const GlassChip({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final blur = ScPerf.of(context) == PerfMode.light ? 0.0 : 8.0;
    Widget pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x0AFFFFFF),
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: const Color(0x14FFFFFF), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0x73FFFFFF)),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0x8CFFFFFF)),
            ),
          ),
        ],
      ),
    );
    if (blur > 0) {
      pill = ClipRRect(
        borderRadius: BorderRadius.circular(9999),
        child: BackdropFilter(filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur), child: pill),
      );
    }
    return MouseRegion(cursor: SystemMouseCursors.click, child: pill);
  }
}
