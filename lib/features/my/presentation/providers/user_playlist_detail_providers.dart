import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_dio_provider.dart';
import '../../../playlist/domain/entities/playlist_detail_state.dart';
import '../../data/datasources/user_playlist_detail_api_client.dart';
import '../../data/repositories/user_playlist_detail_repository_impl.dart';
import '../../domain/repositories/user_playlist_detail_repository.dart';
import '../controllers/user_playlist_detail_controller.dart';

final userPlaylistDetailApiClientProvider =
    Provider<UserPlaylistDetailApiClient>((ref) {
      final dio = ref.watch(apiDioProvider);
      return UserPlaylistDetailApiClient(dio);
    });

final userPlaylistDetailRepositoryProvider =
    Provider<UserPlaylistDetailRepository>((ref) {
      final apiClient = ref.watch(userPlaylistDetailApiClientProvider);
      return UserPlaylistDetailRepositoryImpl(apiClient);
    });

final userPlaylistDetailControllerProvider =
    NotifierProvider.autoDispose<
      UserPlaylistDetailController,
      PlaylistDetailState
    >(UserPlaylistDetailController.new);
