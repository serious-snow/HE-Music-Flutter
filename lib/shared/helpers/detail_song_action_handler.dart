import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_message_service.dart';
import '../../app/config/app_config_controller.dart';
import '../../app/i18n/app_i18n.dart';
import '../../app/router/app_routes.dart';
import '../../features/online/domain/entities/online_platform.dart';
import '../../features/online/presentation/providers/online_providers.dart';
import '../../features/player/domain/entities/player_queue_source.dart';
import '../../features/player/domain/entities/player_track.dart';
import '../../features/player/presentation/providers/player_providers.dart';
import '../models/he_music_models.dart';
import 'album_id_helper.dart';
import 'song_artist_navigation_helper.dart';
import '../utils/cover_resolver.dart';
import '../widgets/song_actions_sheet.dart';

typedef DetailSongStringField<T> = String Function(T song);
typedef DetailSongNullableStringField<T> = String? Function(T song);
typedef DetailSongArtistsField<T> = List<SongInfoArtistInfo> Function(T song);
typedef DetailSongAlbumIdField<T> = String? Function(T song);
typedef DetailSongAlbumTitleField<T> = String? Function(T song);

class DetailSongActionHandler<T> {
  DetailSongActionHandler({
    required this.ref,
    required this.songIdOf,
    required this.songTitleOf,
    required this.songArtistOf,
    required this.songPlatformOf,
    required this.songCoverOf,
    this.songArtistsOf,
    this.songAlbumIdOf,
    this.songAlbumTitleOf,
    this.queueSource,
  });

  final WidgetRef ref;
  final DetailSongStringField<T> songIdOf;
  final DetailSongStringField<T> songTitleOf;
  final DetailSongStringField<T> songArtistOf;
  final DetailSongStringField<T> songPlatformOf;
  final DetailSongNullableStringField<T> songCoverOf;
  final DetailSongArtistsField<T>? songArtistsOf;
  final DetailSongAlbumIdField<T>? songAlbumIdOf;
  final DetailSongAlbumTitleField<T>? songAlbumTitleOf;
  final PlayerQueueSource? queueSource;

  String resolveCoverUrl(T song) {
    final config = ref.read(appConfigProvider);
    final platforms =
        ref.read(onlinePlatformsProvider).valueOrNull ??
        const <OnlinePlatform>[];
    return resolveSongCoverUrl(
      baseUrl: config.apiBaseUrl,
      token: config.authToken ?? '',
      platforms: platforms,
      platformId: songPlatformOf(song),
      songId: songIdOf(song),
      cover: songCoverOf(song),
      size: 300,
    );
  }

  Future<void> playAll(
    BuildContext context,
    List<T> songs, {
    int startIndex = 0,
  }) async {
    if (songs.isEmpty) return;
    if (startIndex < 0 || startIndex >= songs.length) {
      return;
    }
    final playerController = ref.read(playerControllerProvider.notifier);
    try {
      final tracks = await _buildTracks(songs);
      await playerController.replaceQueue(
        tracks,
        startIndex: startIndex,
        queueSource: queueSource,
      );
    } catch (error) {
      _showErrorMessage(
        AppI18n.format(
          ref.read(appConfigProvider),
          'detail.play_failed',
          <String, String>{'error': '$error'},
        ),
      );
    }
  }

  void showSongActions({
    required BuildContext context,
    required T song,
    required String coverUrl,
  }) {
    final platformId = songPlatformOf(song);
    final config = ref.read(appConfigProvider);
    final platformLabel = _resolvePlatformLabel(platformId);
    final artists = songArtistsOf?.call(song) ?? const <SongInfoArtistInfo>[];
    final albumId = songAlbumIdOf?.call(song)?.trim() ?? '';
    final albumTitle = songAlbumTitleOf?.call(song)?.trim() ?? '';
    final canViewAlbum = hasValidAlbumId(albumId);
    showSongActionsSheet(
      context: context,
      coverUrl: coverUrl.isEmpty ? null : coverUrl,
      title: songTitleOf(song),
      subtitle: songArtistOf(song),
      hasMv: false,
      sourceLabel: AppI18n.format(
        config,
        'song.source',
        <String, String>{'platform': platformLabel},
      ),
      onPlay: () => unawaited(_playNow(song, coverUrl)),
      onPlayNext: () => unawaited(_insertNext(song, coverUrl)),
      onAddToPlaylist: () => unawaited(_appendToQueue(song, coverUrl)),
      onWatchMv: () {},
      onViewComment: () => _openSongComments(
        context: context,
        songId: songIdOf(song),
        platformId: platformId,
        title: songTitleOf(song),
      ),
      albumActionLabel: canViewAlbum
          ? AppI18n.t(config, 'player.action.view_album')
          : null,
      onViewAlbum: canViewAlbum
          ? () => _openAlbumDetail(
              context: context,
              albumId: albumId,
              platformId: platformId,
              albumTitle: albumTitle,
            )
          : null,
      artistActionLabel: songArtistActionLabel(
        artists,
        localeCode: config.localeCode,
      ),
      onViewArtists: artists.isEmpty
          ? null
          : () => unawaited(
              openSongArtistSelection(
                context: context,
                platformId: platformId,
                artists: artists,
                onError: (message) => _showMessage(context, message),
              ),
            ),
      onCopySongName: () => unawaited(
        _copyText(
          context: context,
          value: songTitleOf(song),
          success: AppI18n.t(config, 'player.copy.name_done'),
        ),
      ),
      onCopySongShareLink: () => unawaited(
        _copyText(
          context: context,
          value: 'https://y.wjhe.top/song/$platformId/${songIdOf(song)}',
          success: AppI18n.t(config, 'player.copy.share_done'),
        ),
      ),
      onSearchSameName: () => _openSongSearch(
        context: context,
        platformId: platformId,
        keyword: songTitleOf(song),
      ),
      onCopySongId: () => unawaited(
        _copyText(
          context: context,
          value: songIdOf(song),
          success: AppI18n.t(config, 'player.copy.id_done'),
        ),
      ),
    );
  }

  Future<void> _playNow(T song, String coverUrl) async {
    final track = await _buildTrack(song, coverUrl);
    await ref.read(playerControllerProvider.notifier).insertNextAndPlay(track);
  }

  Future<void> _insertNext(T song, String coverUrl) async {
    final track = await _buildTrack(song, coverUrl);
    await ref.read(playerControllerProvider.notifier).insertNextTrack(track);
  }

  Future<void> _appendToQueue(T song, String coverUrl) async {
    final track = await _buildTrack(song, coverUrl);
    await ref.read(playerControllerProvider.notifier).appendTrack(track);
  }

  String _resolvePlatformLabel(String platformId) {
    final normalized = platformId.trim();
    if (normalized.isEmpty) {
      return '';
    }
    final platforms =
        ref.read(onlinePlatformsProvider).valueOrNull ??
        const <OnlinePlatform>[];
    for (final platform in platforms) {
      if (platform.id == normalized) {
        final name = platform.name.trim();
        if (name.isNotEmpty) {
          return name;
        }
        break;
      }
    }
    return normalized.toUpperCase();
  }

  Future<PlayerTrack> _buildTrack(T song, String coverUrl) async {
    return PlayerTrack(
      id: songIdOf(song),
      title: songTitleOf(song),
      links: song is SongInfo ? song.links : const <LinkInfo>[],
      artist: songArtistOf(song),
      albumId: song is SongInfo ? song.album?.id : songAlbumIdOf?.call(song),
      album: song is SongInfo
          ? song.album?.name
          : songAlbumTitleOf?.call(song),
      artists: song is SongInfo
          ? song.artists
          : (songArtistsOf?.call(song) ?? const <SongInfoArtistInfo>[]),
      mvId: song is SongInfo ? song.mvId : null,
      artworkUrl: coverUrl.isEmpty ? null : coverUrl,
      platform: songPlatformOf(song),
    );
  }

  Future<List<PlayerTrack>> _buildTracks(List<T> songs) async {
    final tracks = <PlayerTrack>[];
    for (final song in songs) {
      final artworkUrl = resolveCoverUrl(song);
      tracks.add(await _buildTrack(song, artworkUrl));
    }
    return tracks;
  }

  void _openSongSearch({
    required BuildContext context,
    required String platformId,
    required String keyword,
  }) {
    final uri = Uri(
      path: AppRoutes.onlineSearch,
      queryParameters: <String, String>{
        'platform': platformId,
        'keyword': keyword,
      },
    );
    context.push(uri.toString());
  }

  void _openSongComments({
    required BuildContext context,
    required String songId,
    required String platformId,
    required String title,
  }) {
    if (!_platformSupports(
      platformId: platformId,
      featureFlag: PlatformFeatureSupportFlag.getCommentList,
    )) {
      _showMessage(
        context,
        AppI18n.t(ref.read(appConfigProvider), 'search.comment_unsupported'),
      );
      return;
    }
    final uri = Uri(
      path: AppRoutes.onlineComments,
      queryParameters: <String, String>{
        'id': songId,
        'resource_type': 'song',
        'platform': platformId,
        'title': title,
      },
    );
    context.push(uri.toString());
  }

  void _openAlbumDetail({
    required BuildContext context,
    required String albumId,
    required String platformId,
    required String albumTitle,
  }) {
    final uri = Uri(
      path: AppRoutes.albumDetail,
      queryParameters: <String, String>{
        'id': albumId,
        'platform': platformId,
        'title': albumTitle.isEmpty
            ? AppI18n.t(ref.read(appConfigProvider), 'album.fallback_title')
            : albumTitle,
      },
    );
    context.push(uri.toString());
  }

  bool _platformSupports({
    required String platformId,
    required BigInt featureFlag,
  }) {
    final all = ref.read(onlinePlatformsProvider).valueOrNull;
    if (all == null) return true;
    for (final platform in all) {
      if (platform.id != platformId) continue;
      return platform.available && platform.supports(featureFlag);
    }
    return true;
  }

  Future<void> _copyText({
    required BuildContext context,
    required String value,
    required String success,
  }) async {
    final text = value.trim();
    if (text.isEmpty) {
      _showMessage(
        context,
        AppI18n.t(ref.read(appConfigProvider), 'search.copy_empty'),
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    _showMessage(context, success);
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showErrorMessage(String message) {
    AppMessageService.showError(message);
  }
}
