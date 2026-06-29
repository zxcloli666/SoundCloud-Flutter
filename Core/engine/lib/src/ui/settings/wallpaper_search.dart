import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../providers/settings.dart';
import '../../providers/wallpaper.dart';
import 'settings_primitives.dart';

/// Источники обоев и их возможности (легаси `lib/wallpapers.ts`).
enum WpSource { wallhaven, pinterest, konachan, safebooru }

class _Caps {
  final bool category;
  final bool color;
  final bool tagBased;
  final bool adult;
  final bool adultNeedsKey;
  const _Caps({
    this.category = false,
    this.color = false,
    this.tagBased = false,
    this.adult = false,
    this.adultNeedsKey = false,
  });
}

const _sourceMeta = <WpSource, ({String label, _Caps caps})>{
  WpSource.wallhaven: (
    label: 'Wallhaven',
    caps: _Caps(category: true, color: true, adult: true, adultNeedsKey: true),
  ),
  WpSource.pinterest: (label: 'Pinterest', caps: _Caps()),
  WpSource.konachan: (
    label: 'Konachan',
    caps: _Caps(tagBased: true, adult: true),
  ),
  WpSource.safebooru: (label: 'Safebooru', caps: _Caps(tagBased: true)),
};

/// Фиксированная палитра Wallhaven (единственные значения параметра `colors`).
const _wpColors = [
  '660000', '990000', 'cc0000', 'cc3333', 'ea4c88', '993399', '663399',
  '333399', '0066cc', '0099cc', '66cccc', '77cc33', '669900', '336600',
  '666600', '999900', 'cccc33', 'ffff00', 'ffcc33', 'ff9900', 'ff6600',
  'cc6633', '996633', '663300', '000000', '999999', 'cccccc', 'ffffff',
  '424153',
];

/// Встроенный поиск онлайн-обоев (легаси `WallpaperSearch.tsx`). Wallhaven
/// (категории + цвет), Konachan/Safebooru (по тегам), Pinterest. Выбор →
/// родитель качает и применяет. 18+ опт-ин; NSFW Wallhaven требует ключ.
class WallpaperSearch extends ConsumerStatefulWidget {
  final Future<void> Function(String fullUrl) onPick;

  const WallpaperSearch({super.key, required this.onPick});

  @override
  ConsumerState<WallpaperSearch> createState() => _WallpaperSearchState();
}

class _WallpaperSearchState extends ConsumerState<WallpaperSearch> {
  WpSource _source = WpSource.wallhaven;
  String _query = '';
  String _category = 'anime';
  String? _color;
  bool _adult = false;
  List<WallpaperHitDto> _items = const [];
  String? _cursor;
  bool _loading = false;
  bool _error = false;
  String? _picking;
  int _reqId = 0;
  Timer? _debounce;
  final _queryCtrl = TextEditingController();

  _Caps get _caps => _sourceMeta[_source]!.caps;

  String get _apiKey => ref.read(settingsProvider).wallhavenApiKey;

  bool get _adultBlocked =>
      _adult && _caps.adultNeedsKey && _apiKey.trim().isEmpty;

  @override
  void initState() {
    super.initState();
    _scheduleSearch(immediate: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryCtrl.dispose();
    super.dispose();
  }

  void _scheduleSearch({bool immediate = false}) {
    _debounce?.cancel();
    final delay = immediate || (_query.isEmpty && _apiKey.trim().isEmpty)
        ? Duration.zero
        : const Duration(milliseconds: 420);
    _debounce = Timer(delay, () => _run(null, append: false));
  }

  Future<void> _run(String? cursor, {required bool append}) async {
    final id = ++_reqId;
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final res = await searchWallpapers(WallpaperQueryDto(
        source: _source.name,
        query: _query,
        category: _caps.category ? _category : null,
        color: _color,
        cursor: cursor,
        adult: _adult,
        apiKey: _apiKey.isEmpty ? null : _apiKey,
      ));
      if (id != _reqId) return;
      setState(() {
        _cursor = res.cursor;
        _items = append ? [..._items, ...res.items] : res.items;
      });
    } catch (_) {
      if (id != _reqId) return;
      setState(() {
        _error = true;
        if (!append) _items = const [];
      });
    } finally {
      if (id == _reqId) setState(() => _loading = false);
    }
  }

  Future<void> _pick(WallpaperHitDto hit) async {
    if (_picking != null) return;
    setState(() => _picking = hit.id);
    try {
      await widget.onPick(hit.full);
    } finally {
      if (mounted) setState(() => _picking = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x33000000),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x0FFFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingsSegmented<WpSource>(
            value: _source,
            columns: 4,
            onChanged: (s) => setState(() {
              _source = s;
              _color = null;
              _scheduleSearch(immediate: true);
            }),
            options: [
              for (final e in _sourceMeta.entries)
                SegmentedOption(e.key, e.value.label),
            ],
          ),
          const SizedBox(height: 14),
          _queryRow(),
          if (_caps.color) ...[const SizedBox(height: 14), _colorRow()],
          if (_caps.adult) ...[const SizedBox(height: 14), _adultRow()],
          const SizedBox(height: 14),
          _results(),
          const SizedBox(height: 12),
          _footer(),
        ],
      ),
    );
  }

  Widget _queryRow() {
    final palette = ScTheme.paletteOf(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SizedBox(
            height: 40,
            child: TextField(
              controller: _queryCtrl,
              onChanged: (v) {
                _query = v;
                _scheduleSearch();
              },
              style: const TextStyle(color: Color(0xD9FFFFFF), fontSize: 13),
              cursorColor: palette.accent,
              decoration: InputDecoration(
                isCollapsed: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                prefixIcon: const Icon(LucideIcons.search,
                    size: 15, color: Color(0x59FFFFFF)),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 34, minHeight: 0),
                hintText: _caps.tagBased ? 'теги через пробел' : 'Поиск обоев…',
                hintStyle: const TextStyle(color: Color(0x4DFFFFFF), fontSize: 13),
                filled: true,
                fillColor: const Color(0x0DFFFFFF),
                enabledBorder: _fieldBorder(const Color(0x14FFFFFF)),
                focusedBorder: _fieldBorder(palette.accent),
              ),
            ),
          ),
        ),
        if (_caps.category) ...[
          const SizedBox(width: 10),
          SizedBox(
            width: 240,
            child: SettingsSegmented<String>(
              value: _category,
              columns: 3,
              onChanged: (c) => setState(() {
                _category = c;
                _scheduleSearch(immediate: true);
              }),
              options: const [
                SegmentedOption('anime', 'Аниме'),
                SegmentedOption('general', 'Общее'),
                SegmentedOption('people', 'Люди'),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _colorRow() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Padding(
          padding: EdgeInsets.only(right: 2),
          child: Text('Цвет',
              style: TextStyle(color: Color(0x66FFFFFF), fontSize: 11)),
        ),
        _anyColorChip(),
        for (final c in _wpColors) _colorDot(c),
      ],
    );
  }

  Widget _anyColorChip() {
    final on = _color == null;
    return GestureDetector(
      onTap: () => setState(() {
        _color = null;
        _scheduleSearch(immediate: true);
      }),
      child: Container(
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? const Color(0x14FFFFFF) : Colors.transparent,
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(
              color: on ? const Color(0x4DFFFFFF) : const Color(0x14FFFFFF)),
        ),
        child: Text('Любой',
            style: TextStyle(
                color: on ? Colors.white : const Color(0x73FFFFFF),
                fontSize: 10.5,
                fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _colorDot(String hex) {
    final on = _color == hex;
    final color = Color(int.parse('FF$hex', radix: 16));
    return GestureDetector(
      onTap: () => setState(() {
        _color = on ? null : hex;
        _scheduleSearch(immediate: true);
      }),
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
              color: on ? Colors.white : const Color(0x2EFFFFFF),
              width: on ? 2 : 1),
          boxShadow:
              on ? [BoxShadow(color: color, blurRadius: 12)] : null,
        ),
      ),
    );
  }

  Widget _adultRow() {
    final palette = ScTheme.paletteOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () => setState(() {
                _adult = !_adult;
                _scheduleSearch(immediate: true);
              }),
              child: Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _adult ? palette.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(9999),
                  border: Border.all(
                      color:
                          _adult ? Colors.transparent : const Color(0x1AFFFFFF)),
                ),
                child: Text('18+',
                    style: TextStyle(
                        color: _adult
                            ? palette.accentContrast
                            : const Color(0x73FFFFFF),
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 10),
            Text(_adult ? 'Контент 18+ включён' : 'Только безопасный контент',
                style: const TextStyle(color: Color(0x59FFFFFF), fontSize: 11)),
          ],
        ),
        if (_caps.adultNeedsKey && _adult) ...[
          const SizedBox(height: 10),
          _keyField(),
        ],
      ],
    );
  }

  Widget _keyField() {
    final palette = ScTheme.paletteOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 36,
          child: TextField(
            obscureText: true,
            controller: TextEditingController(text: _apiKey)
              ..selection = TextSelection.collapsed(offset: _apiKey.length),
            onSubmitted: (v) {
              ref.read(settingsProvider.notifier).setWallhavenApiKey(v.trim());
              _scheduleSearch(immediate: true);
            },
            onChanged: (v) =>
                ref.read(settingsProvider.notifier).setWallhavenApiKey(v.trim()),
            style: const TextStyle(
                color: Color(0xD9FFFFFF), fontSize: 12, fontFamily: 'monospace'),
            cursorColor: palette.accent,
            decoration: InputDecoration(
              isCollapsed: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              prefixIcon: const Icon(LucideIcons.lock,
                  size: 13, color: Color(0x4DFFFFFF)),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 32, minHeight: 0),
              hintText: 'Wallhaven API-ключ',
              hintStyle: const TextStyle(color: Color(0x40FFFFFF), fontSize: 12),
              filled: true,
              fillColor: const Color(0x0DFFFFFF),
              enabledBorder: _fieldBorder(
                  _adultBlocked ? const Color(0x66FBBF24) : const Color(0x14FFFFFF)),
              focusedBorder: _fieldBorder(
                  _adultBlocked ? const Color(0xB3FBBF24) : palette.accent),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            _adultBlocked
                ? 'Для NSFW нужен личный ключ Wallhaven'
                : 'Ключ из профиля Wallhaven — разблокирует NSFW',
            style: const TextStyle(color: Color(0x4DFFFFFF), fontSize: 10.5),
          ),
        ),
      ],
    );
  }

  Widget _results() {
    if (_error) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
            child: Text('Не удалось загрузить',
                style: TextStyle(color: Color(0xCCF87171), fontSize: 12.5))),
      );
    }
    if (_items.isEmpty && !_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
            child: Text('Ничего не найдено',
                style: TextStyle(color: Color(0x59FFFFFF), fontSize: 12.5))),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 16 / 9,
      ),
      itemBuilder: (_, i) => _resultTile(_items[i]),
    );
  }

  Widget _resultTile(WallpaperHitDto hit) {
    final palette = ScTheme.paletteOf(context);
    final picking = _picking == hit.id;
    return GestureDetector(
      onTap: () => _pick(hit),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image(
              image: ScImageProxy.sized(hit.thumb, 480),
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) =>
                  const ColoredBox(color: Color(0x08FFFFFF)),
            ),
            if (picking)
              Container(
                color: const Color(0x66000000),
                alignment: Alignment.center,
                child: const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                ),
              ),
            if (hit.resolution.isNotEmpty)
              Positioned(
                right: 4,
                bottom: 4,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0x8C000000),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(hit.resolution,
                      style: const TextStyle(
                          color: Color(0xD9FFFFFF),
                          fontSize: 9,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _pick(hit),
                  hoverColor: palette.accentGlow,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _footer() {
    final meta = _sourceMeta[_source]!;
    final tag = _adult && !_adultBlocked ? '18+' : 'SFW';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('${meta.label} · $tag',
            style: const TextStyle(color: Color(0x40FFFFFF), fontSize: 10.5)),
        if (_loading)
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Color(0x66FFFFFF)),
          )
        else if (_cursor != null && _items.isNotEmpty)
          GestureDetector(
            onTap: () => _run(_cursor, append: true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0x0FFFFFFF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x0FFFFFFF)),
              ),
              child: const Text('Ещё',
                  style: TextStyle(
                      color: Color(0xB3FFFFFF),
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
          ),
      ],
    );
  }

  static OutlineInputBorder _fieldBorder(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color),
      );
}
