import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../providers.dart' show QrPhase, qrLinkControllerProvider;

/// Лист QR-переноса сессии (легаси `QrLinkSheet`, режим `pull`): стеклянный
/// диалог со смартфон-иконкой, QR-артефактом и спиннером ожидания. На `claimed`
/// контроллер уже выставил сессию и перечитал auth — гейт закроет логин, а лист
/// размонтируется; здесь показываем зелёную галочку как подтверждение.
///
/// Открывать через [showQrLinkSheet]. Опрос живёт пока лист открыт — контроллер
/// глушится в [dispose].
class QrLinkSheet extends ConsumerStatefulWidget {
  const QrLinkSheet({super.key});

  @override
  ConsumerState<QrLinkSheet> createState() => _QrLinkSheetState();
}

class _QrLinkSheetState extends ConsumerState<QrLinkSheet> {
  @override
  void initState() {
    super.initState();
    // Линк создаём после первого кадра — контроллер тогда уже смонтирован.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(qrLinkControllerProvider.notifier).start(mode: 'pull');
    });
  }

  @override
  void dispose() {
    ref.read(qrLinkControllerProvider.notifier).cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(qrLinkControllerProvider);
    return ScModal(
      size: ScModalSize.sm,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _SheetHeader(),
          const SizedBox(height: 20),
          _body(state.phase, state.payload, state.error),
        ],
      ),
    );
  }

  Widget _body(QrPhase phase, String? payload, String? error) {
    return switch (phase) {
      QrPhase.claimed => const _Claimed(),
      QrPhase.error => _Failed(
          message: error,
          onRetry: () => ref.read(qrLinkControllerProvider.notifier).start(mode: 'pull'),
        ),
      _ when payload != null => _Pending(payload: payload),
      _ => const _Preparing(),
    };
  }
}

/// Открывает [QrLinkSheet] поверх логина.
Future<void> showQrLinkSheet(BuildContext context) {
  // Диалог уходит в root-navigator (выше ProviderScope движка) — пере-вносим
  // контейнер, иначе Consumer-лист падает «No ProviderScope found».
  final container = ProviderScope.containerOf(context);
  return showScModal<void>(
    context: context,
    builder: (_) => UncontrolledProviderScope(
      container: container,
      child: const QrLinkSheet(),
    ),
  );
}

/// Шапка: стеклянный смартфон-бейдж + заголовок + подсказка.
class _SheetHeader extends StatelessWidget {
  const _SheetHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x14FFFFFF), width: 0.5),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0x0FFFFFFF), Color(0x05FFFFFF)],
            ),
          ),
          child: const Icon(LucideIcons.smartphone, size: 20, color: Color(0x99FFFFFF)),
        ),
        const SizedBox(height: 12),
        const Text(
          'Войти с телефона',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xE6FFFFFF)),
        ),
        const SizedBox(height: 6),
        const Text(
          'Отсканируй код в приложении на телефоне — сессия перенесётся сюда',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, height: 1.4, color: Color(0x66FFFFFF)),
        ),
      ],
    );
  }
}

/// Готовим линк: спиннер до прихода payload.
class _Preparing extends StatelessWidget {
  const _Preparing();

  @override
  Widget build(BuildContext context) {
    final accent = ScTheme.paletteOf(context).accent;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
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
          const SizedBox(height: 12),
          const Text('Готовим код…', style: TextStyle(fontSize: 11.5, color: Color(0x4DFFFFFF))),
        ],
      ),
    );
  }
}

/// Линк создан: QR-артефакт + строка-подсказка ожидания.
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
          'Ожидаем сканирование…',
          style: TextStyle(fontSize: 11.5, color: Color(0x59FFFFFF)),
        ),
      ],
    );
  }
}

/// Сессия принята: зелёная галочка. Гейт уберёт логин следом.
class _Claimed extends StatelessWidget {
  const _Claimed();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0x4D34C759), width: 0.5),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0x3334C759), Color(0x0D34C759)],
              ),
            ),
            child: const Icon(LucideIcons.check, size: 24, color: Color(0xFF34D399)),
          ),
          const SizedBox(height: 12),
          const Text(
            'Готово! Входим…',
            style: TextStyle(fontSize: 13, color: Color(0xB3FFFFFF)),
          ),
        ],
      ),
    );
  }
}

/// Сбой/истечение линка: текст ошибки + повтор.
class _Failed extends StatelessWidget {
  final String? message;
  final VoidCallback onRetry;

  const _Failed({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message?.isNotEmpty == true ? message! : 'Не удалось создать код',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, height: 1.4, color: Color(0xCCF87171)),
          ),
          const SizedBox(height: 14),
          _RetryButton(onTap: onRetry),
        ],
      ),
    );
  }
}

/// Стеклянная вторичная кнопка повтора (легаси retry-pill).
class _RetryButton extends StatefulWidget {
  final VoidCallback onTap;

  const _RetryButton({required this.onTap});

  @override
  State<_RetryButton> createState() => _RetryButtonState();
}

class _RetryButtonState extends State<_RetryButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: ScTokens.dFast,
          curve: ScTokens.easeApple,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x0FFFFFFF)),
            color: _hover ? const Color(0x14FFFFFF) : const Color(0x0DFFFFFF),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.rotateCw,
                size: 13,
                color: _hover ? const Color(0xD9FFFFFF) : const Color(0x99FFFFFF),
              ),
              const SizedBox(width: 6),
              Text(
                'Повторить',
                style: TextStyle(
                  fontSize: 12,
                  color: _hover ? const Color(0xD9FFFFFF) : const Color(0x99FFFFFF),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
