import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../rust/data.dart';
import '../rust/dto.dart';

/// Редакционный пик (`featured`) — один трек или плейлист в зависимости от kind.
final featuredProvider = FutureProvider.autoDispose<FeaturedDto>((ref) {
  return featured();
});
