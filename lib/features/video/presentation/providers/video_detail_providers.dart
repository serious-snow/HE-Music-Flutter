import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_dio_provider.dart';
import '../../data/datasources/video_detail_api_client.dart';
import '../../data/repositories/video_detail_repository_impl.dart';
import '../../domain/entities/video_detail_state.dart';
import '../../domain/repositories/video_detail_repository.dart';
import '../controllers/video_detail_controller.dart';

final videoDetailApiClientProvider = Provider<VideoDetailApiClient>((ref) {
  final dio = ref.watch(apiDioProvider);
  return VideoDetailApiClient(dio);
});

final videoDetailRepositoryProvider = Provider<VideoDetailRepository>((ref) {
  final apiClient = ref.watch(videoDetailApiClientProvider);
  return VideoDetailRepositoryImpl(apiClient);
});

final videoDetailControllerProvider =
    NotifierProvider.autoDispose<VideoDetailController, VideoDetailState>(
      VideoDetailController.new,
    );
