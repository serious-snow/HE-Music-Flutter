import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_dio_provider.dart';
import '../../data/datasources/playlist_detail_api_client.dart';
import '../../data/repositories/playlist_detail_repository_impl.dart';
import '../../domain/entities/playlist_detail_state.dart';
import '../../domain/repositories/playlist_detail_repository.dart';
import '../controllers/playlist_detail_controller.dart';

final playlistDetailApiClientProvider = Provider<PlaylistDetailApiClient>((
  ref,
) {
  final dio = ref.watch(apiDioProvider);
  return PlaylistDetailApiClient(dio);
});

final playlistDetailRepositoryProvider = Provider<PlaylistDetailRepository>((
  ref,
) {
  final apiClient = ref.watch(playlistDetailApiClientProvider);
  return PlaylistDetailRepositoryImpl(apiClient);
});

final playlistDetailControllerProvider =
    NotifierProvider.autoDispose<PlaylistDetailController, PlaylistDetailState>(
      PlaylistDetailController.new,
    );
