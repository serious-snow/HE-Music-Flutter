import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_dio_provider.dart';
import '../../data/datasources/song_detail_api_client.dart';
import '../../data/repositories/song_detail_repository_impl.dart';
import '../../domain/entities/song_detail_state.dart';
import '../../domain/repositories/song_detail_repository.dart';
import '../controllers/song_detail_controller.dart';

final songDetailApiClientProvider = Provider<SongDetailApiClient>((ref) {
  final dio = ref.watch(apiDioProvider);
  return SongDetailApiClient(dio);
});

final songDetailRepositoryProvider = Provider<SongDetailRepository>((ref) {
  final apiClient = ref.watch(songDetailApiClientProvider);
  return SongDetailRepositoryImpl(apiClient);
});

final songDetailControllerProvider =
    NotifierProvider.autoDispose<SongDetailController, SongDetailState>(
      SongDetailController.new,
    );
