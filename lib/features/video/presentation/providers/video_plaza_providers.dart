import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_dio_provider.dart';
import '../../data/datasources/video_plaza_api_client.dart';
import '../../domain/entities/video_plaza_state.dart';
import '../controllers/video_plaza_controller.dart';

final videoPlazaApiClientProvider = Provider<VideoPlazaApiClient>((ref) {
  final dio = ref.watch(apiDioProvider);
  return VideoPlazaApiClient(dio);
});

final videoPlazaControllerProvider =
    NotifierProvider.autoDispose<VideoPlazaController, VideoPlazaState>(
      VideoPlazaController.new,
    );
