import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../providers/qr.dart';

/// QR-перенос сессии (легаси `QrLinkSheet`, §3.12): стеклянный диалог со
/// Smartphone-тайлом, заголовком/подзаголовком под режим и QR-артефактом.
///
/// `mode`:
///  - `'pull'` — войти на ЭТОМ устройстве, сканируя код с уже залогиненного;
///  - `'push'` — отдать ТЕКУЩУЮ сессию другому устройству («Передать сессию»).
///
/// Контроллер ([qrLinkControllerProvider]) создаёт линк на маунте и опрашивает
/// статус; на `claimed` показывает успех, на ошибке — повтор. Закрытие листа
/// глушит опрос через [QrLinkController.cancel].
Future<void> showQrLinkSheet(BuildContext context, {required String mode}) {
  // Диалог уходит в root-navigator (выше вложенного ProviderScope движка), иначе
  // Consumer-лист не находит провайдеры → «No ProviderScope found». Пере-вносим
  // тот же контейнер в поддерево диалога.
  final container = ProviderScope.containerOf(context);
  return showScModal(
    context: context,
    builder: (_) => UncontrolledProviderScope(
      container: container,
      child: _QrLinkSheet(mode: mode),
    ),
  );
}

class _QrLinkSheet extends ConsumerStatefulWidget {
  final String mode;

  const _QrLinkSheet({required this.mode});

  @override
  ConsumerState<_QrLinkSheet> createState() => _QrLinkSheetState();
}

class _QrLinkSheetState extends ConsumerState<_QrLinkSheet> {
  @override
  void initState() {
    super.initState();
    // Поднять линк после первого кадра: контроллер autoDispose, маунт листа —
    // его жизненный цикл.
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  void _start() => ref.read(qrLinkControllerProvider.notifier).start(mode: widget.mode);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(qrLinkControllerProvider);
    final isPush = widget.mode == 'push';
    return ScModal(
      size: ScModalSize.sm,
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 28),
      onClose: () {
        ref.read(qrLinkControllerProvider.notifier).cancel();
        Navigator.of(context).maybePop();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _header(isPush),
          const SizedBox(height: 20),
          _body(state),
        ],
      ),
    );
  }

  Widget _header(bool isPush) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AccentIconTileNeutral(),
        const SizedBox(height: 12),
        Text(
          isPush ? 'Добавить устройство' : 'Войти с другого устройства',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xE6FFFFFF),
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Text(
            isPush
                ? 'Открой SoundCloud на телефоне (или другом устройстве) и отсканируй этот код, чтобы войти там.'
                : 'Открой SoundCloud на устройстве, где ты уже вошёл, и отсканируй этот код.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0x66FFFFFF),
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _body(QrLinkState state) {
    return switch (state.phase) {
      QrPhase.idle || QrPhase.waiting when state.payload == null => const _Preparing(),
      QrPhase.waiting => _Pending(payload: state.payload!),
      QrPhase.claimed => _Claimed(push: widget.mode == 'push'),
      QrPhase.error => _Failed(error: state.error, onRetry: _start),
      QrPhase.idle => const _Preparing(),
    };
  }
}

/// Светящийся spinner — линк ещё создаётся.
class _Preparing extends StatelessWidget {
  const _Preparing();

  @override
  Widget build(BuildContext context) {
    final accent = ScTheme.paletteOf(context).accent;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(accent),
              backgroundColor: const Color(0x0FFFFFFF),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Генерируем код…',
            style: TextStyle(fontSize: 11.5, color: Color(0x4DFFFFFF)),
          ),
        ],
      ),
    );
  }
}

/// QR готов к сканированию.
class _Pending extends StatelessWidget {
  final String payload;

  const _Pending({required this.payload});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ScQrCode(data: payload, size: 240),
        const SizedBox(height: 16),
        const Text(
          'Отсканируй камерой устройства',
          style: TextStyle(fontSize: 11, color: Color(0x59FFFFFF)),
        ),
      ],
    );
  }
}

/// Линк заклеймлен — устройство залогинено.
class _Claimed extends StatelessWidget {
  final bool push;

  const _Claimed({required this.push});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0x3334C759), Color(0x0D34C759)],
              ),
              border: Border.all(color: const Color(0x4D34C759), width: 0.5),
            ),
            child: const Icon(LucideIcons.check, size: 24, color: Color(0xFF4ADE80)),
          ),
          const SizedBox(height: 12),
          Text(
            push ? 'Другое устройство залогинено.' : 'Ты вошёл.',
            style: const TextStyle(fontSize: 13, color: Color(0xB3FFFFFF)),
          ),
        ],
      ),
    );
  }
}

/// Линк не удался/истёк — кнопка нового кода.
class _Failed extends StatefulWidget {
  final String? error;
  final VoidCallback onRetry;

  const _Failed({required this.error, required this.onRetry});

  @override
  State<_Failed> createState() => _FailedState();
}

class _FailedState extends State<_Failed> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Text(
              widget.error?.isNotEmpty == true ? widget.error! : 'Не удалось.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: Color(0xCCF87171)),
            ),
          ),
          const SizedBox(height: 14),
          MouseRegion(
            onEnter: (_) => setState(() => _hover = true),
            onExit: (_) => setState(() => _hover = false),
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: widget.onRetry,
              child: AnimatedContainer(
                duration: ScTokens.dFast,
                curve: ScTokens.easeApple,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: _hover ? const Color(0x14FFFFFF) : const Color(0x0DFFFFFF),
                  border: Border.all(
                    color: _hover ? const Color(0x1FFFFFFF) : const Color(0x0FFFFFFF),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.rotateCw,
                      size: 13,
                      color: _hover ? const Color(0xD9FFFFFF) : const Color(0x99FFFFFF),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'Сгенерировать новый код',
                      style: TextStyle(
                        fontSize: 12,
                        color: _hover ? const Color(0xD9FFFFFF) : const Color(0x99FFFFFF),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Нейтральный Smartphone-тайл шапки (легаси: стеклянный квадрат 48 без акцента).
class AccentIconTileNeutral extends StatelessWidget {
  const AccentIconTileNeutral({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x0FFFFFFF), Color(0x05FFFFFF)],
        ),
        border: Border.all(color: const Color(0x14FFFFFF), width: 0.5),
      ),
      child: const Icon(LucideIcons.smartphone, size: 20, color: Color(0x99FFFFFF)),
    );
  }
}
