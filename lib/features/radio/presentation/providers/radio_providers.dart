import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/radio_api_client.dart';
import '../../../../core/network/api_dio_provider.dart';
import '../controllers/radio_plaza_controller.dart';

final radioApiClientProvider = Provider<RadioApiClient>((ref) {
  final dio = ref.watch(apiDioProvider);
  return RadioApiClient(dio);
});

final radioPlazaControllerProvider =
    NotifierProvider.autoDispose<RadioPlazaController, RadioPlazaState>(
      RadioPlazaController.new,
    );
