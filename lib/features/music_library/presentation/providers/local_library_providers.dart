import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/audio/local_audio_metadata_reader.dart';
import '../../data/datasources/local_music_query_data_source.dart';
import '../../data/repositories/local_music_repository_impl.dart';
import '../../domain/entities/local_song.dart';
import '../../domain/repositories/local_music_repository.dart';
import '../controllers/local_library_controller.dart';

final localMusicQueryDataSourceProvider = Provider<LocalMusicQueryDataSource>((
  ref,
) {
  return LocalMusicQueryDataSource();
});

final localMusicRepositoryProvider = Provider<LocalMusicRepository>((ref) {
  final dataSource = ref.read(localMusicQueryDataSourceProvider);
  return LocalMusicRepositoryImpl(dataSource, LocalAudioMetadataReader());
});

final localLibraryControllerProvider =
    AsyncNotifierProvider<LocalLibraryController, List<LocalSong>>(
      LocalLibraryController.new,
    );
