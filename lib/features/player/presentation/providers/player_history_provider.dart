import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/player_history_data_source.dart';

final playerHistoryDataSourceProvider = Provider<PlayerHistoryDataSource>((
  ref,
) {
  return const PlayerHistoryDataSource();
});
