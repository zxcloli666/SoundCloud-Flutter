import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../providers/settings.dart';
import '../../providers/wallpaper.dart';
import 'settings_primitives.dart';
import 'wallpaper_search.dart';

/// Карточка «Фоновое изображение» (легаси `WallpaperCard.tsx`): сетка обоев
/// (нет/сохранённые/добавить файл/URL/поиск), затем слайдеры затемнения,
/// прозрачности и блюра, когда фон выбран. Скачка/импорт/удаление — в ядре
/// (`wallpaperControllerProvider`), путь файла кладём в настройки.
class WallpaperCard extends ConsumerStatefulWidget {
  const WallpaperCard({super.key});

  @override
  ConsumerState<WallpaperCard> createState() => _WallpaperCardState();
}

class _WallpaperCardState extends ConsumerState<WallpaperCard> {
  bool _showSearch = false;
  bool _showUrlInput = false;
  bool _downloading = false;
  final _urlCtrl = TextEditingController();

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  SettingsNotifier get _settings => ref.read(settingsProvider.notifier);
  WallpaperController get _ctrl =>
      ref.read(wallpaperControllerProvider.notifier);

  Future<void> _pickOnline(String url) async {
    final path = await _ctrl.download(url);
    if (path != null) _settings.setBackgroundImage(path);
  }

  Future<void> _pickFile() async {
    final res = await FilePicker.pickFiles(type: FileType.image);
    final src = res?.files.single.path;
    if (src == null) return;
    final path = await _ctrl.import(src);
    if (path != null) _settings.setBackgroundImage(path);
  }

  Future<void> _downloadUrl() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    setState(() => _downloading = true);
    final path = await _ctrl.download(url);
    if (!mounted) return;
    setState(() {
      _downloading = false;
      if (path != null) {
        _urlCtrl.clear();
        _showUrlInput = false;
      }
    });
    if (path != null) _settings.setBackgroundImage(path);
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(settingsProvider.select((s) => s.backgroundImage));
    final saved = ref.watch(savedWallpapersProvider).value ?? const [];

    return SettingsCard(
      title: 'Фоновое изображение',
      icon: LucideIcons.image,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _noneTile(current.isEmpty),
              for (final path in saved)
                _thumbTile(path, current == path),
              _addFileTile(),
              _urlTile(),
              _searchTile(),
            ],
          ),
          if (_showSearch) WallpaperSearch(onPick: _pickOnline),
          if (_showUrlInput) ...[
            const SizedBox(height: 16),
            _urlInputRow(),
          ],
          if (current.isNotEmpty) ...[
            const SizedBox(height: 20),
            _sliders(),
          ],
        ],
      ),
    );
  }

  Widget _noneTile(bool active) {
    return _Tile(
      active: active,
      onTap: () => _settings.setBackgroundImage(''),
      child: const Center(
        child: Text('Нет',
            style: TextStyle(
                color: Color(0x66FFFFFF),
                fontSize: 10,
                fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _thumbTile(String path, bool active) {
    final palette = ScTheme.paletteOf(context);
    return _Tile(
      active: active,
      onTap: () => _settings.setBackgroundImage(active ? '' : path),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image(
            image: ResizeImage(FileImage(File(path)), width: 160),
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) =>
                const ColoredBox(color: Color(0x08FFFFFF)),
          ),
          if (active)
            Container(
              color: const Color(0x1AFFFFFF),
              alignment: Alignment.center,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: palette.accentGlow, blurRadius: 8)],
                ),
              ),
            ),
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: () => _remove(path, active),
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  color: Color(0x99000000),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.x, size: 9, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _remove(String path, bool active) {
    _ctrl.remove(path);
    if (active) _settings.setBackgroundImage('');
  }

  Widget _addFileTile() {
    return _DashedTile(
      onTap: _pickFile,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('+',
              style: TextStyle(color: Color(0x4DFFFFFF), fontSize: 16)),
          SizedBox(height: 1),
          Text('Файл',
              style: TextStyle(color: Color(0x40FFFFFF), fontSize: 9)),
        ],
      ),
    );
  }

  Widget _urlTile() {
    return _DashedTile(
      active: _showUrlInput,
      onTap: () => setState(() => _showUrlInput = !_showUrlInput),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.link, size: 12, color: Color(0x4DFFFFFF)),
          SizedBox(height: 2),
          Text('URL', style: TextStyle(color: Color(0x40FFFFFF), fontSize: 9)),
        ],
      ),
    );
  }

  Widget _searchTile() {
    final palette = ScTheme.paletteOf(context);
    return _DashedTile(
      active: _showSearch,
      accentWhenActive: true,
      onTap: () => setState(() => _showSearch = !_showSearch),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.search,
              size: 12,
              color: _showSearch ? palette.accent : const Color(0x4DFFFFFF)),
          const SizedBox(height: 2),
          const Text('Поиск',
              style: TextStyle(color: Color(0x40FFFFFF), fontSize: 9)),
        ],
      ),
    );
  }

  Widget _urlInputRow() {
    final palette = ScTheme.paletteOf(context);
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 40,
            child: TextField(
              controller: _urlCtrl,
              onSubmitted: (_) => _downloadUrl(),
              style: const TextStyle(color: Color(0xD9FFFFFF), fontSize: 13),
              cursorColor: palette.accent,
              decoration: InputDecoration(
                isCollapsed: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                hintText: 'https://…',
                hintStyle:
                    const TextStyle(color: Color(0x33FFFFFF), fontSize: 13),
                filled: true,
                fillColor: const Color(0x0AFFFFFF),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0x0FFFFFFF)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: palette.accent),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _downloading ? null : _downloadUrl,
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0x14FFFFFF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x0FFFFFFF)),
            ),
            child: _downloading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Скачать',
                    style: TextStyle(
                        color: Color(0xB3FFFFFF),
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _sliders() {
    final s = ref.watch(settingsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _slider('Затемнение', s.backgroundDim, 0, 0.85,
            '${(s.backgroundDim * 100).round()}%', _settings.setBackgroundDim),
        _slider(
            'Прозрачность',
            s.backgroundOpacity,
            0,
            0.7,
            '${(s.backgroundOpacity * 100).round()}%',
            _settings.setBackgroundOpacity),
        _slider('Размытие', s.backgroundBlur, 0, 40,
            '${s.backgroundBlur.round()}px', _settings.setBackgroundBlur),
      ],
    );
  }

  Widget _slider(String label, double value, double min, double max,
      String readout, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: Color(0x80FFFFFF),
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
              Text(readout,
                  style: const TextStyle(
                      color: Color(0x4DFFFFFF), fontSize: 12)),
            ],
          ),
          SettingsSlider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// База плитки 80×56 с акцентной рамкой при выборе (легаси `w-20 h-14`).
class _Tile extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  final Widget child;

  const _Tile({required this.active, required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 80,
          height: 56,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0x05FFFFFF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? const Color(0x66FFFFFF) : const Color(0x0FFFFFFF),
              width: 2,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Пунктирная плитка действия (добавить/URL/поиск).
class _DashedTile extends StatelessWidget {
  final bool active;
  final bool accentWhenActive;
  final VoidCallback onTap;
  final Widget child;

  const _DashedTile({
    required this.onTap,
    required this.child,
    this.active = false,
    this.accentWhenActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ScTheme.paletteOf(context);
    final border = accentWhenActive && active
        ? palette.accent
        : (active ? const Color(0x33FFFFFF) : const Color(0x1AFFFFFF));
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 80,
          height: 56,
          decoration: BoxDecoration(
            color: accentWhenActive && active
                ? palette.accentGlow
                : (active ? const Color(0x0AFFFFFF) : Colors.transparent),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border, width: 2),
          ),
          child: child,
        ),
      ),
    );
  }
}
