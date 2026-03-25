import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../playlist/domain/entities/playlist_detail_state.dart';
import '../../domain/entities/user_playlist_detail_request.dart';
import '../../domain/repositories/user_playlist_detail_repository.dart';
import '../providers/user_playlist_detail_providers.dart';

class UserPlaylistDetailController
    extends AutoDisposeNotifier<PlaylistDetailState> {
  String _lastRequestKey = '';

  @override
  PlaylistDetailState build() {
    return PlaylistDetailState.initial;
  }

  Future<void> initialize(UserPlaylistDetailRequest request) async {
    if (_lastRequestKey == request.cacheKey && state.content != null) {
      return;
    }
    _lastRequestKey = request.cacheKey;
    await _load(request);
  }

  Future<void> retry(UserPlaylistDetailRequest request) async {
    await _load(request);
  }

  Future<void> updatePlaylist({
    required UserPlaylistDetailRequest request,
    required String name,
    required String cover,
    required String description,
  }) async {
    await _repository.updatePlaylist(
      id: request.id,
      name: name,
      cover: cover,
      description: description,
    );
    await _load(request);
  }

  Future<void> deletePlaylist(String id) {
    return _repository.deletePlaylist(id);
  }

  Future<void> _load(UserPlaylistDetailRequest request) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final content = await _repository.fetchDetail(request);
      state = state.copyWith(
        loading: false,
        content: content,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(loading: false, errorMessage: '$error');
    }
  }

  UserPlaylistDetailRepository get _repository {
    return ref.read(userPlaylistDetailRepositoryProvider);
  }
}
