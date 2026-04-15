import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/app_message_service.dart';
import '../../../../../app/config/app_config_controller.dart';
import '../../../../../app/config/app_config_state.dart';
import '../../../../../app/i18n/app_i18n.dart';
import '../../../../../app/router/app_routes.dart';
import '../../../../../shared/helpers/album_id_helper.dart';
import '../../../../../shared/helpers/current_track_helper.dart';
import '../../../../../shared/helpers/platform_label_helper.dart';
import '../../../../../shared/helpers/song_artist_navigation_helper.dart';
import '../../../../../shared/models/he_music_models.dart';
import '../../../../../shared/utils/cover_resolver.dart';
import '../../../../../shared/utils/favorite_song_key.dart';
import '../../../../../shared/widgets/online_platform_tabs.dart';
import '../../../../../shared/widgets/online_song_list_item.dart';
import '../../../../../shared/widgets/song_list_component.dart';
import '../../../../../shared/widgets/underline_tab.dart';
import '../../../../../shared/widgets/song_actions_sheet.dart';
import '../../../../download/domain/entities/download_task.dart';
import '../../../../download/presentation/providers/download_providers.dart';
import '../../../../download/presentation/widgets/download_quality_sheet.dart';
import '../../../../my/presentation/providers/favorite_song_status_providers.dart';
import '../../../../online/domain/entities/online_platform.dart';
import '../../../../online/presentation/providers/online_providers.dart';
import '../../../../player/domain/entities/player_quality_option.dart';
import '../../../../player/domain/entities/player_track.dart';
import '../../../../player/presentation/providers/player_providers.dart';
import '../../../../player/presentation/widgets/mini_player_bar.dart';
import '../../domain/entities/new_song_page_state.dart';
import '../providers/new_song_page_providers.dart';

class NewSongPage extends ConsumerStatefulWidget {
  const NewSongPage({this.initialPlatform, this.initialTabId, super.key});

  final String? initialPlatform;
  final String? initialTabId;

  @override
  ConsumerState<NewSongPage> createState() => _NewSongPageState();
}

class _NewSongPageState extends ConsumerState<NewSongPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref
          .read(newSongPageControllerProvider.notifier)
          .initialize(
            preferredPlatformId: widget.initialPlatform,
            preferredTabId: widget.initialTabId,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(newSongPageControllerProvider);
    final config = ref.watch(appConfigProvider);
    final controller = ref.read(newSongPageControllerProvider.notifier);
    final currentTrack = ref.watch(
      playerControllerProvider.select((playback) => playback.currentTrack),
    );
    final favoriteSongKeys = ref.watch(
      favoriteSongStatusProvider.select((favorite) => favorite.songKeys),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('新歌')),
      bottomNavigationBar: MiniPlayerBar(
        onOpenFullPlayer: () => context.push(AppRoutes.player),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: OnlinePlatformTabs(
              platforms: state.platforms,
              selectedId: state.selectedPlatformId,
              requiredFeatureFlag: PlatformFeatureSupportFlag.getNewSongList,
              onSelected: controller.selectPlatform,
            ),
          ),
          const Divider(height: 1),
          _ReleaseTabBar(
            labels: state.tabs
                .map((item) => _ReleaseTabData(id: item.id, name: item.name))
                .toList(growable: false),
            selectedId: state.selectedTabId,
            onSelected: controller.selectTab,
          ),
          const Divider(height: 1),
          Expanded(
            child: _NewSongBody(
              state: state,
              favoriteSongKeys: favoriteSongKeys,
              currentTrack: currentTrack,
              resolveSongCover: (song) =>
                  _resolveNewSongCover(config: config, song: song),
              isSongLiked: (song) {
                final platformId = song.platform.trim().isNotEmpty
                    ? song.platform.trim()
                    : (state.selectedPlatformId ?? '').trim();
                if (platformId.isEmpty) {
                  return false;
                }
                return favoriteSongKeys.contains(
                  buildFavoriteSongKey(songId: song.id, platform: platformId),
                );
              },
              isCurrentSong: (song) => isCurrentSongTrack(currentTrack, song),
              onTapSong: (songs, index) => _playNewSongs(
                context: context,
                songs: songs,
                startIndex: index,
              ),
              onLikeSong: (song) => _toggleSongFavorite(song: song),
              onMoreSong: (song) =>
                  _showNewSongActions(context: context, song: song),
              onRetry: controller.retry,
              onLoadMore: controller.loadMore,
            ),
          ),
        ],
      ),
    );
  }
}

class _NewSongBody extends StatelessWidget {
  const _NewSongBody({
    required this.state,
    required this.favoriteSongKeys,
    required this.currentTrack,
    required this.resolveSongCover,
    required this.isSongLiked,
    required this.isCurrentSong,
    required this.onTapSong,
    required this.onLikeSong,
    required this.onMoreSong,
    required this.onRetry,
    required this.onLoadMore,
  });

  final NewSongPageState state;
  final Set<String> favoriteSongKeys;
  final PlayerTrack? currentTrack;
  final String Function(SongInfo song) resolveSongCover;
  final bool Function(SongInfo song) isSongLiked;
  final bool Function(SongInfo song) isCurrentSong;
  final void Function(List<SongInfo> songs, int index) onTapSong;
  final Future<void> Function(SongInfo song) onLikeSong;
  final ValueChanged<SongInfo> onMoreSong;
  final Future<void> Function() onRetry;
  final Future<void> Function() onLoadMore;

  @override
  Widget build(BuildContext context) {
    if (state.tabsLoading && state.tabs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.songsErrorMessage != null && state.songs.isEmpty) {
      return _RetryBody(message: state.songsErrorMessage!, onRetry: onRetry);
    }
    return SongListComponent(
      initialLoading: state.songsLoading && state.songs.isEmpty,
      itemCount: state.songs.length,
      hasMore: state.hasMore,
      loadingMore: state.loadingMore,
      onLoadMore: onLoadMore,
      empty: const Center(child: Text('暂无新歌')),
      itemBuilder: (context, index) {
        final song = state.songs[index];
        return OnlineSongListItem(
          song: song,
          artistAlbumText: song.artistAlbumText,
          subtitleText: song.displaySubtitle,
          coverUrl: resolveSongCover(song).isEmpty
              ? null
              : resolveSongCover(song),
          isCurrent: isCurrentSong(song),
          isLiked: isSongLiked(song),
          onTap: () => onTapSong(state.songs, index),
          onLikeTap: () => onLikeSong(song),
          onMoreTap: () => onMoreSong(song),
        );
      },
    );
  }
}

class _ReleaseTabData {
  const _ReleaseTabData({required this.id, required this.name});

  final String id;
  final String name;
}

class _ReleaseTabBar extends StatelessWidget {
  const _ReleaseTabBar({
    required this.labels,
    required this.selectedId,
    required this.onSelected,
  });

  final List<_ReleaseTabData> labels;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: labels
            .map(
              (item) => UnderlineTab(
                label: item.name,
                selected: item.id == selectedId,
                enabled: true,
                onTap: () => onSelected(item.id),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _RetryBody extends StatelessWidget {
  const _RetryBody({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: () => onRetry(), child: const Text('重试')),
        ],
      ),
    );
  }
}

extension on _NewSongPageState {
  String get _selectedPlatformId {
    return ref.read(newSongPageControllerProvider).selectedPlatformId?.trim() ??
        '';
  }

  List<OnlinePlatform> get _platforms {
    return ref.read(onlinePlatformsProvider).valueOrNull ??
        const <OnlinePlatform>[];
  }

  Future<void> _playNewSongs({
    required BuildContext context,
    required List<SongInfo> songs,
    required int startIndex,
  }) async {
    if (songs.isEmpty || startIndex < 0 || startIndex >= songs.length) {
      return;
    }
    final selectedPlatformId = _selectedPlatformId;
    final playerController = ref.read(playerControllerProvider.notifier);
    final config = ref.read(appConfigProvider);
    try {
      final tracks = songs
          .map(
            (song) => PlayerTrack(
              id: song.id,
              title: song.title,
              links: song.links,
              artist: song.artist,
              album: song.album?.name.trim().isEmpty ?? true
                  ? null
                  : song.album?.name,
              albumId: song.album?.id.trim().isEmpty ?? true
                  ? null
                  : song.album?.id,
              artists: song.artists,
              mvId: song.mvId,
              artworkUrl:
                  _resolveNewSongCover(config: config, song: song).isEmpty
                  ? null
                  : _resolveNewSongCover(config: config, song: song),
              platform: song.platform.trim().isNotEmpty
                  ? song.platform.trim()
                  : selectedPlatformId,
            ),
          )
          .toList(growable: false);
      await playerController.replaceQueue(tracks, startIndex: startIndex);
    } catch (error) {
      AppMessageService.showError(
        AppI18n.format(
          ref.read(appConfigProvider),
          'detail.play_failed',
          <String, String>{'error': '$error'},
        ),
      );
    }
  }

  Future<void> _toggleSongFavorite({required SongInfo song}) async {
    final platformId = song.platform.trim().isNotEmpty
        ? song.platform.trim()
        : _selectedPlatformId;
    if (platformId.isEmpty) {
      return;
    }
    final liked = ref.read(
      favoriteSongStatusProvider.select(
        (state) => state.songKeys.contains(
          buildFavoriteSongKey(songId: song.id, platform: platformId),
        ),
      ),
    );
    try {
      await ref
          .read(onlineControllerProvider.notifier)
          .toggleSongFavorite(
            songId: song.id,
            platform: platformId,
            like: !liked,
          );
    } catch (error) {
      AppMessageService.showError('$error');
    }
  }

  void _showNewSongActions({
    required BuildContext context,
    required SongInfo song,
  }) {
    final platformId = song.platform.trim().isNotEmpty
        ? song.platform.trim()
        : _selectedPlatformId;
    if (platformId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('平台未就绪')));
      return;
    }
    final title = song.title;
    final subtitle = song.artist;
    final albumId = song.album?.id.trim() ?? '';
    final albumTitle = song.album?.name.trim() ?? '';
    final canViewAlbum = hasValidAlbumId(albumId);
    final config = ref.read(appConfigProvider);
    final platforms = _platforms;
    final artworkUrl = _resolveNewSongCover(config: config, song: song);
    final sourceLabel = AppI18n.format(config, 'song.source', <String, String>{
      'platform': resolvePlatformLabel(platformId, platforms: platforms),
    });
    final qualities = buildDownloadQualityOptions(
      links: song.links,
      qualityDescriptions: _platformQualityDescriptions(
        platforms: platforms,
        platformId: platformId,
      ),
    );
    showSongActionsSheet(
      context: context,
      coverUrl: artworkUrl.isEmpty ? null : artworkUrl,
      title: title,
      subtitle: subtitle,
      hasMv: song.hasMv,
      sourceLabel: sourceLabel,
      onPlay: () => unawaited(
        _replaceQueueFromOnlineSong(
          song: song,
          artworkUrl: artworkUrl,
          platformId: platformId,
        ),
      ),
      onPlayNext: () => unawaited(
        _insertNextFromOnlineSong(
          song: song,
          artworkUrl: artworkUrl,
          platformId: platformId,
        ),
      ),
      onAddToPlaylist: () => unawaited(
        _appendFromOnlineSong(
          song: song,
          artworkUrl: artworkUrl,
          platformId: platformId,
        ),
      ),
      onDownload: qualities.isEmpty
          ? null
          : () => unawaited(
              _downloadNewSong(
                context: context,
                song: song,
                platformId: platformId,
                artworkUrl: artworkUrl.isEmpty ? null : artworkUrl,
                qualities: qualities,
              ),
            ),
      onWatchMv: () => _openNewSongMvDetail(
        context: context,
        platformId: platformId,
        song: song,
      ),
      onViewComment: () => _openSongComments(
        context: context,
        songId: song.id,
        platformId: platformId,
        title: title,
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
        song.artists,
        localeCode: config.localeCode,
      ),
      onViewArtists: song.artists.isEmpty
          ? null
          : () => unawaited(
              openSongArtistSelection(
                context: context,
                platformId: platformId,
                artists: song.artists,
              ),
            ),
      onCopySongName: () => unawaited(
        _copyText(
          context: context,
          value: title,
          successLabel: AppI18n.t(config, 'player.copy.name_done'),
        ),
      ),
      onCopySongShareLink: () => unawaited(
        _copyText(
          context: context,
          value: 'https://y.wjhe.top/song/$platformId/${song.id}',
          successLabel: AppI18n.t(config, 'player.copy.share_done'),
        ),
      ),
      onSearchSameName: () => _openSongSearch(
        context: context,
        platformId: platformId,
        keyword: title,
      ),
      onCopySongId: () => unawaited(
        _copyText(
          context: context,
          value: song.id,
          successLabel: AppI18n.t(config, 'player.copy.id_done'),
        ),
      ),
    );
  }

  String _resolveNewSongCover({
    required AppConfigState config,
    required SongInfo song,
  }) {
    final platformId = song.platform.trim().isNotEmpty
        ? song.platform.trim()
        : _selectedPlatformId;
    if (platformId.isEmpty) {
      return song.cover;
    }
    return resolveSongCoverUrl(
      baseUrl: config.apiBaseUrl,
      token: config.authToken ?? '',
      platforms: _platforms,
      platformId: platformId,
      songId: song.id,
      cover: song.cover,
      size: 300,
    );
  }

  Map<String, String> _platformQualityDescriptions({
    required List<OnlinePlatform> platforms,
    required String platformId,
  }) {
    for (final platform in platforms) {
      if (platform.id == platformId) {
        return platform.qualities;
      }
    }
    return const <String, String>{};
  }

  Future<void> _downloadNewSong({
    required BuildContext context,
    required SongInfo song,
    required String platformId,
    required String? artworkUrl,
    required List<PlayerQualityOption> qualities,
  }) async {
    final config = ref.read(appConfigProvider);
    final selected = await showDownloadQualitySheet(
      context: context,
      qualities: qualities,
      selectedQualityName: qualities.isEmpty ? null : qualities.first.name,
    );
    if (selected == null) {
      return;
    }
    try {
      await ref
          .read(downloadControllerProvider.notifier)
          .enqueue(
            title: song.title,
            quality: DownloadTaskQuality(
              label: selected.name,
              bitrate: selected.quality.toDouble(),
              fileExtension: selected.format.trim().toLowerCase(),
            ),
            songId: song.id,
            platform: platformId,
            artist: song.artist,
            album: song.album?.name,
            artworkUrl: artworkUrl,
          );
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppI18n.format(config, 'player.download.added', <String, String>{
              'title': song.title,
            }),
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppI18n.t(config, 'player.download.failed'))),
      );
    }
  }

  PlayerTrack _buildOnlineTrack({
    required SongInfo song,
    required String artworkUrl,
    required String platformId,
  }) {
    return PlayerTrack(
      id: song.id,
      title: song.title,
      links: song.links,
      artist: song.artist,
      album: song.album?.name,
      albumId: song.album?.id,
      artists: song.artists,
      mvId: song.mvId,
      artworkUrl: artworkUrl.isEmpty ? null : artworkUrl,
      platform: platformId,
    );
  }

  Future<void> _replaceQueueFromOnlineSong({
    required SongInfo song,
    required String artworkUrl,
    required String platformId,
  }) async {
    await ref.read(playerControllerProvider.notifier).replaceQueue(
      <PlayerTrack>[
        _buildOnlineTrack(
          song: song,
          artworkUrl: artworkUrl,
          platformId: platformId,
        ),
      ],
    );
  }

  Future<void> _insertNextFromOnlineSong({
    required SongInfo song,
    required String artworkUrl,
    required String platformId,
  }) async {
    await ref
        .read(playerControllerProvider.notifier)
        .insertNextTrack(
          _buildOnlineTrack(
            song: song,
            artworkUrl: artworkUrl,
            platformId: platformId,
          ),
        );
  }

  Future<void> _appendFromOnlineSong({
    required SongInfo song,
    required String artworkUrl,
    required String platformId,
  }) async {
    await ref
        .read(playerControllerProvider.notifier)
        .appendTrack(
          _buildOnlineTrack(
            song: song,
            artworkUrl: artworkUrl,
            platformId: platformId,
          ),
        );
  }

  void _openSongSearch({
    required BuildContext context,
    required String platformId,
    required String keyword,
  }) {
    context.push(
      Uri(
        path: AppRoutes.onlineSearch,
        queryParameters: <String, String>{
          'platform': platformId,
          'keyword': keyword,
        },
      ).toString(),
    );
  }

  void _openAlbumDetail({
    required BuildContext context,
    required String albumId,
    required String platformId,
    required String albumTitle,
  }) {
    final localeCode = Localizations.localeOf(context).languageCode;
    context.push(
      Uri(
        path: AppRoutes.albumDetail,
        queryParameters: <String, String>{
          'id': albumId,
          'platform': platformId,
          'title': albumTitle.isEmpty
              ? AppI18n.tByLocaleCode(localeCode, 'album.fallback_title')
              : albumTitle,
        },
      ).toString(),
    );
  }

  void _openSongComments({
    required BuildContext context,
    required String songId,
    required String platformId,
    required String title,
  }) {
    final localeCode = Localizations.localeOf(context).languageCode;
    if (!_platformSupports(
      platformId: platformId,
      featureFlag: PlatformFeatureSupportFlag.getCommentList,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppI18n.tByLocaleCode(localeCode, 'search.comment_unsupported'),
          ),
        ),
      );
      return;
    }
    context.push(
      Uri(
        path: AppRoutes.onlineComments,
        queryParameters: <String, String>{
          'id': songId,
          'resource_type': 'song',
          'platform': platformId,
          'title': title,
        },
      ).toString(),
    );
  }

  void _openNewSongMvDetail({
    required BuildContext context,
    required String platformId,
    required SongInfo song,
  }) {
    final localeCode = Localizations.localeOf(context).languageCode;
    final mvId = song.mvId.trim();
    if (mvId.isEmpty || mvId == '0') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppI18n.tByLocaleCode(localeCode, 'search.no_mv')),
        ),
      );
      return;
    }
    context.push(
      Uri(
        path: AppRoutes.videoDetail,
        queryParameters: <String, String>{
          'type': 'mv',
          'id': mvId,
          'platform': platformId,
          'title': song.title,
        },
      ).toString(),
    );
  }

  bool _platformSupports({
    required String platformId,
    required BigInt featureFlag,
  }) {
    for (final platform in _platforms) {
      if (platform.id != platformId) {
        continue;
      }
      return platform.available && platform.supports(featureFlag);
    }
    return true;
  }

  Future<void> _copyText({
    required BuildContext context,
    required String value,
    required String successLabel,
  }) async {
    final localeCode = Localizations.localeOf(context).languageCode;
    final text = value.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppI18n.tByLocaleCode(localeCode, 'search.copy_empty')),
        ),
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(successLabel)));
  }
}
