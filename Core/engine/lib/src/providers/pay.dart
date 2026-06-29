import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../rust/data_pay.dart';
import '../rust/dto_pay.dart';
import 'auth.dart';
import 'library.dart';

/// Тарифы подписки (`pay_plans`). Публичный список — autoDispose, переезжает в
/// кэш только пока открыт STAR.
final payPlansProvider = FutureProvider.autoDispose<List<PlanDto>>((ref) {
  return payPlans();
});

/// Состояние подписки текущего пользователя (`pay_subscription`): премиум-флаг,
/// дедлайн и энтайтлменты по источникам.
final paySubscriptionProvider = FutureProvider.autoDispose<SubscriptionDto>(
  (ref) => paySubscription(),
);

/// Заказы пользователя (`pay_orders`) — история покупок.
final payOrdersProvider = FutureProvider.autoDispose<List<OrderDto>>((ref) {
  return payOrders();
});

/// Фаза чекаута, которую рендерит STAR-флоу.
enum CheckoutPhase { idle, creating, awaiting, paid, failed }

/// Состояние чекаута. [checkout] хранит созданный заказ (pay_url/sbpQr/payTargets
/// для отрисовки), [error] заполнен только в [CheckoutPhase.failed].
class CheckoutState {
  final CheckoutPhase phase;
  final CheckoutDto? checkout;
  final String? error;

  const CheckoutState({
    this.phase = CheckoutPhase.idle,
    this.checkout,
    this.error,
  });

  static const idle = CheckoutState();

  CheckoutState copyWith({
    CheckoutPhase? phase,
    CheckoutDto? checkout,
    String? error,
  }) {
    return CheckoutState(
      phase: phase ?? this.phase,
      checkout: checkout ?? this.checkout,
      error: error,
    );
  }
}

const _pollInterval = Duration(milliseconds: 2500);

/// Контроллер чекаута. [start] создаёт заказ (`pay_checkout`), при наличии
/// [CheckoutDto.payUrl] открывает его внешним браузером и параллельно держит
/// sbpQr/payTargets для отрисовки QR, затем опрашивает `pay_order` до `paid`
/// (→ обновляет auth/подписку) либо `failed`/`expired`. [cancel]/dispose глушат
/// опрос.
final checkoutControllerProvider =
    NotifierProvider.autoDispose<CheckoutController, CheckoutState>(
  CheckoutController.new,
);

class CheckoutController extends Notifier<CheckoutState> {
  Timer? _poll;

  @override
  CheckoutState build() {
    ref.onDispose(_stopPolling);
    return CheckoutState.idle;
  }

  /// Создать заказ и начать опрос статуса. [method] актуален для platega
  /// (по умолчанию `sbp`); [recurring] — автопродление.
  Future<void> start({
    required String planId,
    required String provider,
    String? method,
    bool? recurring,
  }) async {
    _stopPolling();
    state = const CheckoutState(phase: CheckoutPhase.creating);
    final CheckoutDto checkout;
    try {
      checkout = await payCheckout(
        planId: planId,
        provider: provider,
        method: method,
        recurring: recurring,
      );
    } catch (e) {
      state = CheckoutState(phase: CheckoutPhase.failed, error: e.toString());
      return;
    }

    state = CheckoutState(phase: CheckoutPhase.awaiting, checkout: checkout);
    await _openExternal(checkout.payUrl);
    _startPolling(checkout.orderId);
  }

  /// Остановить опрос и сбросить состояние (закрытие листа оплаты).
  void cancel() {
    _stopPolling();
    state = CheckoutState.idle;
  }

  Future<void> _openExternal(String? payUrl) async {
    if (payUrl == null || payUrl.isEmpty) return;
    final uri = Uri.tryParse(payUrl);
    if (uri == null) return;
    // Падение запуска браузера не валит флоу: QR/таргеты остаются на экране.
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _startPolling(String orderId) {
    _poll = Timer.periodic(_pollInterval, (_) => _tick(orderId));
  }

  Future<void> _tick(String orderId) async {
    final OrderDto? order;
    try {
      order = await payOrder(id: orderId);
    } catch (_) {
      // Сетевые икоты не валят флоу: ждём следующий тик.
      return;
    }
    if (order == null) return;
    switch (order.status) {
      case 'paid':
        await _onPaid();
      case 'failed':
      case 'expired':
        _stopPolling();
        state = state.copyWith(phase: CheckoutPhase.failed, error: order.status);
    }
  }

  Future<void> _onPaid() async {
    _stopPolling();
    await _refreshEntitlements();
    state = state.copyWith(phase: CheckoutPhase.paid);
  }

  Future<void> _refreshEntitlements() async {
    await ref.read(authProvider.notifier).refresh();
    ref.invalidate(paySubscriptionProvider);
    ref.invalidate(meSubscriptionProvider);
    ref.invalidate(payOrdersProvider);
  }

  void _stopPolling() {
    _poll?.cancel();
    _poll = null;
  }
}

/// Активировать промокод (`pay_redeem`) и перечитать auth/подписку.
final redeemControllerProvider = Provider.autoDispose<RedeemController>(
  RedeemController.new,
);

class RedeemController {
  RedeemController(this._ref);

  final Ref _ref;

  /// Погасить код; возвращает выданный план/срок для подтверждения на экране.
  Future<RedeemDto> redeem(String code) async {
    final result = await payRedeem(code: code.trim());
    await _refresh();
    return result;
  }

  /// Отменить автопродление по источнику (`pay_cancel`) и перечитать подписку.
  Future<void> cancelSubscription(String source) async {
    await payCancel(source: source);
    await _refresh();
  }

  Future<void> _refresh() async {
    await _ref.read(authProvider.notifier).refresh();
    _ref.invalidate(paySubscriptionProvider);
    _ref.invalidate(meSubscriptionProvider);
    _ref.invalidate(payOrdersProvider);
  }
}
