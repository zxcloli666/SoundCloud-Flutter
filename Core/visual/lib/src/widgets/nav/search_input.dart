import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../perf.dart';
import '../../theme.dart';
import '../../tokens.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Стеклянное поле поиска (легаси GlobalSearch / Discover SearchInput): пилюля с
/// backdrop-blur, акцентной рамкой/тенью в фокусе, иконкой поиска и clear-X.
///
/// Дебаунс — здесь же: [onChanged] зовётся сразу для UI, [onDebounced] — после
/// паузы [debounce] (350ms у Search, 220ms у Discover). Сеть/логику дёргает
/// потребитель в [onDebounced]; виджет ничего не знает про данные.
class SearchInput extends StatefulWidget {
  final String? initialValue;
  final String hintText;
  final Duration debounce;
  final bool pill;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onDebounced;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onCleared;
  final TextEditingController? controller;
  final FocusNode? focusNode;

  const SearchInput({
    super.key,
    this.initialValue,
    this.hintText = '',
    this.debounce = const Duration(milliseconds: 350),
    this.pill = true,
    this.onChanged,
    this.onDebounced,
    this.onSubmitted,
    this.onCleared,
    this.controller,
    this.focusNode,
  });

  @override
  State<SearchInput> createState() => _SearchInputState();
}

class _SearchInputState extends State<SearchInput> {
  late final TextEditingController _controller =
      widget.controller ?? TextEditingController(text: widget.initialValue);
  late final FocusNode _focus = widget.focusNode ?? FocusNode();
  Timer? _debounce;
  bool _focused = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _hasText = _controller.text.isNotEmpty;
    _focus.addListener(_onFocusChange);
    _controller.addListener(_onTextChange);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focus.removeListener(_onFocusChange);
    _controller.removeListener(_onTextChange);
    if (widget.focusNode == null) _focus.dispose();
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() => setState(() => _focused = _focus.hasFocus);

  void _onTextChange() {
    final text = _controller.text;
    final hasText = text.isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
    widget.onChanged?.call(text);
    _debounce?.cancel();
    _debounce = Timer(widget.debounce, () => widget.onDebounced?.call(text));
  }

  void _clear() {
    _controller.clear();
    widget.onCleared?.call();
  }

  @override
  Widget build(BuildContext context) {
    final perf = ScPerf.of(context);
    final accent = ScTheme.paletteOf(context).accent;
    final radius =
        BorderRadius.circular(widget.pill ? 999 : ScTokens.rCard);
    final blur = PerfProfile(perf).sigma(24); // GlobalSearch blur(24)

    final iconColor = _focused ? accent : const Color(0x59FFFFFF); // white/35
    final borderColor = _focused ? accent : const Color(0x1FFFFFFF); // white/12
    final shadows = perf == PerfMode.light
        ? const <BoxShadow>[]
        : _focused
            ? [
                const BoxShadow(
                    color: Color(0x66000000), blurRadius: 34, offset: Offset(0, 10)),
                BoxShadow(
                    color: accent.withValues(alpha: 0.20), blurRadius: 22),
              ]
            : const [
                BoxShadow(
                    color: Color(0x47000000), blurRadius: 20, offset: Offset(0, 6)),
              ];

    Widget field = Container(
      height: widget.pill ? 44 : 42,
      padding: const EdgeInsets.only(left: 16, right: 8),
      decoration: BoxDecoration(
        color: perf == PerfMode.light
            ? const Color(0xD116161A)
            : const Color(0x12FFFFFF), // ~white/0.07 base tint
        borderRadius: radius,
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Row(
        children: [
          TweenAnimationBuilder<Color?>(
            duration: ScTokens.dFast,
            tween: ColorTween(end: iconColor),
            builder: (_, color, __) =>
                Icon(LucideIcons.search, size: 17, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(child: _textField()),
          if (_hasText) _clearButton(),
        ],
      ),
    );

    if (blur > 0) {
      field = ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: field,
        ),
      );
    } else {
      field = ClipRRect(borderRadius: radius, child: field);
    }

    return AnimatedContainer(
      duration: ScTokens.dGlass,
      curve: ScTokens.easeApple,
      decoration: BoxDecoration(borderRadius: radius, boxShadow: shadows),
      child: field,
    );
  }

  Widget _textField() {
    return TextField(
      controller: _controller,
      focusNode: _focus,
      cursorColor: ScTheme.paletteOf(context).accent,
      style: const TextStyle(color: Color(0xEBFFFFFF), fontSize: 14),
      textInputAction: TextInputAction.search,
      onSubmitted: (v) => widget.onSubmitted?.call(v),
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        hintText: widget.hintText,
        hintStyle: const TextStyle(color: Color(0x59FFFFFF), fontSize: 14),
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _clearButton() {
    return _IconHitTarget(
      size: 28,
      onTap: _clear,
      child: const Icon(LucideIcons.x, size: 15, color: Color(0x8CFFFFFF)),
    );
  }
}

/// Круглая кликабельная зона под мелкие иконки (clear-X и т.п.).
class _IconHitTarget extends StatefulWidget {
  final double size;
  final Widget child;
  final VoidCallback onTap;

  const _IconHitTarget({
    required this.size,
    required this.child,
    required this.onTap,
  });

  @override
  State<_IconHitTarget> createState() => _IconHitTargetState();
}

class _IconHitTargetState extends State<_IconHitTarget> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: widget.size,
          height: widget.size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _hover ? const Color(0x14FFFFFF) : Colors.transparent,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
