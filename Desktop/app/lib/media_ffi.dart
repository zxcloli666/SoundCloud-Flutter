import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:sc_engine/sc_engine.dart';

/// Обёртка над media-частью `libdesktop_bridge.so` (единый десктоп-FFI):
/// системные медиа-контролы (MPRIS/SMTC). Outbound — метаданные/обложка/
/// длительность/позиция/play-state по событиям движка; inbound (медиа-клавиши ОС)
/// — через [NativeCallable] в [ScRemoteControls].
class DesktopMedia {
  final bool Function() _init;
  final void Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, int)
      _nowPlaying;
  final void Function(bool) _setPlaying;
  final void Function(int) _setPosition;
  final void Function() _clear;
  final void Function(Pointer<NativeFunction<Void Function(Int32)>>)
      _setEventHandler;

  NativeCallable<Void Function(Int32)>? _eventCb;

  DesktopMedia._(
    this._init,
    this._nowPlaying,
    this._setPlaying,
    this._setPosition,
    this._clear,
    this._setEventHandler,
  );

  factory DesktopMedia.open(String libPath) {
    final lib = DynamicLibrary.open(libPath);
    return DesktopMedia._(
      lib.lookupFunction<Bool Function(), bool Function()>('sc_media_init'),
      lib.lookupFunction<
          Void Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Int64),
          void Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>,
              int)>('sc_media_now_playing'),
      lib.lookupFunction<Void Function(Bool), void Function(bool)>(
          'sc_media_set_playing'),
      lib.lookupFunction<Void Function(Int64), void Function(int)>(
          'sc_media_set_position'),
      lib.lookupFunction<Void Function(), void Function()>('sc_media_clear'),
      lib.lookupFunction<
              Void Function(Pointer<NativeFunction<Void Function(Int32)>>),
              void Function(Pointer<NativeFunction<Void Function(Int32)>>)>(
          'sc_media_set_event_handler'),
    );
  }

  bool init() => _init();

  /// Подключить медиа-клавиши ОС к движку (inbound). Коды зеркалят `MediaKey`.
  void bindRemote(ScRemoteControls remote) {
    _eventCb = NativeCallable<Void Function(Int32)>.listener((int code) {
      switch (code) {
        case 0:
          remote.play();
        case 1:
          remote.pause();
        case 2:
          remote.playPause();
        case 3:
          remote.next();
        case 4:
          remote.previous();
        case 5:
          remote.stop();
      }
    });
    _setEventHandler(_eventCb!.nativeFunction);
  }

  void nowPlaying(String title, String artist, String coverUrl, int durationMs) {
    final titlePtr = title.toNativeUtf8();
    final artistPtr = artist.toNativeUtf8();
    final coverPtr = coverUrl.toNativeUtf8();
    try {
      _nowPlaying(titlePtr, artistPtr, coverPtr, durationMs);
    } finally {
      malloc.free(titlePtr);
      malloc.free(artistPtr);
      malloc.free(coverPtr);
    }
  }

  void setPlaying(bool playing) => _setPlaying(playing);

  void setPosition(int positionMs) => _setPosition(positionMs);

  void clear() => _clear();
}
