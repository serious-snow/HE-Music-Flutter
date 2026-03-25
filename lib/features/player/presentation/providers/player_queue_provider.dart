import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/player_queue_data_source.dart';

final playerQueueDataSourceProvider = Provider<PlayerQueueDataSource>((ref) {
  return const PlayerQueueDataSource();
});
