import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../data/datasources/download_path_data_source.dart';
import '../../data/datasources/download_runner_data_source.dart';
import '../../data/datasources/download_task_store_data_source.dart';
import '../../data/services/download_lyric_resolver.dart';
import '../../data/services/download_metadata_writer.dart';
import '../../data/repositories/download_repository_impl.dart';
import '../../domain/entities/download_state.dart';
import '../../domain/repositories/download_repository.dart';
import '../../../lyrics/data/datasources/online_lyric_data_source.dart';
import '../../../online/presentation/providers/online_providers.dart';
import '../controllers/download_controller.dart';

final downloadPathDataSourceProvider = Provider<DownloadPathDataSource>((ref) {
  return DownloadPathDataSource();
});

final downloadRunnerDataSourceProvider = Provider<DownloadRunnerDataSource>((
  ref,
) {
  return DownloadRunnerDataSource();
});

final downloadTaskStoreDataSourceProvider = Provider<DownloadTaskStoreDataSource>(
  (ref) {
    return DownloadTaskStoreDataSource();
  },
);

final downloadRepositoryProvider = Provider<DownloadRepository>((ref) {
  final runnerDataSource = ref.read(downloadRunnerDataSourceProvider);
  final taskStoreDataSource = ref.read(downloadTaskStoreDataSourceProvider);
  final pathDataSource = ref.read(downloadPathDataSourceProvider);
  return DownloadRepositoryImpl(
    runnerDataSource,
    taskStoreDataSource,
    pathDataSource,
  );
});

final downloadMetadataWriterProvider = Provider<DownloadMetadataWriter>((ref) {
  final lyricDataSource = OnlineLyricDataSource(ref.read(onlineApiClientProvider));
  return DownloadMetadataWriter(
    lyricResolver: DownloadLyricResolver.fromDataSource(lyricDataSource),
    metadataAdapter: const AudioMetadataAdapter(),
    dio: Dio(),
  );
});

final downloadControllerProvider =
    NotifierProvider<DownloadController, DownloadState>(DownloadController.new);
