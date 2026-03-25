import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_dio_provider.dart';
import '../../data/datasources/playlist_plaza_api_client.dart';
import '../../domain/entities/playlist_plaza_state.dart';
import '../controllers/playlist_plaza_controller.dart';

final playlistPlazaApiClientProvider = Provider<PlaylistPlazaApiClient>((ref) {
  final dio = ref.watch(apiDioProvider);
  return PlaylistPlazaApiClient(dio);
});

final playlistPlazaControllerProvider =
    NotifierProvider.autoDispose<PlaylistPlazaController, PlaylistPlazaState>(
      PlaylistPlazaController.new,
    );
