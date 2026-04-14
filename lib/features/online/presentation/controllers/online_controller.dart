import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../core/error/app_exception.dart';
import '../../../../core/error/failure.dart';
import '../../../my/domain/entities/my_favorite_type.dart';
import '../../../my/presentation/providers/favorite_collection_status_providers.dart';
import '../../../my/presentation/providers/favorite_song_status_providers.dart';
import '../../domain/entities/online_feature_state.dart';
import '../providers/online_providers.dart';

class SongUrlResolution {
  const SongUrlResolution({required this.url, required this.format});

  final String url;
  final String format;
}

class OnlineController extends Notifier<OnlineFeatureState> {
  @override
  OnlineFeatureState build() {
    return OnlineFeatureState.initial;
  }

  Future<void> login({
    required String username,
    required String password,
  }) async {
    _validateNotEmpty(username, 'Username is required.');
    _validateNotEmpty(password, 'Password is required.');
    await _runAction(() async {
      final client = ref.read(onlineApiClientProvider);
      final response = await client.login(
        username: username,
        password: password,
      );
      final token = _findToken(response);
      if (token == null || token.isEmpty) {
        throw const AppException(
          NetworkFailure('Token missing in login response.'),
        );
      }
      await _completeLoginWithToken(token);
      state = state.copyWith(message: 'Login success.', clearError: true);
    });
  }

  Future<void> loginWithToken(String token) async {
    _validateNotEmpty(token, 'Token is required.');
    await _runAction(() async {
      await _completeLoginWithToken(token);
      state = state.copyWith(message: 'Login success.', clearError: true);
    });
  }

  Future<void> fetchProfile() async {
    await _runAction(() async {
      final client = ref.read(onlineApiClientProvider);
      final profile = await client.fetchProfile();
      await ref.read(favoriteSongStatusProvider.notifier).refresh();
      await ref.read(favoriteCollectionStatusProvider.notifier).refresh();
      state = state.copyWith(
        profile: profile,
        message: 'Profile fetched.',
        clearError: true,
      );
    });
  }

  Future<void> searchMusic({
    required String keyword,
    required String platform,
    String type = 'song',
  }) async {
    _validateNotEmpty(keyword, 'Keyword is required.');
    _validateNotEmpty(platform, 'Platform is required.');
    await _runAction(() async {
      final client = ref.read(onlineApiClientProvider);
      final results = await client.searchMusic(
        keyword: keyword,
        platform: platform,
        type: type,
      );
      state = state.copyWith(
        searchResults: results,
        message: 'Search completed: ${results.length} items.',
        clearError: true,
      );
    });
  }

  Future<String> fetchSongUrl({
    required String songId,
    required String platform,
    int? quality,
    String? format,
  }) async {
    final resolution = await resolveSongUrl(
      songId: songId,
      platform: platform,
      quality: quality,
      format: format,
    );
    return resolution.url;
  }

  Future<SongUrlResolution> resolveSongUrl({
    required String songId,
    required String platform,
    int? quality,
    String? format,
  }) async {
    _validateNotEmpty(songId, 'Song id is required.');
    _validateNotEmpty(platform, 'Platform is required.');
    final client = ref.read(onlineApiClientProvider);
    final payload = await client.fetchSongUrl(
      songId: songId,
      platform: platform,
      quality: quality,
      format: format,
    );
    final url = '${payload['url'] ?? ''}'.trim();
    if (url.isEmpty) {
      throw const AppException(
        NetworkFailure('Invalid /v1/song/url response: missing url'),
      );
    }
    final requestedFormat = (format ?? '').trim();
    final resolvedFormat = '${payload['format'] ?? ''}'.trim();
    return SongUrlResolution(
      url: url,
      format: resolvedFormat.isNotEmpty
          ? resolvedFormat
          : (requestedFormat.isNotEmpty ? requestedFormat : 'mp3'),
    );
  }

  Future<void> createPlaylist(String name) async {
    _validateNotEmpty(name, 'Playlist name is required.');
    await _runAction(() async {
      final client = ref.read(onlineApiClientProvider);
      await client.createPlaylist(name);
      state = state.copyWith(message: 'Playlist created.', clearError: true);
    });
  }

  Future<void> togglePlaylistFavorite({
    required String playlistId,
    required String platform,
    required bool like,
    String? name,
    String? cover,
    String? creator,
  }) async {
    _validateNotEmpty(playlistId, 'Playlist id is required.');
    _validateNotEmpty(platform, 'Platform is required.');
    await _runAction(() async {
      final client = ref.read(onlineApiClientProvider);
      await client.togglePlaylistFavorite(
        playlistId: playlistId,
        platform: platform,
        like: like,
        name: name,
        cover: cover,
        creator: creator,
      );
      final status = ref.read(favoriteCollectionStatusProvider.notifier);
      if (like) {
        status.add(
          type: MyFavoriteType.playlists,
          id: playlistId,
          platform: platform,
        );
      } else {
        status.remove(
          type: MyFavoriteType.playlists,
          id: playlistId,
          platform: platform,
        );
      }
      final action = like ? 'favorited' : 'unfavorited';
      state = state.copyWith(message: 'Playlist $action.', clearError: true);
    });
  }

  Future<void> toggleSongFavorite({
    required String songId,
    required String platform,
    required bool like,
  }) async {
    _validateNotEmpty(songId, 'Song id is required.');
    _validateNotEmpty(platform, 'Platform is required.');
    await _runAction(() async {
      final client = ref.read(onlineApiClientProvider);
      await client.toggleSongFavorite(
        songId: songId,
        platform: platform,
        like: like,
      );
      final status = ref.read(favoriteSongStatusProvider.notifier);
      if (like) {
        status.addSong(songId: songId, platform: platform);
      } else {
        status.removeSong(songId: songId, platform: platform);
      }
      final action = like ? 'favorited' : 'unfavorited';
      state = state.copyWith(message: 'Song $action.', clearError: true);
    });
  }

  Future<void> toggleAlbumFavorite({
    required String albumId,
    required String platform,
    required bool like,
    String? name,
    String? cover,
    List<Map<String, dynamic>>? artists,
  }) async {
    _validateNotEmpty(albumId, 'Album id is required.');
    _validateNotEmpty(platform, 'Platform is required.');
    await _runAction(() async {
      final client = ref.read(onlineApiClientProvider);
      await client.toggleAlbumFavorite(
        albumId: albumId,
        platform: platform,
        like: like,
        name: name,
        cover: cover,
        artists: artists,
      );
      final status = ref.read(favoriteCollectionStatusProvider.notifier);
      if (like) {
        status.add(
          type: MyFavoriteType.albums,
          id: albumId,
          platform: platform,
        );
      } else {
        status.remove(
          type: MyFavoriteType.albums,
          id: albumId,
          platform: platform,
        );
      }
      final action = like ? 'favorited' : 'unfavorited';
      state = state.copyWith(message: 'Album $action.', clearError: true);
    });
  }

  Future<void> toggleArtistFavorite({
    required String artistId,
    required String platform,
    required bool like,
    String? name,
    String? cover,
  }) async {
    _validateNotEmpty(artistId, 'Artist id is required.');
    _validateNotEmpty(platform, 'Platform is required.');
    await _runAction(() async {
      final client = ref.read(onlineApiClientProvider);
      await client.toggleArtistFavorite(
        artistId: artistId,
        platform: platform,
        like: like,
        name: name,
        cover: cover,
      );
      final status = ref.read(favoriteCollectionStatusProvider.notifier);
      if (like) {
        status.add(
          type: MyFavoriteType.artists,
          id: artistId,
          platform: platform,
        );
      } else {
        status.remove(
          type: MyFavoriteType.artists,
          id: artistId,
          platform: platform,
        );
      }
      final action = like ? 'favorited' : 'unfavorited';
      state = state.copyWith(message: 'Artist $action.', clearError: true);
    });
  }

  Future<void> fetchComments({
    required String resourceId,
    required String resourceType,
    required String platform,
  }) async {
    _validateNotEmpty(resourceId, 'Resource id is required.');
    _validateNotEmpty(resourceType, 'Resource type is required.');
    _validateNotEmpty(platform, 'Platform is required.');
    await _runAction(() async {
      final client = ref.read(onlineApiClientProvider);
      final comments = await client.fetchComments(
        resourceId: resourceId,
        resourceType: resourceType,
        platform: platform,
      );
      state = state.copyWith(
        comments: comments,
        message: 'Comments loaded: ${comments.length} items.',
        clearError: true,
      );
    });
  }

  Future<void> _runAction(Future<void> Function() action) async {
    state = state.copyWith(loading: true, clearMessage: true, clearError: true);
    try {
      await action();
    } catch (error) {
      state = state.copyWith(error: error.toString());
      rethrow;
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  String? _findToken(Map<String, dynamic> response) {
    final direct = response['token'];
    if (direct is String) {
      return direct;
    }
    final data = response['data'];
    if (data is Map) {
      final value = data['token'];
      if (value is String) {
        return value;
      }
    }
    return null;
  }

  Future<void> _completeLoginWithToken(String token) async {
    ref.read(appConfigProvider.notifier).setAuthToken(token);
    await ref.read(favoriteSongStatusProvider.notifier).refresh();
    await ref.read(favoriteCollectionStatusProvider.notifier).refresh();
  }

  void _validateNotEmpty(String input, String message) {
    if (input.trim().isNotEmpty) {
      return;
    }
    throw AppException(ValidationFailure(message));
  }
}
