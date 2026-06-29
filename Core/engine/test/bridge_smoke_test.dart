import 'dart:io';

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sc_engine/src/rust/api.dart';
import 'package:sc_engine/src/rust/frb_generated.dart';

/// Проверка проброса Dart→Rust через нативную либу (без cargokit, напрямую).
/// Запуск: `flutter test test/bridge_smoke_test.dart` (headless, без дисплея).
void main() {
  const libPath =
      '/home/loli/IdeaProjects/SoundCloud/Core/shared/target/debug/libsc_bridge.so';

  test('нативная либа грузится и вызов проходит сквозь FFI', () async {
    await RustLib.init(externalLibrary: ExternalLibrary.open(libPath));

    final tmp = Directory.systemTemp.createTempSync('sc_bridge_smoke').path;
    await initRuntime(dataDir: tmp, cacheDir: tmp, dpiBypass: false);

    // search ходит в сеть (SoundCloud). Сети может не быть — нам важно, что
    // вызов реально дошёл до Rust и вернулся (результатом или ошибкой через FFI).
    try {
      final tracks = await search(query: 'lofi', limit: 3, offset: 0);
      // ignore: avoid_print
      print('SMOKE: search вернул ${tracks.length} треков');
    } catch (error) {
      // ignore: avoid_print
      print('SMOKE: search бросил (вероятно нет сети/SC): $error');
    }
  });
}
