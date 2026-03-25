import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/local_song.dart';
import '../providers/local_library_providers.dart';

const permissionDeniedMessage = '未获得本地音频读取权限，请先授权媒体或存储权限。';

class LocalLibraryController extends AsyncNotifier<List<LocalSong>> {
  @override
  Future<List<LocalSong>> build() async {
    return const <LocalSong>[];
  }

  Future<void> scanLibrary() async {
    state = const AsyncLoading();
    final repository = ref.read(localMusicRepositoryProvider);
    final granted = await repository.requestPermission();
    if (!granted) {
      state = AsyncError(permissionDeniedMessage, StackTrace.current);
      return;
    }
    state = await AsyncValue.guard(repository.scanSongs);
  }

  Future<void> clearLibrary() async {
    state = const AsyncData(<LocalSong>[]);
  }
}
