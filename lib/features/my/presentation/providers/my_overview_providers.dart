import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_dio_provider.dart';
import '../../data/datasources/my_overview_api_client.dart';
import '../../data/repositories/my_overview_repository_impl.dart';
import '../../domain/entities/my_overview_state.dart';
import '../../domain/repositories/my_overview_repository.dart';
import '../controllers/my_overview_controller.dart';

final myOverviewApiClientProvider = Provider<MyOverviewApiClient>((ref) {
  final dio = ref.watch(apiDioProvider);
  return MyOverviewApiClient(dio);
});

final myOverviewRepositoryProvider = Provider<MyOverviewRepository>((ref) {
  final apiClient = ref.watch(myOverviewApiClientProvider);
  return MyOverviewRepositoryImpl(apiClient);
});

final myOverviewControllerProvider =
    NotifierProvider<MyOverviewController, MyOverviewState>(
      MyOverviewController.new,
    );
