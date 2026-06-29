import 'package:sc_visual/sc_visual.dart' show hashStr;

/// Детерминированная пере-тасовка каталога (легаси §3.3 `seededOrder`): LCG-Fisher-Yates.
/// Seed 0 сохраняет порядок бэкенда для первого рендера; reshuffle поднимает nonce
/// (без рефетча). Seed для nonce>0 = `hashStr("<bucket>:<nonce>")`.
List<T> seededOrder<T>(List<T> items, int seed) {
  if (seed == 0) return items;
  final a = List<T>.of(items);
  var s = seed & 0xFFFFFFFF;
  for (var i = a.length - 1; i > 0; i--) {
    s = (s * 1664525 + 1013904223) & 0xFFFFFFFF;
    final j = s % (i + 1);
    final tmp = a[i];
    a[i] = a[j];
    a[j] = tmp;
  }
  return a;
}

/// Seed пере-тасовки: 0 на nonce==0 (порядок бэка), иначе `hashStr("bucket:nonce")`.
int reshuffleSeed(String bucket, int nonce) =>
    nonce == 0 ? 0 : hashStr('$bucket:$nonce');
