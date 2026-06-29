import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../perf.dart';
import '../../theme.dart';
import '../../tokens.dart';

class TabDockItem {
  final String id;
  final String label;
  final int? count;

  const TabDockItem({required this.id, required this.label, this.count});
}

/// Сегментный контрол со скользящей пилюлей (легаси `TabDock`): стеклянный док,
/// пилюля едет под активную вкладку 500ms ease-label. Цвет пилюли — [aura]
/// (по умолчанию акцент темы). Меряем ширины кнопок и анимируем позицию.
class TabDock extends StatefulWidget {
  final List<TabDockItem> tabs;
  final String activeId;
  final ValueChanged<String> onChanged;
  final Color? aura;

  const TabDock({
    super.key,
    required this.tabs,
    required this.activeId,
    required this.onChanged,
    this.aura,
  });

  @override
  State<TabDock> createState() => _TabDockState();
}

class _TabDockState extends State<TabDock> {
  static const _pillCurve = Cubic(0.2, 0.8, 0.2, 1);
  static const _pillDuration = Duration(milliseconds: 500);
  static const _height = 36.0;
  static const _gap = 4.0;

  final _keys = <String, GlobalKey>{};
  Rect? _pillRect;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncPill());
  }

  @override
  void didUpdateWidget(TabDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeId != widget.activeId ||
        oldWidget.tabs.length != widget.tabs.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncPill());
    }
  }

  void _syncPill() {
    final key = _keys[widget.activeId];
    final box = key?.currentContext?.findRenderObject() as RenderBox?;
    final dock = context.findRenderObject() as RenderBox?;
    if (box == null || dock == null || !box.hasSize) return;
    final origin = dock.globalToLocal(box.localToGlobal(Offset.zero));
    final next = origin & box.size;
    if (next != _pillRect) setState(() => _pillRect = next);
  }

  @override
  Widget build(BuildContext context) {
    final perf = ScPerf.of(context);
    final aura = widget.aura ?? ScTheme.paletteOf(context).accent;
    final radius = BorderRadius.circular(ScTokens.rCard);
    final blur = PerfProfile(perf).sigma(40); // dock blur(40)

    Widget dock = Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: perf == PerfMode.light
            ? const Color(0xEB0F0F12) // rgba(15,15,18,0.92)
            : const Color(0x8C0F0F12), // rgba(15,15,18,0.55)
        borderRadius: radius,
        border: Border.all(color: const Color(0x14FFFFFF)), // inset white/0.08
      ),
      child: Stack(
        children: [
          if (_pillRect != null) _pill(aura),
          _tabRow(aura),
        ],
      ),
    );

    if (blur > 0) {
      dock = ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: dock,
        ),
      );
    } else {
      dock = ClipRRect(borderRadius: radius, child: dock);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: perf == PerfMode.light
            ? const []
            : const [
                BoxShadow(
                    color: Color(0x73000000), blurRadius: 60, offset: Offset(0, 24)),
              ],
      ),
      child: dock,
    );
  }

  Widget _pill(Color aura) {
    final rect = _pillRect!;
    return AnimatedPositioned(
      duration: _pillDuration,
      curve: _pillCurve,
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ScTokens.rButton),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [aura.withValues(alpha: 0.22), aura.withValues(alpha: 0.06)],
          ),
          border: Border.all(color: aura.withValues(alpha: 0.35), width: 0.5),
          boxShadow: [
            BoxShadow(
              color: aura.withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabRow(Color aura) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < widget.tabs.length; i++) ...[
            if (i > 0) const SizedBox(width: _gap),
            _tabButton(widget.tabs[i]),
          ],
        ],
      ),
    );
  }

  Widget _tabButton(TabDockItem tab) {
    final active = tab.id == widget.activeId;
    final key = _keys.putIfAbsent(tab.id, GlobalKey.new);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => widget.onChanged(tab.id),
        child: Container(
          key: key,
          height: _height,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedDefaultTextStyle(
                duration: ScTokens.dFast,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: active ? const Color(0xFFFFFFFF) : const Color(0x73FFFFFF),
                ),
                child: Text(tab.label),
              ),
              if (tab.count != null) ...[
                const SizedBox(width: 7),
                _countChip(tab.count!, active),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _countChip(int count, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: active ? const Color(0x1FFFFFFF) : const Color(0x0FFFFFFF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: active ? const Color(0xCCFFFFFF) : const Color(0x73FFFFFF),
        ),
      ),
    );
  }
}
