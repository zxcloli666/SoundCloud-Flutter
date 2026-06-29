import 'dart:ffi';

import 'package:ffi/ffi.dart';

/// Обёртка над call-частью `libdesktop_bridge.so`: relay-агент (call-client).
/// «Подключение» = автостарт по флагу; нода участвует в relay-сети, бэкенд ходит
/// через неё. Реальный клиент инжектится в проде (локально — disabled).
class DesktopCall {
  final bool Function(Pointer<Utf8>) _start;
  final void Function(bool) _setEnabled;
  final int Function() _status;
  final bool Function() _isEnabled;

  DesktopCall._(this._start, this._setEnabled, this._status, this._isEnabled);

  factory DesktopCall.open(String libPath) {
    final lib = DynamicLibrary.open(libPath);
    return DesktopCall._(
      lib.lookupFunction<Bool Function(Pointer<Utf8>),
          bool Function(Pointer<Utf8>)>('sc_call_start'),
      lib.lookupFunction<Void Function(Bool), void Function(bool)>(
          'sc_call_set_enabled'),
      lib.lookupFunction<Int32 Function(), int Function()>('sc_call_status'),
      lib.lookupFunction<Bool Function(), bool Function()>('sc_call_is_enabled'),
    );
  }

  /// Поднять агент (автостарт по флагу в [dataDir]).
  bool start(String dataDir) {
    final ptr = dataDir.toNativeUtf8();
    try {
      return _start(ptr);
    } finally {
      malloc.free(ptr);
    }
  }

  void setEnabled(bool enabled) => _setEnabled(enabled);

  /// 0 disabled · 1 connecting · 2 provisioning · 3 active · 4 failed.
  int status() => _status();

  bool isEnabled() => _isEnabled();
}
