import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_dio_provider.dart';
import '../../data/datasources/home_discover_api_client.dart';
import '../../domain/entities/home_discover_state.dart';
import '../controllers/home_discover_controller.dart';

final homeDiscoverApiClientProvider = Provider<HomeDiscoverApiClient>((ref) {
  final dio = ref.watch(apiDioProvider);
  return HomeDiscoverApiClient(dio);
});

final homeDiscoverControllerProvider =
    NotifierProvider<HomeDiscoverController, HomeDiscoverState>(
      HomeDiscoverController.new,
    );
