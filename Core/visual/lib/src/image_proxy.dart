import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Прокси картинок + постоянный диск-кэш. Внешние CDN (sndcdn и пр.) грузим не
/// напрямую, а через наш домен `images.scdinternal.site` (контракт: `GET <base>/`
/// + заголовок `X-Target: base64(url)`) — SNI запроса = наш домен, пассивный скан
/// РКН не банит по `sndcdn`; плюс кэшируем на диск (как Tauri permanent image
/// cache), чтобы не перекачивать каждый запуск. Свои домены и не-http — напрямую.
///
/// Конфигурируется оболочкой на старте ([configure]); по умолчанию выключено
/// (прямые запросы) — `visual` остаётся платформо-агностичным.
class ScImageProxy {
  static String? _base;
  static String? _cacheDir;

  static final HttpClient _http = HttpClient()
    ..connectionTimeout = const Duration(seconds: 15)
    ..userAgent = null;

  /// Хосты, которые НЕ проксируем (наши/локальные) — точное совпадение или суффикс.
  static const _whitelist = [
    'scdinternal.site',
    'localhost',
    '127.0.0.1',
  ];

  /// Включить прокси+диск-кэш картинок. [base] — напр. `https://images.scdinternal.site`;
  /// [cacheDir] — каталог кэша приложения (картинки лягут в `<cacheDir>/images`).
  static void configure({String? base, String? cacheDir}) {
    _base = (base != null && base.isNotEmpty) ? base : null;
    _cacheDir = cacheDir;
  }

  /// `ImageProvider` удалённой картинки: диск-кэш → прокси-фетч. Ключ кэша Flutter
  /// — оригинальный URL (картинки не схлопываются).
  static ImageProvider provider(String url) {
    if (_base == null || !url.startsWith('http') || _whitelisted(url)) {
      return NetworkImage(url);
    }
    return _CachedProxyImage(url, _base!, _cacheDir);
  }

  /// То же с даунскейлом декода до [cacheWidth] px (если задан).
  static ImageProvider sized(String url, int? cacheWidth) {
    final base = provider(url);
    return cacheWidth == null ? base : ResizeImage(base, width: cacheWidth);
  }

  static bool _whitelisted(String url) {
    final host = Uri.tryParse(url)?.host ?? '';
    return _whitelist.any((d) => host == d || host.endsWith('.$d'));
  }
}

/// Картинка через прокси с постоянным диск-кэшем. Ключ (==/hashCode) — оригинальный
/// URL; фетч идёт на `<base>/?u=...` с `X-Target`, байты кэшируются в файл по
/// `sha256(url)` и переиспользуются между запусками.
@immutable
class _CachedProxyImage extends ImageProvider<_CachedProxyImage> {
  const _CachedProxyImage(this.url, this.base, this.cacheDir);

  final String url;
  final String base;
  final String? cacheDir;

  @override
  Future<_CachedProxyImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_CachedProxyImage>(this);

  @override
  ImageStreamCompleter loadImage(
      _CachedProxyImage key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: key._loadCodec(decode),
      scale: 1.0,
      debugLabel: key.url,
    );
  }

  Future<ui.Codec> _loadCodec(ImageDecoderCallback decode) async {
    final bytes = await _bytes();
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    return decode(buffer);
  }

  Future<Uint8List> _bytes() async {
    final file = _cacheFile();
    if (file != null && await file.exists()) {
      try {
        final cached = await file.readAsBytes();
        if (cached.isNotEmpty) return cached;
      } catch (_) {}
    }
    final bytes = await _fetch();
    if (file != null) {
      unawaited(_writeAtomic(file, bytes));
    }
    return bytes;
  }

  File? _cacheFile() {
    final dir = cacheDir;
    if (dir == null) return null;
    final hash = sha256.convert(utf8.encode(url)).toString();
    return File('$dir/images/$hash');
  }

  Future<Uint8List> _fetch() async {
    final bytes = utf8.encode(url);
    final uri = Uri.parse('$base/?u=${base64Url.encode(bytes)}');
    final request = await ScImageProxy._http.getUrl(uri);
    request.headers.set('X-Target', base64.encode(bytes));
    final response = await request.close();
    if (response.statusCode != 200) {
      throw NetworkImageLoadException(
          statusCode: response.statusCode, uri: uri);
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in response) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  /// Запись в кэш атомарна (tmp → rename): прерванная запись не оставит битый файл.
  Future<void> _writeAtomic(File file, Uint8List bytes) async {
    try {
      await file.parent.create(recursive: true);
      final tmp = File('${file.path}.$pid.part');
      await tmp.writeAsBytes(bytes, flush: true);
      await tmp.rename(file.path);
    } catch (_) {}
  }

  @override
  bool operator ==(Object other) =>
      other is _CachedProxyImage && other.url == url;

  @override
  int get hashCode => url.hashCode;
}
