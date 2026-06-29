import 'package:sc_visual/sc_visual.dart';

import '../rust/api.dart';

/// Рейтинг-мета трека (`_scd_meta`) для общего бейджа [TrackStatusBadge]
/// (A/C/F/·/!). ЕДИНЫЙ источник — чтобы бейдж был на ВСЕХ карточках/рядах треков
/// (полки реки, архив, библиотека, артист-волна, похожие). Не дублировать инлайном.
TrackStatusMeta trackScdMeta(TrackDto t) => TrackStatusMeta(
      storageState: t.storageState,
      storageQuality: t.storageQuality,
      indexState: t.indexState,
    );
