import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

/// Обёртка над tray-частью `libdesktop_bridge.so`: системный трей через нативный
/// StatusNotifierItem (ksni/D-Bus, без GTK — поднимается на Wayland/Hyprland, где
/// GTK-трей пустой). Меню статичное (как в Tauri); клики прилетают кодом в
/// [NativeCallable], откуда дёргаем переданные обработчики. Левый клик иконки и
/// пункт «Мини-плеер» → один обработчик.
class DesktopTray {
  final bool Function(Pointer<Utf8>) _init;
  final void Function(Pointer<NativeFunction<Void Function(Int32)>>) _setHandler;

  NativeCallable<Void Function(Int32)>? _cb;

  DesktopTray._(this._init, this._setHandler);

  factory DesktopTray.open(String libPath) {
    final lib = DynamicLibrary.open(libPath);
    return DesktopTray._(
      lib.lookupFunction<Bool Function(Pointer<Utf8>),
          bool Function(Pointer<Utf8>)>('sc_tray_init'),
      lib.lookupFunction<
              Void Function(Pointer<NativeFunction<Void Function(Int32)>>),
              void Function(Pointer<NativeFunction<Void Function(Int32)>>)>(
          'sc_tray_set_action_handler'),
    );
  }

  /// Поднять трей с иконкой [iconPath] (PNG). Обработчики действий — inbound через
  /// нативный колбэк. `false` — трей не поднялся.
  bool start({
    required String iconPath,
    required VoidCallback onShow,
    required VoidCallback onMini,
    required VoidCallback onPlayPause,
    required VoidCallback onPrev,
    required VoidCallback onNext,
    required VoidCallback onQuit,
  }) {
    _cb = NativeCallable<Void Function(Int32)>.listener((int code) {
      switch (code) {
        case 0:
          onShow();
        case 1:
        case 6: // левый клик иконки → тоже мини-плеер
          onMini();
        case 2:
          onPlayPause();
        case 3:
          onPrev();
        case 4:
          onNext();
        case 5:
          onQuit();
      }
    });
    _setHandler(_cb!.nativeFunction);
    final ptr = iconPath.toNativeUtf8();
    try {
      return _init(ptr);
    } finally {
      malloc.free(ptr);
    }
  }

  void dispose() {
    _setHandler(nullptr);
    _cb?.close();
    _cb = null;
  }
}
