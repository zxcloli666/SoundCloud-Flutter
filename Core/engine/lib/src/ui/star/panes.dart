import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sc_visual/sc_visual.dart';

import 'console.dart';
import 'provider_glyph.dart';
import 'star_data.dart';

/// Overview: выбор длительности, перки, зажигание или ввод кода (легаси `OverviewPane`).
class OverviewPane extends StatelessWidget {
  final List<StarPlan> plans;
  final bool loading;
  final bool error;
  final VoidCallback onRetry;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final VoidCallback onIgnite;
  final VoidCallback onRedeem;

  const OverviewPane({
    super.key,
    required this.plans,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.selectedId,
    required this.onSelect,
    required this.onIgnite,
    required this.onRedeem,
  });

  @override
  Widget build(BuildContext context) {
    final accent = ScTheme.paletteOf(context).accent;
    if (error) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Не удалось загрузить тарифы',
              style: TextStyle(fontSize: 14, color: Color(0xE6FCA5A5))),
          const SizedBox(height: 12),
          GhostBtn(onPressed: onRetry, child: const Text('Повторить')),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DurationSegmented(
          plans: loading ? const [] : plans,
          loading: loading,
          selectedId: selectedId,
          onSelect: onSelect,
          accent: accent,
        ),
        const SizedBox(height: 16),
        _PerksGrid(accent: accent),
        const SizedBox(height: 18),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            PrimaryBtn(
              onPressed: onIgnite,
              disabled: selectedId == null,
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Text('Активировать'),
                SizedBox(width: 8),
                Icon(LucideIcons.arrowRight),
              ]),
            ),
            LinkBtn(label: 'У меня есть код', onPressed: onRedeem),
          ],
        ),
      ],
    );
  }
}

class _DurationSegmented extends StatelessWidget {
  final List<StarPlan> plans;
  final bool loading;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final Color accent;

  const _DurationSegmented({
    required this.plans,
    required this.loading,
    required this.selectedId,
    required this.onSelect,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x1AFFFFFF)),
        color: const Color(0x0AFFFFFF),
      ),
      child: Row(
        children: [
          if (loading)
            const Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text('Загрузка…',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: starMono, fontSize: 12, color: Color(0x66FFFFFF))),
              ),
            )
          else
            for (final p in plans)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: p == plans.last ? 0 : 6),
                  child: _segment(p, p.id == selectedId),
                ),
              ),
        ],
      ),
    );
  }

  Widget _segment(StarPlan p, bool on) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => onSelect(p.id),
        child: AnimatedContainer(
          duration: ScTokens.dFast,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: on
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [accent.withValues(alpha: 0.28), const Color(0x0FFFFFFF)],
                  )
                : null,
            boxShadow: on
                ? [BoxShadow(color: accent.withValues(alpha: 0.20), blurRadius: 18, spreadRadius: -4)]
                : null,
            border: on
                ? Border.all(color: accent.withValues(alpha: 0.45))
                : Border.all(color: const Color(0x00000000)),
          ),
          child: Column(
            children: [
              Text(
                p.termLabel,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: starMono,
                  fontSize: 12,
                  color: on ? Colors.white : const Color(0x80FFFFFF),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${p.priceRub} ₽',
                      style: const TextStyle(fontSize: 9.5, color: Color(0x73FFFFFF))),
                  if (p.savingsPct > 0) ...[
                    const SizedBox(width: 6),
                    Text('−${p.savingsPct}%',
                        style: TextStyle(
                            fontSize: 9.5, fontWeight: FontWeight.w600, color: accent)),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PerksGrid extends StatelessWidget {
  final Color accent;
  const _PerksGrid({required this.accent});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 560 ? 3 : 2;
        const gap = 8.0;
        final cellW = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final perk in StarPerk.all)
              SizedBox(
                width: cellW,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: const Color(0x14FFFFFF)),
                    color: const Color(0x06FFFFFF),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: accent.withValues(alpha: 0.13),
                          border: Border.all(color: accent.withValues(alpha: 0.22)),
                        ),
                        child: Icon(perk.icon, size: 14, color: accent),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          perk.title,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            height: 1.15,
                            color: Color(0xD9FFFFFF),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Method: шесть способов оплаты + recurring-чекбокс (легаси `MethodPane`).
class MethodPane extends StatelessWidget {
  final List<ActivationOption> options;
  final ActivationOption? selected;
  final ValueChanged<ActivationOption> onSelect;
  final bool canRecur;
  final bool recurring;
  final ValueChanged<bool> onRecurring;
  final String amount;
  final bool pending;
  final bool error;
  final VoidCallback onContinue;

  const MethodPane({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelect,
    required this.canRecur,
    required this.recurring,
    required this.onRecurring,
    required this.amount,
    required this.pending,
    required this.error,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final accent = ScTheme.paletteOf(context).accent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Ttl('Способ активации'),
        LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth >= 560 ? 3 : 2;
            const gap = 8.0;
            final cellW = (c.maxWidth - gap * (cols - 1)) / cols;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final opt in options)
                  SizedBox(
                    width: cellW,
                    child: _MethodCard(
                      option: opt,
                      on: opt.kind == selected?.kind,
                      accent: accent,
                      onTap: () => onSelect(opt),
                    ),
                  ),
              ],
            );
          },
        ),
        if (canRecur) ...[
          const SizedBox(height: 14),
          _RecurringCheckbox(
            checked: recurring,
            accent: accent,
            onChanged: () => onRecurring(!recurring),
          ),
        ],
        const SizedBox(height: 18),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            PrimaryBtn(
              onPressed: onContinue,
              disabled: selected == null || pending,
              child: Text(pending ? 'Создаём…' : 'Продолжить · $amount'),
            ),
            if (error)
              const Text('Не удалось создать заказ',
                  style: TextStyle(fontSize: 12.5, color: Color(0xF2FCA5A5))),
          ],
        ),
      ],
    );
  }
}

class _MethodCard extends StatefulWidget {
  final ActivationOption option;
  final bool on;
  final Color accent;
  final VoidCallback onTap;
  const _MethodCard(
      {required this.option, required this.on, required this.accent, required this.onTap});

  @override
  State<_MethodCard> createState() => _MethodCardState();
}

class _MethodCardState extends State<_MethodCard> {
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
          transform: Matrix4.translationValues(0, _hover ? -2 : 0, 0),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            color: const Color(0x06FFFFFF),
            border: Border.all(
              color: widget.on
                  ? widget.accent.withValues(alpha: 0.6)
                  : const Color(0x1AFFFFFF),
            ),
            boxShadow: widget.on
                ? [BoxShadow(color: widget.accent.withValues(alpha: 0.20), blurRadius: 24, spreadRadius: -8)]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  color: const Color(0x0AFFFFFF),
                  border: Border.all(color: const Color(0x14FFFFFF)),
                ),
                child: ProviderGlyph(kind: widget.option.kind),
              ),
              const SizedBox(height: 10),
              Text(widget.option.title,
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xE6FFFFFF))),
              const SizedBox(height: 2),
              Text(widget.option.tag,
                  style: const TextStyle(
                      fontFamily: starMono,
                      fontSize: 9,
                      letterSpacing: 9 * 0.06,
                      color: Color(0x66FFFFFF))),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecurringCheckbox extends StatelessWidget {
  final bool checked;
  final Color accent;
  final VoidCallback onChanged;
  const _RecurringCheckbox(
      {required this.checked, required this.accent, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final palette = ScTheme.paletteOf(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onChanged,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x1AFFFFFF)),
            color: const Color(0x08FFFFFF),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: ScTokens.dFast,
                width: 19,
                height: 19,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: checked ? accent : const Color(0x00000000),
                  border: Border.all(
                      color: checked ? accent : const Color(0x38FFFFFF)),
                  boxShadow: checked
                      ? [BoxShadow(color: accent.withValues(alpha: 0.20), blurRadius: 14, spreadRadius: -3)]
                      : null,
                ),
                child: checked
                    ? Icon(LucideIcons.check, size: 12, color: palette.accentContrast)
                    : null,
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Автопродление',
                      style: TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w500, color: Color(0xD9FFFFFF))),
                  Text('Продлевать подписку автоматически',
                      style: TextStyle(fontSize: 11, color: Color(0x66FFFFFF))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Success: что разблокировано + к музыке / управление (легаси `SuccessPane`).
class SuccessPane extends StatelessWidget {
  final VoidCallback onMusic;
  final VoidCallback onManage;
  const SuccessPane({super.key, required this.onMusic, required this.onManage});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final perk in StarPerk.all)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0x14FFFFFF)),
                  color: const Color(0x08FFFFFF),
                ),
                child: Text(
                  perk.title,
                  style: const TextStyle(
                      fontFamily: starMono,
                      fontSize: 10.5,
                      letterSpacing: 10.5 * 0.08,
                      color: Color(0xA6FFFFFF)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            PrimaryBtn(onPressed: onMusic, child: const Text('К музыке')),
            GhostBtn(onPressed: onManage, child: const Text('Управление')),
          ],
        ),
      ],
    );
  }
}

/// Redeem: сегментированный ввод STAR-кода (легаси `RedeemPane`).
class RedeemPane extends StatefulWidget {
  final ValueChanged<String> onRedeem;
  final bool pending;
  final String? errorText;
  const RedeemPane({
    super.key,
    required this.onRedeem,
    this.pending = false,
    this.errorText,
  });

  @override
  State<RedeemPane> createState() => _RedeemPaneState();
}

class _RedeemPaneState extends State<RedeemPane> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  String _body = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String raw) {
    final body = normalizeCodeBody(raw);
    if (body != _controller.text) {
      _controller.value = TextEditingValue(
        text: body,
        selection: TextSelection.collapsed(offset: body.length),
      );
    }
    setState(() => _body = body);
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData('text/plain');
    if (!mounted) return;
    if (data?.text != null) _onChanged(data!.text!);
    _focus.requestFocus();
  }

  bool get _valid => starCodeRe.hasMatch(formatCode(_body));

  @override
  Widget build(BuildContext context) {
    final accent = ScTheme.paletteOf(context).accent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Ttl('Активация по коду'),
        Stack(
          children: [
            // Скрытый инпут поверх ячеек (ловит ввод/вставку/бэкспейс).
            Positioned.fill(
              child: Opacity(
                opacity: 0,
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  autofocus: true,
                  onChanged: _onChanged,
                  textCapitalization: TextCapitalization.characters,
                ),
              ),
            ),
            _CodeCells(body: _body, accent: accent),
          ],
        ),
        if (widget.errorText != null) ...[
          const SizedBox(height: 10),
          Text(widget.errorText!,
              style: const TextStyle(fontSize: 12.5, color: Color(0xF2FCA5A5))),
        ],
        const SizedBox(height: 18),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            PrimaryBtn(
              onPressed: () => widget.onRedeem(formatCode(_body)),
              disabled: !_valid || widget.pending,
              child: Text(widget.pending ? 'Активируем…' : 'Активировать'),
            ),
            LinkBtn(label: 'Вставить', onPressed: _paste),
          ],
        ),
      ],
    );
  }
}

class _CodeCells extends StatelessWidget {
  final String body;
  final Color accent;
  const _CodeCells({required this.body, required this.accent});

  @override
  Widget build(BuildContext context) {
    final groups = <Widget>[
      const Padding(
        padding: EdgeInsets.only(right: 8),
        child: Text('STAR',
            style: TextStyle(
                fontFamily: starMono,
                fontSize: 15,
                letterSpacing: 15 * 0.12,
                color: Color(0x73FFFFFF))),
      ),
    ];
    for (var g = 0; g < 4; g++) {
      groups.add(const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Text('–', style: TextStyle(fontFamily: starMono, color: Color(0x40FFFFFF))),
      ));
      groups.add(Expanded(
        child: Row(
          children: [
            for (var c = 0; c < 4; c++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: c == 3 ? 0 : 6),
                  child: _cell(g * 4 + c),
                ),
              ),
          ],
        ),
      ));
    }
    return IgnorePointer(child: Row(children: groups));
  }

  Widget _cell(int idx) {
    final ch = idx < body.length ? body[idx] : null;
    final active = idx == body.length && body.length < 16;
    return AspectRatio(
      aspectRatio: 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          color: ch != null ? const Color(0x0DFFFFFF) : const Color(0x00000000),
          border: Border.all(
            color: active
                ? accent
                : ch != null
                    ? const Color(0x38FFFFFF)
                    : const Color(0x1AFFFFFF),
          ),
          boxShadow: active
              ? [BoxShadow(color: accent.withValues(alpha: 0.20), blurRadius: 16, spreadRadius: -4)]
              : null,
        ),
        child: Text(
          ch ?? 'X',
          style: TextStyle(
            fontFamily: starMono,
            fontSize: 16,
            color: ch != null ? Colors.white : const Color(0x38FFFFFF),
          ),
        ),
      ),
    );
  }
}
