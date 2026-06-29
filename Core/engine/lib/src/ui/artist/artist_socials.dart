import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Метаданные соц-сети (легаси `components/artist/socials.tsx`). Бренд-глифы
/// simple-icons во Flutter не бандлим — берём представительную Material-иконку
/// с фолбэком globe/link. Лейбл повторяет легаси-капитализацию.
class SocialMeta {
  final IconData icon;
  final String label;

  const SocialMeta({required this.icon, required this.label});
}

const _networks = <String, IconData>{
  'instagram': Icons.camera_alt_rounded,
  'twitter': Icons.alternate_email_rounded,
  'x': Icons.alternate_email_rounded,
  'youtube': Icons.smart_display_rounded,
  'soundcloud': LucideIcons.cloud,
  'spotify': LucideIcons.audioLines,
  'apple_music': LucideIcons.music,
  'bandcamp': LucideIcons.disc3,
  'tiktok': Icons.music_video_rounded,
  'discogs': LucideIcons.disc3,
  'lastfm': LucideIcons.radio,
  'genius': LucideIcons.micVocal,
  'musicbrainz': LucideIcons.libraryBig,
  'facebook': Icons.facebook_rounded,
  'wikipedia': Icons.menu_book_rounded,
  'personal': LucideIcons.globe,
};

SocialMeta socialMeta(String kind) {
  final k = kind.toLowerCase();
  return SocialMeta(icon: _networks[k] ?? LucideIcons.link, label: socialLabel(k));
}

String socialLabel(String kind) {
  final k = kind.toLowerCase();
  if (k == 'apple_music') return 'Apple Music';
  if (k == 'lastfm') return 'Last.fm';
  if (k == 'twitter' || k == 'x') return 'Twitter';
  if (k == 'musicbrainz') return 'MusicBrainz';
  if (k.isEmpty) return 'Link';
  return k[0].toUpperCase() + k.substring(1);
}
