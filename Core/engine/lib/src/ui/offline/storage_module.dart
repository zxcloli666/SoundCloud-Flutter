import 'package:flutter/material.dart';
import 'package:sc_visual/sc_visual.dart';

import 'offline_model.dart';
import 'storage_bar.dart';
import 'storage_cache_cta.dart';

/// Снимок объёма хранилища для StorageModule.
class StorageStats {
  final int totalBytes;
  final int likedBytes;
  final int cachedCount;
  final int likedCount;
  final int likedCachedCount;
  final int? limitBytes;

  const StorageStats({
    this.totalBytes = 0,
    this.likedBytes = 0,
    this.cachedCount = 0,
    this.likedCount = 0,
    this.likedCachedCount = 0,
    this.limitBytes,
  });
}

/// Прогресс bulk-докачки лайков.
class CacheLikesProgress {
  final int done;
  final int total;
  final int failed;

  const CacheLikesProgress({this.done = 0, this.total = 0, this.failed = 0});
}

/// Правый модуль hero-деки: объём хранилища с защищённой квотой лайков +
/// покрытие лайков и CTA «скачать все лайки».
class StorageModule extends StatelessWidget {
  final StorageStats stats;
  final bool caching;
  final CacheLikesProgress? progress;
  final VoidCallback onStartLikes;
  final VoidCallback onCancelLikes;

  const StorageModule({
    super.key,
    required this.stats,
    required this.caching,
    required this.onStartLikes,
    required this.onCancelLikes,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final limit = stats.limitBytes;
    final cacheBytes = (stats.totalBytes - stats.likedBytes).clamp(0, 1 << 62);
    final freeBytes =
        limit != null ? (limit - stats.totalBytes).clamp(0, 1 << 62) : null;
    final coverage =
        stats.likedCount > 0 ? stats.likedCachedCount / stats.likedCount : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'ХРАНИЛИЩЕ',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                    color: Color(0x59FFFFFF),
                  ),
                ),
              ),
              Text(
                'файлов: ${stats.cachedCount}',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: Color(0x4DFFFFFF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                formatBytes(stats.totalBytes),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.6,
                  height: 1,
                  color: Color(0xEBFFFFFF),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                limit != null ? 'из ${formatBytes(limit)}' : 'без лимита',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Color(0x66FFFFFF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StorageBar(
            likedBytes: stats.likedBytes,
            cacheBytes: cacheBytes,
            denomBytes: (limit ?? stats.totalBytes),
          ),
          const SizedBox(height: 10),
          _legend(stats.likedBytes, cacheBytes, freeBytes),
          if (stats.likedCount > 0) ...[
            const Spacer(),
            const SizedBox(height: 14),
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0x0FFFFFFF))),
              ),
              padding: const EdgeInsets.only(top: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _coverageHeader(stats),
                  const SizedBox(height: 8),
                  _coverageBar(context, coverage),
                  const SizedBox(height: 12),
                  CacheLikesCta(
                    caching: caching,
                    progress: progress,
                    remaining:
                        (stats.likedCount - stats.likedCachedCount).clamp(0, 1 << 30),
                    onStart: onStartLikes,
                    onCancel: onCancelLikes,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _legend(int liked, int cache, int? free) {
    return Wrap(
      spacing: 16,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.lock, size: 9, color: Color(0x59FFFFFF)),
            const SizedBox(width: 6),
            _legendText('лайки ${formatBytes(liked)}'),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: const Color(0x4DFFFFFF),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 6),
            _legendText('кэш ${formatBytes(cache)}'),
          ],
        ),
        if (free != null) _legendText('свободно ${formatBytes(free)}'),
      ],
    );
  }

  Widget _legendText(String s) => Text(
        s,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 10.5,
          height: 1.4,
          color: Color(0x73FFFFFF),
        ),
      );

  Widget _coverageHeader(StorageStats s) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        const Expanded(
          child: Text(
            'покрытие лайков',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: Color(0x8CFFFFFF),
            ),
          ),
        ),
        Text.rich(
          TextSpan(
            text: '${s.likedCachedCount} ',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xE6FFFFFF),
            ),
            children: [
              TextSpan(
                text: 'из ${s.likedCount}',
                style: const TextStyle(
                    fontWeight: FontWeight.w400, color: Color(0x59FFFFFF)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _coverageBar(BuildContext context, double coverage) {
    final palette = ScTheme.paletteOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: Container(
        height: 3,
        color: const Color(0x12FFFFFF),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: coverage.clamp(0, 1),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [palette.accentGlow, palette.accent],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
