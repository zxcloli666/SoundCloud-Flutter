import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../rust/data.dart';

/// Гейт входа: приложением можно пользоваться ТОЛЬКО после реального входа.
/// `authenticated` — бэк подтвердил сессию (`/auth/status`); это единственный
/// ключ в приложение. `hasSession` (локальный токен есть) сам по себе НЕ пускает:
/// протухший/невалидный токен даёт `authenticated:false` → экран входа.
class AuthState {
  final bool hasSession;
  final bool authenticated;
  final String? username;

  const AuthState({
    required this.hasSession,
    required this.authenticated,
    this.username,
  });

  /// В основное приложение — только при подтверждённой бэком сессии. Никаких
  /// анонимных/полу-залогиненных состояний (это инвариант, не фоллбэк).
  bool get canUseMainShell => authenticated;

  static const none = AuthState(hasSession: false, authenticated: false);
}

/// Статус сессии. Бутстрап читает локальный токен (+ подтверждение бэка); после
/// входа/выхода — [AuthNotifier.refresh].
final authProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

class AuthNotifier extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() => _read();

  Future<AuthState> _read() async {
    final status = await authStatus();
    return AuthState(
      hasSession: status.hasSession,
      authenticated: status.authenticated,
      username: status.username,
    );
  }

  /// Перечитать статус после входа (ядро уже получило токен через sessionProvider).
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_read);
  }

  /// Выход: ядро чистит локальную сессию (до сети), затем гейт падает на вход.
  Future<void> logout() async {
    await authLogout();
    state = const AsyncValue.data(AuthState.none);
  }
}

/// Явный выбор «смотреть офлайн» без входа — НЕ фоллбэк разлогина. Возврат из
/// него ([exit]) ведёт обратно на экран входа.
final offlineBypassProvider = NotifierProvider<OfflineBypassNotifier, bool>(
  OfflineBypassNotifier.new,
);

class OfflineBypassNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void enter() => state = true;
  void exit() => state = false;
}
