import '../../../playlist/domain/entities/playlist_detail_content.dart';
import '../entities/user_playlist_detail_request.dart';

abstract interface class UserPlaylistDetailRepository {
  Future<PlaylistDetailContent> fetchDetail(UserPlaylistDetailRequest request);
  Future<void> updatePlaylist({
    required String id,
    required String name,
    required String cover,
    required String description,
  });
  Future<void> deletePlaylist(String id);
}
