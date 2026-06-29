import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../rust/data_social.dart';
import '../rust/dto_social.dart';

export '../rust/dto_social.dart'
    show WallpaperHitDto, WallpaperPageDto, WallpaperQueryDto;

/// Абсолютные пути сохранённых обоев из хранилища ядра (`<cache>/wallpapers/`).
/// Перечитывается после правок через [WallpaperController].
final savedWallpapersProvider =
    FutureProvider.autoDispose<List<String>>((ref) {
  return wallpaperList();
});

/// Командный контроллер обоев: качает/импортирует/удаляет файлы в ядре и
/// перечитывает [savedWallpapersProvider]. Своего состояния не держит.
final wallpaperControllerProvider =
    NotifierProvider<WallpaperController, void>(WallpaperController.new);

class WallpaperController extends Notifier<void> {
  @override
  void build() {}

  /// Скачать обоину по URL (через наш транспорт, браузерный UA). Возвращает путь
  /// сохранённого файла или `null` при ошибке.
  Future<String?> download(String url) async {
    try {
      final path = await wallpaperDownload(url: url);
      ref.invalidate(savedWallpapersProvider);
      return path;
    } catch (_) {
      return null;
    }
  }

  /// Импортировать локальный файл (file-picker) в хранилище. Возвращает путь
  /// в хранилище или `null` при ошибке.
  Future<String?> import(String srcPath) async {
    try {
      final path = await wallpaperImport(srcPath: srcPath);
      ref.invalidate(savedWallpapersProvider);
      return path;
    } catch (_) {
      return null;
    }
  }

  /// Удалить обоину и перечитать список.
  Future<void> remove(String path) async {
    await wallpaperRemove(path: path);
    ref.invalidate(savedWallpapersProvider);
  }
}

/// Одноразовый поиск онлайн-обоев (страница + курсор). Состояние держит сам
/// экран поиска — это тонкая обёртка над мостом.
Future<WallpaperPageDto> searchWallpapers(WallpaperQueryDto query) {
  return wallpaperSearch(query: query);
}
