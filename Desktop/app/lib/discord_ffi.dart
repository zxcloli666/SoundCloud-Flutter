import 'dart:ffi';

import 'package:ffi/ffi.dart';

/// Обёртка над Discord-частью `libdesktop_bridge.so`: Rich Presence «Listening to»
/// (обложка + кнопка + live-таймстемпы) по медиа-хукам движка. Discord не запущен
/// — `init` вернёт `false`, остальное no-op.
class DesktopDiscord {
  final bool Function() _init;
  final void Function(
      Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, int) _nowPlaying;
  final void Function(bool) _setPlaying;
  final void Function(int) _setPosition;
  final void Function() _clear;

  DesktopDiscord._(
    this._init,
    this._nowPlaying,
    this._setPlaying,
    this._setPosition,
    this._clear,
  );

  factory DesktopDiscord.open(String libPath) {
    final lib = DynamicLibrary.open(libPath);
    return DesktopDiscord._(
      lib.lookupFunction<Bool Function(), bool Function()>('sc_discord_init'),
      lib.lookupFunction<
          Void Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>,
              Pointer<Utf8>, Int64),
          void Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>,
              Pointer<Utf8>, int)>('sc_discord_now_playing'),
      lib.lookupFunction<Void Function(Bool), void Function(bool)>(
          'sc_discord_set_playing'),
      lib.lookupFunction<Void Function(Int64), void Function(int)>(
          'sc_discord_set_position'),
      lib.lookupFunction<Void Function(), void Function()>('sc_discord_clear'),
    );
  }

  bool init() => _init();

  void nowPlaying(
      String title, String artist, String coverUrl, String trackUrl, int durationSecs) {
    final titlePtr = title.toNativeUtf8();
    final artistPtr = artist.toNativeUtf8();
    final coverPtr = coverUrl.toNativeUtf8();
    final urlPtr = trackUrl.toNativeUtf8();
    try {
      _nowPlaying(titlePtr, artistPtr, coverPtr, urlPtr, durationSecs);
    } finally {
      malloc.free(titlePtr);
      malloc.free(artistPtr);
      malloc.free(coverPtr);
      malloc.free(urlPtr);
    }
  }

  void setPlaying(bool playing) => _setPlaying(playing);

  void setPosition(int positionSecs) => _setPosition(positionSecs);

  void clear() => _clear();
}
