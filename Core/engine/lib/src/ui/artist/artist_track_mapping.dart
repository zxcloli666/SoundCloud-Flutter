import 'package:sc_visual/sc_visual.dart';

import '../../rust/api.dart';

/// `TrackDto` → `TrackRowData` для строк вкладок артиста. Заголовок/артист уже
/// разрешены мостом (§5.1 живёт в бэке); здесь только маппинг полей строки:
/// бейдж `_scd_meta`, тип загрузки (cover → UploadKind.cover), лайк, статистика.
TrackRowData artistTrackRow(TrackDto t) {
  return TrackRowData(
    title: t.title,
    artistLine: t.artistName,
    artworkUrl: t.artworkUrl,
    durationMs: t.durationMs.toInt(),
    meta: TrackStatusMeta(
      storageState: t.storageState,
      storageQuality: t.storageQuality,
      indexState: t.indexState,
    ),
    uploadKind: t.isCover ? UploadKind.cover : null,
    liked: t.userFavorite ?? false,
    playbackCount: t.playCount?.toInt(),
    likesCount: t.likesCount?.toInt(),
  );
}
