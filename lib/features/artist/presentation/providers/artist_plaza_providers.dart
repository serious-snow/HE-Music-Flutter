import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_dio_provider.dart';
import '../../data/datasources/artist_plaza_api_client.dart';
import '../../domain/entities/artist_plaza_state.dart';
import '../controllers/artist_plaza_controller.dart';

final artistPlazaApiClientProvider = Provider<ArtistPlazaApiClient>((ref) {
  final dio = ref.watch(apiDioProvider);
  return ArtistPlazaApiClient(dio);
});

final artistPlazaControllerProvider =
    NotifierProvider.autoDispose<ArtistPlazaController, ArtistPlazaState>(
      ArtistPlazaController.new,
    );
