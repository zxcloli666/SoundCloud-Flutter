import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// Кнопки управления окном (правый край шапки): фуллскрин · свернуть · развернуть
/// · закрыть. Сама шапка (лого/нав/поиск) и перетаскивание — в движке
/// (`ScHeaderBar`); сюда десктоп отдаёт только нативные оконные операции.
class WindowControls extends StatelessWidget {
  const WindowControls({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _WinButton(icon: Icons.fullscreen, iconSize: 17, onTap: _toggleFullscreen),
        _WinButton(icon: Icons.remove, iconSize: 16, onTap: windowManager.minimize),
        _WinButton(icon: Icons.crop_square_rounded, iconSize: 13, onTap: toggleMaximize),
        _WinButton(icon: Icons.close_rounded, iconSize: 16, danger: true, onTap: windowManager.close),
      ],
    );
  }
}

Future<void> toggleMaximize() async {
  if (await windowManager.isMaximized()) {
    await windowManager.unmaximize();
  } else {
    await windowManager.maximize();
  }
}

Future<void> _toggleFullscreen() async {
  await windowManager.setFullScreen(!await windowManager.isFullScreen());
}

class _WinButton extends StatefulWidget {
  final IconData icon;
  final double iconSize;
  final bool danger;
  final Future<void> Function() onTap;

  const _WinButton({
    required this.icon,
    required this.onTap,
    this.iconSize = 18,
    this.danger = false,
  });

  @override
  State<_WinButton> createState() => _WinButtonState();
}

class _WinButtonState extends State<_WinButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final Color bg = _hover
        ? (widget.danger ? const Color(0xCCDC2626) : const Color(0x12FFFFFF))
        : const Color(0x00000000);
    final Color fg = _hover ? const Color(0xFFFFFFFF) : const Color(0x4DFFFFFF);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => widget.onTap(),
        child: Container(
          width: 40,
          height: 36,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
          child: Icon(widget.icon, size: widget.iconSize, color: fg),
        ),
      ),
    );
  }
}
