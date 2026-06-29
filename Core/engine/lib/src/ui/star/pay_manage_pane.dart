import 'package:flutter/material.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../rust/dto_pay.dart';
import 'console.dart';
import 'star_data.dart';

/// Pay: SBP QR с шагами, либо внешний/крипто-чекаут в браузере (легаси `PayPane`).
/// SBP рисует реальный QR из `sbpQr` через [ScQrCode]; крипто/карта открывают
/// `payTargets`/`payUrl` во внешнем браузере.
class PayPane extends StatelessWidget {
  final ActivationOption option;
  final PayPhase phase;
  final String serial;
  final String? sbpQr;
  final List<PayTargetDto> payTargets;
  final bool expired;
  final String? timeLeftLabel;
  final VoidCallback onChangeMethod;

  /// Открыть `payUrl` (single-target/SBP-fallback во внешнем браузере).
  final VoidCallback? onOpenCheckout;

  /// Открыть конкретный таргет (CryptoBot tg/webapp и т.п.).
  final ValueChanged<PayTargetDto>? onOpenTarget;

  const PayPane({
    super.key,
    required this.option,
    required this.phase,
    required this.serial,
    required this.onChangeMethod,
    this.sbpQr,
    this.payTargets = const [],
    this.expired = false,
    this.timeLeftLabel,
    this.onOpenCheckout,
    this.onOpenTarget,
  });

  bool get _isSbp => option.isSbp && sbpQr != null;

  @override
  Widget build(BuildContext context) {
    final accent = ScTheme.paletteOf(context).accent;

    if (expired) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Ttl('${option.title} · $serial'),
          const Text('Время на оплату истекло. Создай заказ заново.',
              style: TextStyle(fontSize: 12.5, height: 1.5, color: Color(0x99FFFFFF))),
          const SizedBox(height: 14),
          PrimaryBtn(onPressed: onChangeMethod, child: const Text('Повторить')),
        ],
      );
    }

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Ttl([
          '${option.title} · ${option.tag} · $serial',
          if (phase == PayPhase.waiting && timeLeftLabel != null) ' · $timeLeftLabel',
        ].join()),
        if (_isSbp)
          _sbpSteps(accent)
        else
          const Text(
            'Открой страницу оплаты в браузере и заверши платёж — членство активируется автоматически.',
            style: TextStyle(fontSize: 12.5, height: 1.5, color: Color(0x99FFFFFF)),
          ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (!_isSbp) ..._checkoutButtons(),
            if (phase == PayPhase.failed)
              PrimaryBtn(onPressed: onChangeMethod, child: const Text('Повторить')),
            LinkBtn(label: 'Сменить способ', onPressed: onChangeMethod),
          ],
        ),
      ],
    );

    if (!_isSbp) return body;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _qrTile(),
        const SizedBox(width: 16),
        Expanded(child: body),
      ],
    );
  }

  Widget _qrTile() => ScQrCode(data: sbpQr!, size: 132);

  /// Кнопки внешнего чекаута (легаси `PayPane`): >1 таргета → ghost-кнопка на
  /// каждый, иначе единая primary «Открыть оплату».
  List<Widget> _checkoutButtons() {
    if (payTargets.length > 1) {
      return [
        for (final tg in payTargets)
          GhostBtn(
            onPressed: () => onOpenTarget?.call(tg),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(_targetLabel(tg.kind)),
              const SizedBox(width: 8),
              const Icon(LucideIcons.externalLink, size: 13),
            ]),
          ),
      ];
    }
    return [
      PrimaryBtn(
        onPressed: onOpenCheckout ?? () {},
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Text('Открыть оплату'),
          SizedBox(width: 8),
          Icon(LucideIcons.externalLink),
        ]),
      ),
    ];
  }

  String _targetLabel(String kind) => switch (kind) {
        'tg' => 'Открыть в Telegram',
        'webapp' => 'Открыть в браузере',
        'miniapp' => 'Открыть мини-приложение',
        _ => 'Открыть',
      };

  Widget _sbpSteps(Color accent) {
    const steps = [
      'Открой приложение банка',
      'Отсканируй QR-код или подтверди оплату',
      'Дождись подтверждения — членство активируется',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 16,
                  child: Text(
                    (i + 1).toString().padLeft(2, '0'),
                    style: TextStyle(fontFamily: starMono, fontSize: 11, color: accent),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(steps[i],
                      style: const TextStyle(fontSize: 12.5, color: Color(0x99FFFFFF))),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Manage: Discord-связка, автопродление (cancel-only), источник; продлить/код
/// (легаси `ManagePane` + `DiscordCard`). Discord/cancel требуют pay-моста —
/// здесь карточка-приглашение и тумблер по факту состояния подписки.
class ManagePane extends StatelessWidget {
  final int endsAt;
  final bool autoRenew;
  final String source;
  final VoidCallback onExtend;
  final VoidCallback onRedeem;
  final VoidCallback? onCancelRenew;

  const ManagePane({
    super.key,
    required this.endsAt,
    required this.autoRenew,
    required this.source,
    required this.onExtend,
    required this.onRedeem,
    this.onCancelRenew,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _DiscordCard(),
        const SizedBox(height: 10),
        _row(
          context,
          title: 'Автопродление',
          sub: autoRenew
              ? 'Следующее списание ${passDate(endsAt)}'
              : 'Выключено — продли вручную',
          trailing: _renewSwitch(context),
        ),
        const SizedBox(height: 10),
        _row(
          context,
          title: 'Источник',
          sub: 'Откуда активировано членство',
          trailing: Text(
            source.isEmpty ? '—' : source,
            style: const TextStyle(fontFamily: starMono, fontSize: 13, color: Colors.white),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            GhostBtn(onPressed: onExtend, child: const Text('Продлить')),
            GhostBtn(onPressed: onRedeem, child: const Text('Ввести код')),
          ],
        ),
      ],
    );
  }

  Widget _row(BuildContext context,
      {required String title, required String sub, required Widget trailing}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x14FFFFFF)),
        color: const Color(0x08FFFFFF),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xD9FFFFFF))),
                const SizedBox(height: 2),
                Text(sub, style: const TextStyle(fontSize: 11.5, color: Color(0x66FFFFFF))),
              ],
            ),
          ),
          const SizedBox(width: 12),
          trailing,
        ],
      ),
    );
  }

  Widget _renewSwitch(BuildContext context) {
    final accent = ScTheme.paletteOf(context).accent;
    final enabled = autoRenew && onCancelRenew != null;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: enabled ? onCancelRenew : null,
        child: Container(
          width: 44,
          height: 24,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0x1FFFFFFF)),
            color: autoRenew ? accent.withValues(alpha: 0.22) : const Color(0x0AFFFFFF),
          ),
          child: AnimatedAlign(
            duration: ScTokens.dSidebar,
            alignment: autoRenew ? Alignment.centerRight : Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: autoRenew ? accent : const Color(0x66FFFFFF),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Discord-карточка (легаси `DiscordCard`). Без pay-моста показываем пустое
/// состояние с подсказкой `/sc-link`.
class _DiscordCard extends StatelessWidget {
  const _DiscordCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x0FFFFFFF)),
        color: const Color(0x08FFFFFF),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.discord, size: 15, color: Color(0x73FFFFFF)),
              SizedBox(width: 7),
              Text('DISCORD',
                  style: TextStyle(
                      fontFamily: starMono,
                      fontSize: 10.5,
                      letterSpacing: 10.5 * 0.18,
                      color: Color(0x73FFFFFF))),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Discord ещё не привязан',
              style: TextStyle(fontSize: 13, color: Color(0xBFFFFFFF))),
          const SizedBox(height: 6),
          const Text('Привяжи аккаунт командой в нашем сервере',
              style: TextStyle(fontSize: 12, color: Color(0x66FFFFFF))),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: const Color(0x0FFFFFFF),
            ),
            child: const Text('/sc-link',
                style: TextStyle(
                    fontFamily: starMono, fontSize: 12, color: Color(0xD9FFFFFF))),
          ),
        ],
      ),
    );
  }
}
