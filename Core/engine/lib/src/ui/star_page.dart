import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers.dart';
import '../rust/dto_pay.dart';
import 'star/center_readout.dart';
import 'star/console.dart';
import 'star/living_core.dart';
import 'star/panes.dart';
import 'star/pay_manage_pane.dart';
import 'star/star_atmosphere.dart';
import 'star/star_data.dart';

/// STAR PASS — «Живое Ядро» (легаси `pages/StarPage.tsx`, §3.14). Энергия живёт
/// в canvas-ядре; пер-стейт контент едет на парящей стеклянной консоли над ним.
/// Этот файл — чистая оркестрация (стейт-машина + дата-вайринг); каждая панель
/// живёт в `ui/star/*`.
///
/// Дата-слой — реальный `pay`-мост: [payPlansProvider] (каталог),
/// [paySubscriptionProvider] (премиум/дедлайн/энтайтлменты),
/// [checkoutControllerProvider] (создание заказа + поллинг) и
/// [redeemControllerProvider] (код/отмена автопродления).
class StarPage extends ConsumerStatefulWidget {
  const StarPage({super.key});

  @override
  ConsumerState<StarPage> createState() => _StarPageState();
}

class _StarPageState extends ConsumerState<StarPage> {
  StarStep _step = StarStep.overview;
  String? _planId;
  ActivationOption? _option;
  bool _recurring = false;
  int _igniteKey = 0;
  bool _initFromPremium = false;

  StarPlan? _selectedPlan(List<StarPlan> plans) {
    for (final p in plans) {
      if (p.id == _planId) return p;
    }
    return null;
  }

  bool get _lit => _step == StarStep.success || _step == StarStep.manage;

  bool _canRecur(StarPlan? plan) => (_option?.recurring ?? false) && plan?.months == 1;

  // Куда возвращает «назад» в шапке, по шагу (null = нет кнопки) (легаси backTarget).
  StarStep? _backTarget(bool premium) {
    return switch (_step) {
      StarStep.pay => StarStep.method,
      StarStep.method => StarStep.overview,
      StarStep.redeem => premium ? StarStep.manage : StarStep.overview,
      StarStep.overview => premium ? StarStep.manage : null,
      _ => null,
    };
  }

  // charge (размер ядра): lit→1; иначе по месяцам выбранного плана (легаси).
  double _charge(StarPlan? plan) {
    if (_lit) return 1;
    if (plan == null) return 0.5;
    return plan.months >= 12 ? 1 : plan.months >= 3 ? 0.6 : 0.28;
  }

  void _autoPickBest(List<StarPlan> plans) {
    if (_planId != null || plans.isEmpty) return;
    final best = StarPlan.best(plans);
    if (best != null) _planId = best.id;
  }

  void _goMethod() {
    ref.read(checkoutControllerProvider.notifier).cancel();
    setState(() => _step = StarStep.method);
  }

  Future<void> _startCheckout() async {
    final option = _option;
    final planId = _planId;
    if (option == null || planId == null) return;
    final plans = ref.read(payPlansProvider).value?.map(StarPlan.fromDto).toList() ?? const [];
    final plan = _selectedPlan(plans);
    final allowRecurring = option.recurring && plan?.months == 1 && _recurring;
    setState(() => _step = StarStep.pay);
    await ref.read(checkoutControllerProvider.notifier).start(
          planId: planId,
          provider: option.provider,
          method: option.method,
          recurring: allowRecurring,
        );
  }

  Future<void> _openUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(payPlansProvider);
    final subAsync = ref.watch(paySubscriptionProvider);
    final sub = subAsync.value;
    final premium = sub?.premium ?? false;

    final me = ref.watch(meProvider).value;
    // За гейтом юзер реальный; пока профиль грузится — пусто, без фейк-«Гостя».
    final handle = (me?.username != null && me!.username.isNotEmpty)
        ? '@${me.username}'
        : '';

    final plans = plansAsync.value?.map(StarPlan.fromDto).toList() ?? const <StarPlan>[];
    _autoPickBest(plans);
    final selectedPlan = _selectedPlan(plans);

    // Стартовый шаг: премиум → manage. Однократно после первого known-значения.
    if (!_initFromPremium && subAsync.hasValue) {
      _initFromPremium = true;
      _step = premium ? StarStep.manage : StarStep.overview;
    }

    // Реакция чекаута: idle→paid гонит ударную волну + переход в success.
    _listenCheckout();

    final ent = sub != null ? primaryEntitlement(sub.entitlements) : null;
    // Активное окно = энтайтлмент с поздним концом, иначе premium_until.
    final subEndsAt = ent?.endsAt.toInt() ?? sub?.premiumUntil.toInt() ?? 0;

    final checkout = ref.watch(checkoutControllerProvider).checkout;
    final serialSeed = checkout?.orderId ?? handle;
    final backTarget = _backTarget(premium);
    final phase = _payPhase();

    return Stack(
      children: [
        const StarAtmosphere(),
        SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1060),
              child: LayoutBuilder(
                builder: (context, c) {
                  final wide = c.maxWidth >= 768;
                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: wide ? 32 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Header(
                          backTarget: backTarget,
                          onBack: backTarget == null
                              ? null
                              : () => setState(() => _step = backTarget),
                        ),
                        // Core region — ядро центрируется и сжимается с вьюпортом.
                        Expanded(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 240),
                            child: _CoreRegion(
                              charge: _charge(selectedPlan),
                              waiting: _step == StarStep.pay && phase == PayPhase.waiting,
                              lit: _lit,
                              igniteKey: _igniteKey,
                              readout: CenterReadout(
                                step: _step,
                                phase: phase,
                                handle: handle,
                                plan: selectedPlan,
                                endsAt: subEndsAt,
                                serialSeed: serialSeed,
                              ),
                            ),
                          ),
                        ),
                        // Console — в нормальном потоке под ядром, не перекрывает его.
                        Padding(
                          padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 700),
                              child: StarConsole(
                                child: _pane(plansAsync, plans, selectedPlan, sub, subEndsAt, ent),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Текущая [PayPhase] из фазы чекаут-контроллера (легаси `phaseOf`).
  PayPhase _payPhase() {
    return switch (ref.watch(checkoutControllerProvider).phase) {
      CheckoutPhase.paid => PayPhase.granted,
      CheckoutPhase.failed => PayPhase.failed,
      _ => PayPhase.waiting,
    };
  }

  /// Зажигание + переход на success на idle→paid (фаза контроллера).
  void _listenCheckout() {
    ref.listen<CheckoutState>(checkoutControllerProvider, (prev, next) {
      if (prev?.phase != CheckoutPhase.paid && next.phase == CheckoutPhase.paid) {
        if (_step == StarStep.pay) {
          setState(() {
            _igniteKey += 1;
            _step = StarStep.success;
          });
        }
      }
    });
  }

  Widget _pane(
    AsyncValue<List<PlanDto>> plansAsync,
    List<StarPlan> plans,
    StarPlan? selectedPlan,
    SubscriptionDto? sub,
    int subEndsAt,
    EntitlementDto? ent,
  ) {
    switch (_step) {
      case StarStep.overview:
        return OverviewPane(
          plans: plans,
          loading: plansAsync.isLoading,
          error: plansAsync.hasError,
          onRetry: () => ref.invalidate(payPlansProvider),
          selectedId: _planId,
          onSelect: (id) => setState(() => _planId = id),
          onIgnite: _goMethod,
          onRedeem: () => setState(() => _step = StarStep.redeem),
        );
      case StarStep.method:
        final checkoutState = ref.watch(checkoutControllerProvider);
        return MethodPane(
          options: ActivationOption.all,
          selected: _option,
          onSelect: (o) => setState(() => _option = o),
          canRecur: _canRecur(selectedPlan),
          recurring: _recurring,
          onRecurring: (v) => setState(() => _recurring = v),
          amount: selectedPlan != null ? '${selectedPlan.priceRub} ₽' : '',
          pending: checkoutState.phase == CheckoutPhase.creating,
          error: checkoutState.phase == CheckoutPhase.failed,
          onContinue: _startCheckout,
        );
      case StarStep.pay:
        final checkout = ref.watch(checkoutControllerProvider).checkout;
        return PayPane(
          option: _option ?? ActivationOption.all.first,
          phase: _payPhase(),
          serial: passSerial(checkout?.orderId ?? ''),
          sbpQr: checkout?.sbpQr,
          payTargets: checkout?.payTargets ?? const [],
          onChangeMethod: _goMethod,
          onOpenCheckout: () => _openUrl(checkout?.payUrl),
          onOpenTarget: (t) => _openUrl(t.url),
        );
      case StarStep.success:
        return SuccessPane(
          onMusic: () =>
              ref.read(routerProvider.notifier).selectTab(const HomeRoute()),
          onManage: () => setState(() => _step = StarStep.manage),
        );
      case StarStep.manage:
        final source = ent?.source ?? '';
        final autoRenew = (ent?.autoRenew ?? false) && !(ent?.canceled ?? false);
        return ManagePane(
          endsAt: subEndsAt,
          autoRenew: autoRenew,
          source: source,
          onExtend: () => setState(() => _step = StarStep.overview),
          onRedeem: () => setState(() => _step = StarStep.redeem),
          onCancelRenew:
              autoRenew && source.isNotEmpty ? () => _cancel(source) : null,
        );
      case StarStep.redeem:
        return _RedeemHost(
          onRedeemed: () => setState(() => _step = StarStep.manage),
        );
    }
  }

  Future<void> _cancel(String source) async {
    await ref.read(redeemControllerProvider).cancelSubscription(source);
  }
}

/// Хост redeem-панели: владеет pending/ошибкой вокруг `pay_redeem`.
class _RedeemHost extends ConsumerStatefulWidget {
  final VoidCallback onRedeemed;
  const _RedeemHost({required this.onRedeemed});

  @override
  ConsumerState<_RedeemHost> createState() => _RedeemHostState();
}

class _RedeemHostState extends ConsumerState<_RedeemHost> {
  bool _pending = false;
  String? _error;

  Future<void> _redeem(String code) async {
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      await ref.read(redeemControllerProvider).redeem(code);
      if (!mounted) return;
      widget.onRedeemed();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Код не принят. Проверь и попробуй снова.');
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RedeemPane(
      pending: _pending,
      errorText: _error,
      onRedeem: _redeem,
    );
  }
}

/// Замороженная шапка: «✦ STAR» mono слева + «назад» по шагу справа.
class _Header extends StatelessWidget {
  final StarStep? backTarget;
  final VoidCallback? onBack;
  const _Header({required this.backTarget, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final accent = ScTheme.paletteOf(context).accent;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Text('✦', style: TextStyle(fontSize: 12, color: accent)),
          const SizedBox(width: 10),
          const Text('STAR',
              style: TextStyle(
                fontFamily: starMono,
                fontSize: 12,
                letterSpacing: 12 * 0.34,
                color: Color(0x99FFFFFF),
              )),
          const Spacer(),
          if (backTarget != null) _BackButton(onTap: onBack),
        ],
      ),
    );
  }
}

class _BackButton extends StatefulWidget {
  final VoidCallback? onTap;
  const _BackButton({required this.onTap});

  @override
  State<_BackButton> createState() => _BackButtonState();
}

class _BackButtonState extends State<_BackButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final color = _hover ? const Color(0xE6FFFFFF) : const Color(0x73FFFFFF);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.chevronLeft, size: 14, color: color),
            const SizedBox(width: 6),
            Text('Назад',
                style: TextStyle(
                    fontFamily: starMono, fontSize: 11, letterSpacing: 11 * 0.14, color: color)),
          ],
        ),
      ),
    );
  }
}

/// Область ядра: живое ядро на фоне + readout в центре с тёмной линзой-скримом.
class _CoreRegion extends StatelessWidget {
  final double charge;
  final bool waiting;
  final bool lit;
  final int igniteKey;
  final Widget readout;

  const _CoreRegion({
    required this.charge,
    required this.waiting,
    required this.lit,
    required this.igniteKey,
    required this.readout,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        LivingCore(charge: charge, waiting: waiting, lit: lit, igniteKey: igniteKey),
        // readout на CORE_CENTER_Y (46%), по центру по X.
        Positioned.fill(
          child: IgnorePointer(
            child: Align(
              alignment: const Alignment(0, coreCenterY * 2 - 1),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Чистая тёмная линза — держит глифы читаемыми над ярким ядром.
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            radius: 0.6,
                            colors: const [
                              Color(0xF2030305), // rgba(3,3,5,0.95)
                              Color(0xDB030305), // 0.86
                              Color(0x6B030305), // 0.42
                              Color(0x00030305),
                            ],
                            stops: const [0, 0.4, 0.68, 0.86],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
                      child: readout,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
