import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/audio/local_audio_metadata_reader.dart';
import '../../../online/presentation/providers/online_providers.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../../data/datasources/demo_lyric_data_source.dart';
import '../../data/datasources/online_lyric_data_source.dart';
import '../../data/repositories/lyric_repository_impl.dart';
import '../../domain/entities/lyric_document.dart';
import '../../domain/entities/lyric_request.dart';
import '../../domain/repositories/lyric_repository.dart';

class CurrentLyricStoreState {
  const CurrentLyricStoreState({
    this.request,
    this.document = const AsyncData<LyricDocument>(LyricDocument.empty()),
  });

  final LyricRequest? request;
  final AsyncValue<LyricDocument> document;

  CurrentLyricStoreState copyWith({
    LyricRequest? request,
    AsyncValue<LyricDocument>? document,
    bool clearRequest = false,
  }) {
    return CurrentLyricStoreState(
      request: clearRequest ? null : request ?? this.request,
      document: document ?? this.document,
    );
  }
}

class CurrentLyricStore extends Notifier<CurrentLyricStoreState> {
  int _requestVersion = 0;

  @override
  CurrentLyricStoreState build() {
    return const CurrentLyricStoreState();
  }

  Future<void> preload(LyricRequest request) async {
    if (state.request == request &&
        state.document is AsyncData<LyricDocument>) {
      return;
    }
    final requestVersion = ++_requestVersion;
    state = CurrentLyricStoreState(
      request: request,
      document: const AsyncLoading<LyricDocument>(),
    );
    final document = await AsyncValue.guard(() async {
      final repository = ref.read(lyricRepositoryProvider);
      return repository.fetchLyrics(
        trackId: request.trackId,
        platform: request.platform,
        localPath: request.localPath,
      );
    });
    if (requestVersion != _requestVersion || state.request != request) {
      return;
    }
    state = state.copyWith(document: document);
  }

  void clear() {
    _requestVersion += 1;
    state = const CurrentLyricStoreState();
  }
}

final lyricDataSourceProvider = Provider<DemoLyricDataSource>((ref) {
  return DemoLyricDataSource();
});

final onlineLyricDataSourceProvider = Provider<OnlineLyricDataSource>((ref) {
  final apiClient = ref.read(onlineApiClientProvider);
  return OnlineLyricDataSource(apiClient);
});

final lyricRepositoryProvider = Provider<LyricRepository>((ref) {
  final onlineDataSource = ref.read(onlineLyricDataSourceProvider);
  final demoDataSource = ref.read(lyricDataSourceProvider);
  return LyricRepositoryImpl(
    onlineDataSource,
    demoDataSource,
    LocalAudioMetadataReader(),
  );
});

final currentLyricStoreProvider =
    NotifierProvider<CurrentLyricStore, CurrentLyricStoreState>(
      CurrentLyricStore.new,
    );

final currentLyricRequestProvider = Provider<LyricRequest?>((ref) {
  final track = ref.watch(
    playerControllerProvider.select((state) => state.currentTrack),
  );
  if (track == null) {
    return null;
  }
  return LyricRequest(
    trackId: track.id,
    platform: track.platform,
    localPath: track.path,
  );
});

final currentLyricDocumentProvider = Provider<AsyncValue<LyricDocument>>((ref) {
  return ref.watch(currentLyricStoreProvider.select((state) => state.document));
});

final lyricPositionProvider = Provider<Duration>((ref) {
  return ref.watch(playerControllerProvider.select((state) => state.position));
});

final lyricsPrefetchBindingProvider = Provider<void>((ref) {
  ref.listen<LyricRequest?>(currentLyricRequestProvider, (previous, next) {
    final notifier = ref.read(currentLyricStoreProvider.notifier);
    if (next == null) {
      notifier.clear();
      return;
    }
    notifier.preload(next);
  });
});
