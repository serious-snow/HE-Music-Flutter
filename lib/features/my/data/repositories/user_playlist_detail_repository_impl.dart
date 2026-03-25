import '../../../playlist/domain/entities/playlist_detail_content.dart';
import '../../domain/entities/user_playlist_detail_request.dart';
import '../../domain/repositories/user_playlist_detail_repository.dart';
import '../datasources/user_playlist_detail_api_client.dart';

class UserPlaylistDetailRepositoryImpl implements UserPlaylistDetailRepository {
  const UserPlaylistDetailRepositoryImpl(this._apiClient);

  final UserPlaylistDetailApiClient _apiClient;

  @override
  Future<PlaylistDetailContent> fetchDetail(UserPlaylistDetailRequest request) {
    return _apiClient.fetchDetail(request);
  }

  @override
  Future<void> updatePlaylist({
    required String id,
    required String name,
    required String cover,
    required String description,
  }) {
    return _apiClient.updatePlaylist(
      id: id,
      name: name,
      cover: cover,
      description: description,
    );
  }

  @override
  Future<void> deletePlaylist(String id) {
    return _apiClient.deletePlaylist(id);
  }
}
