import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:sc_visual/sc_visual.dart';

import '../../rust/dto.dart';
import '../../rust/dto_social.dart' show WebProfileDto;
import 'user_aura.dart';
import 'user_chips.dart';
import 'user_follow_button.dart';
import 'user_hero_panel.dart';
import 'user_stat_orb.dart';
import 'user_web_profiles.dart';

/// IdentityHub (легаси §3.11): аватар-артефакт + чипы + имя (star-gradient) +
/// full_name + описание + web-profiles + действия (Follow/CopyLink) + орбы
/// статистики. Пока [user] не резолвился — деградируем до имени из urn, чтобы
/// страница не падала во время загрузки.
class UserIdentityHub extends StatelessWidget {
  final String urn;
  final UserDto? user;
  final List<WebProfileDto> webProfiles;
  final UserAura aura;
  final bool hasStar;
  final bool isOwnProfile;

  const UserIdentityHub({
    super.key,
    required this.urn,
    required this.user,
    required this.webProfiles,
    required this.aura,
    required this.hasStar,
    required this.isOwnProfile,
  });

  String get _username => user?.username ?? _bareId(urn);
  String _bareId(String urn) => urn.split(':').last;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1024;
    final showStatsColumn = MediaQuery.sizeOf(context).width >= 1280;

    final avatar = AvatarArtifact(
      username: _username,
      avatarUrl: user?.avatarUrl,
      hasStar: hasStar,
      auraOrbs: aura.orbs,
      size: wide ? 180 : 148,
    );

    final identity = _Identity(
      urn: urn,
      user: user,
      username: _username,
      webProfiles: webProfiles,
      aura: aura,
      hasStar: hasStar,
      isOwnProfile: isOwnProfile,
    );

    final orbs = _StatOrbs(user: user, aura: aura);

    return UserHeroPanel(
      aura: aura,
      hasStar: hasStar,
      child: Padding(
        padding: EdgeInsets.all(wide ? 40 : 24),
        child: wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  avatar,
                  const SizedBox(width: 40),
                  Expanded(child: identity),
                  if (showStatsColumn) ...[
                    const SizedBox(width: 32),
                    SizedBox(width: 180, child: orbs),
                  ],
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  avatar,
                  const SizedBox(height: 32),
                  identity,
                  const SizedBox(height: 24),
                  orbs,
                ],
              ),
      ),
    );
  }
}

/// Колонка имени: чипы → username (h1) → full_name → описание → web-profiles →
/// ряд действий.
class _Identity extends StatelessWidget {
  final String urn;
  final UserDto? user;
  final String username;
  final List<WebProfileDto> webProfiles;
  final UserAura aura;
  final bool hasStar;
  final bool isOwnProfile;

  const _Identity({
    required this.urn,
    required this.user,
    required this.username,
    required this.webProfiles,
    required this.aura,
    required this.hasStar,
    required this.isOwnProfile,
  });

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1024;
    final cross = wide ? CrossAxisAlignment.start : CrossAxisAlignment.center;
    final align = wide ? WrapAlignment.start : WrapAlignment.center;
    final u = user;

    return Column(
      crossAxisAlignment: cross,
      mainAxisSize: MainAxisSize.min,
      children: [
        _chips(context, align),
        const SizedBox(height: 16),
        _username(context),
        if (u?.fullName != null && u!.fullName != username) ...[
          const SizedBox(height: 8),
          Text(
            u.fullName!,
            textAlign: wide ? TextAlign.left : TextAlign.center,
            style: const TextStyle(
              color: Color(0x66FFFFFF),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        if (u?.description != null && u!.description!.isNotEmpty) ...[
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 672),
            child: SelectableText(
              u.description!,
              textAlign: wide ? TextAlign.left : TextAlign.center,
              maxLines: 3,
              style: const TextStyle(
                color: Color(0xA6FFFFFF),
                fontSize: 15,
                height: 1.6,
              ),
            ),
          ),
        ],
        if (webProfiles.isNotEmpty) ...[
          const SizedBox(height: 16),
          UserWebProfiles(profiles: webProfiles, align: align),
        ],
        const SizedBox(height: 20),
        _actions(context, align),
      ],
    );
  }

  Widget _chips(BuildContext context, WrapAlignment align) {
    final u = user;
    final country = [u?.city, u?.countryCode].where((s) => s != null && s.isNotEmpty).join(', ');
    final memberSince = _memberSince(u?.createdAt);
    final plan = u?.plan;
    return Wrap(
      alignment: align,
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (u?.verified ?? false) const VerifiedBadge(),
        if (plan != null && plan.isNotEmpty && plan != 'Free') ProChip(plan: plan),
        if (memberSince != null) InfoChip(icon: Icons.calendar_today_rounded, label: memberSince),
        if (country.isNotEmpty) InfoChip(icon: LucideIcons.globe, label: country),
        if (isOwnProfile) const InfoChip(icon: LucideIcons.sparkles, label: 'PUBLIC'),
      ],
    );
  }

  Widget _username(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 768;
    final style = TextStyle(
      fontSize: wide ? 72 : 48,
      fontWeight: FontWeight.w900,
      height: 0.85,
      letterSpacing: -2,
      color: Colors.white,
    );
    final text = Text(
      username,
      textAlign: MediaQuery.sizeOf(context).width >= 1024 ? TextAlign.left : TextAlign.center,
      style: style,
    );
    if (!hasStar) {
      return DefaultTextStyle.merge(
        style: const TextStyle(shadows: [Shadow(color: Color(0x80000000), blurRadius: 24, offset: Offset(0, 8))]),
        child: text,
      );
    }
    // Star: клип имени в name-gradient ауры.
    return ShaderMask(
      shaderCallback: (rect) => aura.nameGradient.createShader(rect),
      blendMode: BlendMode.srcIn,
      child: text,
    );
  }

  Widget _actions(BuildContext context, WrapAlignment align) {
    final u = user;
    return Wrap(
      alignment: align,
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (!isOwnProfile) UserFollowButton(urn: urn, aura: aura),
        if (u?.permalinkUrl != null) _CopyLink(url: u!.permalinkUrl!),
      ],
    );
  }
}

/// «Участник с» (легаси `dateFormattedLong`): SC шлёт `2020/01/15 ... +0000` —
/// нормализуем к ISO, отбрасываем мусор (NaN / эпоху ≤1970), рендерим «месяц год».
String? _memberSince(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final iso = raw.replaceAll('/', '-').replaceFirst(' +0000', 'Z');
  final d = DateTime.tryParse(iso);
  if (d == null || d.year <= 1970) return null;
  return '${_months[d.month - 1]} ${d.year}';
}

const _months = [
  'январь', 'февраль', 'март', 'апрель', 'май', 'июнь',
  'июль', 'август', 'сентябрь', 'октябрь', 'ноябрь', 'декабрь',
];

/// Кнопка копирования permalink (легаси `CopyLinkButton`): Link→Check, emerald.
class _CopyLink extends StatefulWidget {
  final String url;

  const _CopyLink({required this.url});

  @override
  State<_CopyLink> createState() => _CopyLinkState();
}

class _CopyLinkState extends State<_CopyLink> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.url));
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _copy,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _copied ? const Color(0x1A10B981) : const Color(0x0AFFFFFF),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: _copied ? const Color(0x3310B981) : const Color(0x14FFFFFF),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _copied ? LucideIcons.check : LucideIcons.link,
                size: 15,
                color: _copied ? const Color(0xFF34D399) : const Color(0x80FFFFFF),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Орбы статистики (followers/following/tracks/likes) с убывающей альфой ауры.
class _StatOrbs extends StatelessWidget {
  final UserDto? user;
  final UserAura aura;

  const _StatOrbs({required this.user, required this.aura});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1280;
    final u = user;
    final orbs = [
      UserStatOrb(value: u?.followersCount?.toInt(), label: 'Followers', accent: aura.rgba(0.20)),
      UserStatOrb(value: u?.followingsCount?.toInt(), label: 'Following', accent: aura.rgba(0.16)),
      UserStatOrb(value: u?.trackCount?.toInt(), label: 'Tracks', accent: aura.rgba(0.14)),
      UserStatOrb(value: u?.publicFavoritesCount?.toInt(), label: 'Likes', accent: aura.rgba(0.12)),
    ];
    if (wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < orbs.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            orbs[i],
          ],
        ],
      );
    }
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: orbs,
    );
  }
}
