import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/download_file_data_source.dart';
import '../../data/datasources/download_path_data_source.dart';
import '../../data/repositories/download_repository_impl.dart';
import '../../domain/entities/download_state.dart';
import '../../domain/repositories/download_repository.dart';
import '../controllers/download_controller.dart';

final downloadDioProvider = Provider<Dio>((ref) {
  return Dio();
});

final downloadFileDataSourceProvider = Provider<DownloadFileDataSource>((ref) {
  final dio = ref.read(downloadDioProvider);
  return DownloadFileDataSource(dio);
});

final downloadPathDataSourceProvider = Provider<DownloadPathDataSource>((ref) {
  return DownloadPathDataSource();
});

final downloadRepositoryProvider = Provider<DownloadRepository>((ref) {
  final fileDataSource = ref.read(downloadFileDataSourceProvider);
  final pathDataSource = ref.read(downloadPathDataSourceProvider);
  return DownloadRepositoryImpl(fileDataSource, pathDataSource);
});

final downloadControllerProvider =
    NotifierProvider<DownloadController, DownloadState>(DownloadController.new);
