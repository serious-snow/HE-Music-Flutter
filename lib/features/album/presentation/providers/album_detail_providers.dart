import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_dio_provider.dart';
import '../../data/datasources/album_detail_api_client.dart';
import '../../data/repositories/album_detail_repository_impl.dart';
import '../../domain/entities/album_detail_state.dart';
import '../../domain/repositories/album_detail_repository.dart';
import '../controllers/album_detail_controller.dart';

final albumDetailApiClientProvider = Provider<AlbumDetailApiClient>((ref) {
  final dio = ref.watch(apiDioProvider);
  return AlbumDetailApiClient(dio);
});

final albumDetailRepositoryProvider = Provider<AlbumDetailRepository>((ref) {
  final apiClient = ref.watch(albumDetailApiClientProvider);
  return AlbumDetailRepositoryImpl(apiClient);
});

final albumDetailControllerProvider =
    NotifierProvider.autoDispose<AlbumDetailController, AlbumDetailState>(
      AlbumDetailController.new,
    );
