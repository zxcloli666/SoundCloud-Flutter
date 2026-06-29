import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers.dart' show authProvider, offlineBypassProvider, sessionProvider;
import '../rust/data.dart';
import '../rust/dto.dart';
import 'login/auth_primary_button.dart';
import 'login/brand_mark.dart';
import 'login/offline_entry_card.dart';
import 'login/qr_link_sheet.dart';

/// Экран входа (легаси `Login`, §3.12): атмосфера-аура за центральной стеклянной
/// карточкой `max-w-[400px]`. Геро-BrandMark, затем состояние-машина:
/// idle (CTA входа + OR + офлайн), busy (спиннер + шаг), error (красная карточка
/// + повтор + офлайн).
///
/// Вход — браузерный OAuth (как легаси `use-oauth-flow`): `auth_start_login`
/// открывает ссылку SoundCloud в системном браузере, дальше поллинг
/// `auth_poll_login`; на `completed` токен сессии уходит в ядро через
/// `sessionProvider.set`, и [authProvider] перечитывается — гейт открывает
/// приложение. Бэкенд недоступен > 15с → ошибка.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

enum _Phase { idle, busy, error }

const _pollInterval = Duration(milliseconds: 700);
const _unreachableAfterMs = 15000;

class _LoginPageState extends ConsumerState<LoginPage> {
  _Phase _phase = _Phase.idle;
  String _stepLabel = '';
  String _errorTitle = '';
  String _errorDesc = '';

  Future<void> _signIn() async {
    setState(() {
      _phase = _Phase.busy;
      _stepLabel = _stepText(null);
    });
    final LoginStartDto start;
    try {
      start = await authStartLogin();
      await launchUrl(Uri.parse(start.url), mode: LaunchMode.externalApplication);
    } catch (e) {
      _fail('Сервер недоступен', e.toString());
      return;
    }
    await _poll(start.loginRequestId);
  }

  /// Опрашиваем статус входа до завершения. Транзиентные сбои сети терпим до
  /// [_unreachableAfterMs], затем — ошибка.
  Future<void> _poll(String loginRequestId) async {
    int? failingSinceMs;
    while (mounted && _phase == _Phase.busy) {
      await Future<void>.delayed(_pollInterval);
      if (!mounted || _phase != _Phase.busy) return;

      final LoginStatusDto status;
      try {
        status = await authPollLogin(loginRequestId: loginRequestId);
        failingSinceMs = null;
      } catch (_) {
        final now = DateTime.now().millisecondsSinceEpoch;
        failingSinceMs ??= now;
        if (now - failingSinceMs >= _unreachableAfterMs) {
          _fail('Сервер недоступен', 'Бэкенд не отвечает');
          return;
        }
        continue;
      }
      if (!mounted) return;

      if (status.step != null) {
        setState(() => _stepLabel = _stepText(status.step));
      }
      switch (status.status) {
        case 'completed':
          final sessionId = status.sessionId;
          if (sessionId != null) {
            await _succeed(sessionId);
            return;
          }
        case 'failed':
        case 'expired':
          _fail(
            status.status == 'expired' ? 'Сессия истекла' : 'Не удалось войти',
            status.error ?? '',
          );
          return;
      }
    }
  }

  Future<void> _succeed(String sessionId) async {
    setState(() => _stepLabel = _stepText('session'));
    await ref.read(sessionProvider.notifier).set(sessionId);
    if (!mounted) return;
    // Гейт следит за authProvider — после refresh он откроет приложение, а этот
    // экран размонтируется.
    await ref.read(authProvider.notifier).refresh();
  }

  void _fail(String title, String desc) {
    if (!mounted) return;
    setState(() {
      _phase = _Phase.error;
      _errorTitle = title;
      _errorDesc = desc;
    });
  }

  String _stepText(String? step) => switch (step) {
    'token' => 'Получаем токен…',
    'profile' => 'Загружаем профиль…',
    'session' => 'Открываем сессию…',
    _ => 'Ожидаем подтверждения…',
  };

  void _enterOffline() {
    ref.read(offlineBypassProvider.notifier).enter();
  }

  void _scanQr() {
    showQrLinkSheet(context);
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = _phase == _Phase.busy ? 'Входим…' : 'Звук, который тебя ведёт';
    return Atmosphere(
      energy: 0.5,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _AuthCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BrandMark(subtitle: subtitle),
                  const SizedBox(height: 32),
                  _body(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    return switch (_phase) {
      _Phase.error => _ErrorState(
          title: _errorTitle,
          desc: _errorDesc,
          onRetry: () => setState(() => _phase = _Phase.idle),
          onOffline: _enterOffline,
        ),
      _Phase.busy => _BusyState(label: _stepLabel),
      _Phase.idle => _IdleState(
          onSignIn: _signIn,
          onScanQr: _scanQr,
          onOffline: _enterOffline,
        ),
    };
  }
}

/// Стеклянная карточка входа: `rounded-[2.25rem] px-8 pt-9 pb-7`, тонкий бордер,
/// акцентное свечение тенью, верхний specular-волосок.
class _AuthCard extends StatelessWidget {
  final Widget child;

  const _AuthCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final accentGlow = ScTheme.paletteOf(context).accentGlow;
    final radius = BorderRadius.circular(36);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: const Color(0x1AFFFFFF), width: 0.5),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x0FFFFFFF), Color(0x05FFFFFF), Color(0x09FFFFFF)],
          stops: [0.0, 0.6, 1.0],
        ),
        boxShadow: [
          const BoxShadow(color: Color(0x8C000000), blurRadius: 100, offset: Offset(0, 40)),
          BoxShadow(color: accentGlow, blurRadius: 80),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            const Positioned(top: 0, left: 32, right: 32, child: SpecularHairline.subtle()),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 36, 32, 28),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

/// Состояние покоя: CTA входа + перенос сессии + OR-разделитель + офлайн.
class _IdleState extends StatelessWidget {
  final VoidCallback onSignIn;
  final VoidCallback onScanQr;
  final VoidCallback onOffline;

  const _IdleState({
    required this.onSignIn,
    required this.onScanQr,
    required this.onOffline,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AuthPrimaryButton(
          onPressed: onSignIn,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Войти'),
              SizedBox(width: 8),
              Icon(LucideIcons.chevronRight, size: 16),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _ScanQrButton(onTap: onScanQr),
        const SizedBox(height: 8),
        const _OrSeparator(),
        const SizedBox(height: 4),
        OfflineEntryCard(onTap: onOffline),
      ],
    );
  }
}

/// Призрак-кнопка «Сканировать QR» (легаси `qrLink.scanQr`): без фона, на hover
/// светлеет текст и проступает тонкий тинт. Открывает [QrLinkSheet].
class _ScanQrButton extends StatefulWidget {
  final VoidCallback onTap;

  const _ScanQrButton({required this.onTap});

  @override
  State<_ScanQrButton> createState() => _ScanQrButtonState();
}

class _ScanQrButtonState extends State<_ScanQrButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final fg = _hover ? const Color(0xCCFFFFFF) : const Color(0x73FFFFFF);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: ScTokens.dFast,
          curve: ScTokens.easeApple,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: _hover ? const Color(0x0AFFFFFF) : Colors.transparent,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.smartphone, size: 14, color: fg),
              const SizedBox(width: 8),
              Text(
                'Сканировать QR',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// «ИЛИ»-разделитель: волосок → текст → волосок.
class _OrSeparator extends StatelessWidget {
  const _OrSeparator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Color(0x00FFFFFF), Color(0x1AFFFFFF)]),
              ),
              child: SizedBox(height: 1),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'ИЛИ',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 2.2,
                fontWeight: FontWeight.w600,
                color: Color(0x40FFFFFF),
              ),
            ),
          ),
          const Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Color(0x1AFFFFFF), Color(0x00FFFFFF)]),
              ),
              child: SizedBox(height: 1),
            ),
          ),
        ],
      ),
    );
  }
}

/// Состояние входа: спиннер с accent-дугой + лейбл шага.
class _BusyState extends StatelessWidget {
  final String label;

  const _BusyState({required this.label});

  @override
  Widget build(BuildContext context) {
    final accent = ScTheme.paletteOf(context).accent;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(accent),
              backgroundColor: const Color(0x14FFFFFF),
            ),
          ),
          const SizedBox(height: 16),
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0x73FFFFFF))),
        ],
      ),
    );
  }
}

/// Состояние ошибки: красная плитка-карточка + повтор + офлайн.
class _ErrorState extends StatelessWidget {
  final String title;
  final String desc;
  final VoidCallback onRetry;
  final VoidCallback onOffline;

  const _ErrorState({
    required this.title,
    required this.desc,
    required this.onRetry,
    required this.onOffline,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x33EF4444)),
            color: const Color(0x0FEF4444),
          ),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0x40EF4444)),
                  color: const Color(0x1AEF4444),
                ),
                child: const Icon(LucideIcons.circleAlert, size: 20, color: Color(0xFFF87171)),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xE6FFFFFF)),
              ),
              if (desc.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  desc,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, height: 1.35, color: Color(0x73FFFFFF)),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        AuthPrimaryButton(
          onPressed: onRetry,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.rotateCw, size: 15),
              SizedBox(width: 8),
              Text('Повторить'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        OfflineEntryCard(onTap: onOffline),
      ],
    );
  }
}
