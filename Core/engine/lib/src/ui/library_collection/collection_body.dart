import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

/// Состояния тела раздела поверх постранично-подгружаемого провайдера: единые
/// loading / error / empty + хвостовой триггер догрузки. Тело строится как набор
/// сливеров внутри страничного `CustomScrollView` (страница — единственный
/// скролл-контейнер, §2.1): никаких вложенных скроллов.
///
/// [content] — сливеры с самим списком/сеткой (через `VirtualList.sliver()` /
/// `VirtualGrid.sliver()`). [hasItems] решает, показывать ли [content] или
/// плашку пустоты. [filtered] меняет текст пустоты на «ничего не найдено».
List<Widget> collectionBodySlivers({
  required AsyncValue<Object?> state,
  required bool hasItems,
  required bool filtered,
  required bool hasMore,
  required bool loadingMore,
  required String emptyMessage,
  required String noMatchesMessage,
  required Future<void> Function() onLoadMore,
  required List<Widget> Function() content,
}) {
  return state.when(
    loading: () => const [
      SliverToBoxAdapter(child: _Spinner(size: 32)),
    ],
    error: (e, _) => [
      SliverToBoxAdapter(child: _ErrorPlaque(message: '$e', onRetry: onLoadMore)),
    ],
    data: (_) {
      if (!hasItems) {
        return [
          SliverToBoxAdapter(
            child: _MessagePlaque(
              message: filtered ? noMatchesMessage : emptyMessage,
            ),
          ),
        ];
      }
      return [
        ...content(),
        SliverToBoxAdapter(
          child: CollectionTail(
            hasMore: !filtered && hasMore,
            loadingMore: loadingMore,
            onLoadMore: onLoadMore,
          ),
        ),
      ];
    },
  );
}

/// Хвост коллекции: пока [hasMore] и не идёт догрузка — триггерит [onLoadMore],
/// когда хвост входит в кэш-зону страничного скролла (легаси `InfiniteSentinel`
/// rootMargin 600px). Высота 48px (легаси `h-12`).
class CollectionTail extends StatefulWidget {
  final bool hasMore;
  final bool loadingMore;
  final Future<void> Function() onLoadMore;

  const CollectionTail({
    super.key,
    required this.hasMore,
    required this.loadingMore,
    required this.onLoadMore,
  });

  @override
  State<CollectionTail> createState() => _CollectionTailState();
}

class _CollectionTailState extends State<CollectionTail> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeFire();
  }

  @override
  void didUpdateWidget(CollectionTail old) {
    super.didUpdateWidget(old);
    _maybeFire();
  }

  void _maybeFire() {
    if (widget.hasMore && !widget.loadingMore) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.hasMore && !widget.loadingMore) {
          widget.onLoadMore();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: _Spinner.inline(size: 20),
      );
    }
    return const SizedBox(height: 48);
  }
}

class _Spinner extends StatelessWidget {
  final double size;
  final bool inline;

  const _Spinner({required this.size}) : inline = false;
  const _Spinner.inline({required this.size}) : inline = true;

  @override
  Widget build(BuildContext context) {
    final spinner = SizedBox(
      width: size,
      height: size,
      child: const CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation(Color(0x33FFFFFF)),
      ),
    );
    if (inline) return Center(child: spinner);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Center(child: spinner),
    );
  }
}

class _MessagePlaque extends StatelessWidget {
  final String message;

  const _MessagePlaque({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0x33FFFFFF), fontSize: 14), // white/20
        ),
      ),
    );
  }
}

class _ErrorPlaque extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorPlaque({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.circleAlert, size: 28, color: Color(0x40FFFFFF)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: ScTokens.textTertiary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: onRetry,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(
                    color: const Color(0x0AFFFFFF),
                    borderRadius: BorderRadius.circular(ScTokens.rButton),
                    border: Border.all(color: const Color(0x14FFFFFF)),
                  ),
                  child: const Text(
                    'Повторить',
                    style: TextStyle(color: ScTokens.textSecondary, fontSize: 13),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
