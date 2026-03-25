import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_dio_provider.dart';
import '../../data/datasources/artist_detail_api_client.dart';
import '../../data/repositories/artist_detail_repository_impl.dart';
import '../../domain/entities/artist_detail_state.dart';
import '../../domain/repositories/artist_detail_repository.dart';
import '../controllers/artist_detail_controller.dart';

final artistDetailApiClientProvider = Provider<ArtistDetailApiClient>((ref) {
  final dio = ref.watch(apiDioProvider);
  return ArtistDetailApiClient(dio);
});

final artistDetailRepositoryProvider = Provider<ArtistDetailRepository>((ref) {
  final apiClient = ref.watch(artistDetailApiClientProvider);
  return ArtistDetailRepositoryImpl(apiClient);
});

final artistDetailControllerProvider =
    NotifierProvider.autoDispose<ArtistDetailController, ArtistDetailState>(
      ArtistDetailController.new,
    );
