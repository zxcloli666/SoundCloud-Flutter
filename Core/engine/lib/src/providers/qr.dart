import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../rust/data.dart';
import '../rust/dto.dart';
import 'auth.dart';
import 'core.dart';

/// Фаза QR-переноса сессии, которую рендерит лист.
enum QrPhase { idle, waiting, claimed, error }

/// Состояние QR-линка для отрисовки. `payload` — строка `scd://link?...` под QR;
/// `linkRequestId` — для опроса; `error` заполнен только в [QrPhase.error].
class QrLinkState {
  final QrPhase phase;
  final String mode;
  final String? payload;
  final String? linkRequestId;
  final String? error;

  const QrLinkState({
    this.phase = QrPhase.idle,
    this.mode = 'pull',
    this.payload,
    this.linkRequestId,
    this.error,
  });

  static const idle = QrLinkState();

  QrLinkState copyWith({
    QrPhase? phase,
    String? mode,
    String? payload,
    String? linkRequestId,
    String? error,
  }) {
    return QrLinkState(
      phase: phase ?? this.phase,
      mode: mode ?? this.mode,
      payload: payload ?? this.payload,
      linkRequestId: linkRequestId ?? this.linkRequestId,
      error: error,
    );
  }
}

const _pollInterval = Duration(milliseconds: 2000);

/// Контроллер QR-переноса сессии. [start] создаёт линк и поднимает QR, затем
/// опрашивает статус; на `claimed` с sessionId — прокидывает токен в ядро и
/// перечитывает auth. Опрос живёт пока виден лист; [cancel]/dispose его глушат.
final qrLinkControllerProvider =
    NotifierProvider.autoDispose<QrLinkController, QrLinkState>(
  QrLinkController.new,
);

class QrLinkController extends Notifier<QrLinkState> {
  Timer? _poll;

  @override
  QrLinkState build() {
    ref.onDispose(_stopPolling);
    return QrLinkState.idle;
  }

  /// Создать линк (`mode` — `'pull'` или `'push'`) и начать опрос статуса.
  Future<void> start({String mode = 'pull'}) async {
    _stopPolling();
    state = QrLinkState(phase: QrPhase.waiting, mode: mode);
    try {
      final created = await authLinkCreate(mode: mode);
      state = state.copyWith(
        phase: QrPhase.waiting,
        mode: created.mode,
        payload: created.payload,
        linkRequestId: created.linkRequestId,
      );
      _startPolling(created.linkRequestId);
    } catch (e) {
      state = state.copyWith(phase: QrPhase.error, error: e.toString());
    }
  }

  /// Остановить опрос и сбросить состояние (закрытие листа без входа).
  void cancel() {
    _stopPolling();
    state = QrLinkState.idle;
  }

  void _startPolling(String linkRequestId) {
    _poll = Timer.periodic(_pollInterval, (_) => _tick(linkRequestId));
  }

  Future<void> _tick(String linkRequestId) async {
    final LinkStatusDto status;
    try {
      status = await authLinkStatus(linkRequestId: linkRequestId);
    } catch (_) {
      // Сетевые икоты не валят флоу: ждём следующий тик.
      return;
    }
    switch (status.status) {
      case 'claimed':
        await _onClaimed(status.sessionId);
      case 'failed':
      case 'expired':
        _stopPolling();
        state = state.copyWith(phase: QrPhase.error, error: status.error ?? status.status);
    }
  }

  Future<void> _onClaimed(String? sessionId) async {
    _stopPolling();
    if (sessionId == null) {
      state = state.copyWith(phase: QrPhase.error, error: 'claimed without session');
      return;
    }
    await ref.read(sessionProvider.notifier).set(sessionId);
    await ref.read(authProvider.notifier).refresh();
    state = state.copyWith(phase: QrPhase.claimed);
  }

  void _stopPolling() {
    _poll?.cancel();
    _poll = null;
  }
}
