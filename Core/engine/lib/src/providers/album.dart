import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../rust/data.dart';
import '../rust/dto.dart';

/// Полный альбом (`album_detail`) — шапка, артисты, треклист.
final albumDetailProvider =
    FutureProvider.autoDispose.family<AlbumDetailDto, String>((ref, id) {
  return albumDetail(id: id);
});
