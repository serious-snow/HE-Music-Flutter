import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_dio_provider.dart';
import '../../../online/domain/entities/online_platform.dart';
import '../../../online/presentation/providers/online_providers.dart';
import '../../data/datasources/ranking_api_client.dart';
import '../../data/repositories/ranking_repository_impl.dart';
import '../../domain/entities/ranking_group.dart';
import '../../domain/repositories/ranking_repository.dart';

final rankingApiClientProvider = Provider<RankingApiClient>((ref) {
  final dio = ref.watch(apiDioProvider);
  return RankingApiClient(dio);
});

final rankingRepositoryProvider = Provider<RankingRepository>((ref) {
  final api = ref.watch(rankingApiClientProvider);
  return RankingRepositoryImpl(api);
});

final rankingPlatformsProvider = FutureProvider<List<OnlinePlatform>>((
  ref,
) async {
  final globalAsync = ref.watch(onlinePlatformsProvider);
  final cached = globalAsync.valueOrNull;
  if (cached != null && cached.isNotEmpty) {
    return cached
        .where((platform) => platform.available)
        .toList(growable: false);
  }
  final loaded = await ref
      .read(onlinePlatformsProvider.notifier)
      .ensureLoaded(forceRefresh: true);
  return loaded.where((platform) => platform.available).toList(growable: false);
});

final rankingGroupsProvider = FutureProvider.family<List<RankingGroup>, String>(
  (ref, platform) async {
    final repo = ref.read(rankingRepositoryProvider);
    return repo.fetchRankingGroups(platform: platform);
  },
);
