import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_message_service.dart';
import '../../../../app/config/app_config_controller.dart';
import '../../../../app/config/app_config_state.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../shared/layout/adaptive_media_grid_spec.dart';
import '../../../../shared/helpers/song_artist_navigation_helper.dart';
import '../../../../shared/helpers/album_id_helper.dart';
import '../../../../shared/helpers/platform_label_helper.dart';
import '../../../../shared/constants/layout_tokens.dart';
import '../../../../shared/helpers/current_track_helper.dart';
import '../../../../shared/models/he_music_models.dart';
import '../../../../shared/utils/favorite_song_key.dart';
import '../../../../shared/widgets/song_actions_sheet.dart';
import '../../../../shared/widgets/underline_tab.dart';
import '../../../../shared/utils/cover_resolver.dart';
import '../providers/home_discover_providers.dart';
import '../../../my/presentation/providers/favorite_song_status_providers.dart';
import '../../../player/domain/entities/player_track.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../../../online/domain/entities/online_platform.dart';
import '../../../online/presentation/providers/online_providers.dart';
import 'discover_sections.dart';
import 'home_search_field.dart';

const _entries = <_DiscoverEntry>[
  _DiscoverEntry(
    type: _DiscoverEntryType.ranking,
    icon: Icons.leaderboard_rounded,
    titleKey: 'home.entry.ranking',
  ),
  _DiscoverEntry(
    type: _DiscoverEntryType.playlist,
    icon: Icons.queue_music_rounded,
    titleKey: 'home.entry.playlist',
  ),
  _DiscoverEntry(
    type: _DiscoverEntryType.artist,
    icon: Icons.person_search_rounded,
    titleKey: 'home.entry.artist',
  ),
  _DiscoverEntry(
    type: _DiscoverEntryType.video,
    icon: Icons.ondemand_video_rounded,
    titleKey: 'home.entry.video',
  ),
];

enum _DiscoverEntryType { ranking, playlist, artist, video }

class DiscoverHomeTab extends ConsumerWidget {
  const DiscoverHomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final discoverState = ref.watch(homeDiscoverControllerProvider);
    final searchDefaultState = ref.watch(searchDefaultPlaceholderProvider);
    final globalPlatforms =
        ref.watch(onlinePlatformsProvider).valueOrNull ??
        const <OnlinePlatform>[];
    final currentTrack = ref.watch(
      playerControllerProvider.select((s) => s.currentTrack),
    );
    final discoverController = ref.read(
      homeDiscoverControllerProvider.notifier,
    );
    final favoriteSongKeys = ref.watch(
      favoriteSongStatusProvider.select((state) => state.songKeys),
    );
    final selectedPlatformId = discoverState.selectedPlatformId ?? '';
    final searchPlaceholderPrimary =
        searchDefaultState.currentEntry?.key.trim().isNotEmpty == true
        ? searchDefaultState.currentEntry!.key.trim()
        : AppI18n.t(config, 'home.search');
    final searchPlaceholderSecondary =
        searchDefaultState.currentEntry?.description.trim().isNotEmpty == true
        ? searchDefaultState.currentEntry!.description.trim()
        : null;
    return LayoutBuilder(
      builder: (context, constraints) {
        final gridSpec = resolveAdaptiveMediaGridSpec(
          maxWidth: constraints.maxWidth - LayoutTokens.compactPageGutter * 2,
        );
        return Stack(
          children: <Widget>[
            const Positioned.fill(child: _HomeBackground()),
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: <Widget>[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    LayoutTokens.compactPageGutter,
                    8,
                    LayoutTokens.compactPageGutter,
                    0,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _HomeHeroSection(
                      config: config,
                      searchPlaceholderPrimary: searchPlaceholderPrimary,
                      searchPlaceholderSecondary: searchPlaceholderSecondary,
                      onSearchTap: () => _openSearchPage(
                        context: context,
                        platformId: selectedPlatformId,
                      ),
                      onEntryTap: (entry) => _openEntry(
                        context: context,
                        platformId: selectedPlatformId,
                        entry: entry,
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: LayoutTokens.compactPageGutter + 4,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _PlatformBar(
                      selectedPlatformId: discoverState.selectedPlatformId,
                      onSelected: discoverController.selectPlatform,
                      chips: discoverState.platforms
                          .where((platform) => platform.available)
                          .map(
                            (platform) => _PlatformChipData(
                              id: platform.id,
                              label: platform.shortName,
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 14)),
                ...buildDiscoverSectionSlivers(
                  config: config,
                  gridSpec: gridSpec,
                  loadingText: AppI18n.t(config, 'home.loading'),
                  emptyText: AppI18n.t(config, 'home.empty'),
                  retryText: AppI18n.t(config, 'home.retry'),
                  titleOf: (section) => AppI18n.t(config, section.titleKey),
                  state: discoverState,
                  onRetry: discoverController.retry,
                  onTapSong: (songs, index) => _playDiscoverSong(
                    context: context,
                    ref: ref,
                    songs: songs,
                    startIndex: index,
                  ),
                  onTapAlbum: (album) => _openDiscoverDetailPage(
                    context: context,
                    path: AppRoutes.albumDetail,
                    id: album.id,
                    platform: album.platform,
                    title: album.name,
                  ),
                  onTapPlaylist: (playlist) => _openDiscoverDetailPage(
                    context: context,
                    path: AppRoutes.playlistDetail,
                    id: playlist.id,
                    platform: playlist.platform,
                    title: playlist.name,
                  ),
                  onTapVideo: (video) => _openDiscoverDetailPage(
                    context: context,
                    path: AppRoutes.videoDetail,
                    id: video.id,
                    platform: video.platform,
                    title: video.name,
                  ),
                  onMoreSong: (song) => _showDiscoverSongActions(
                    context: context,
                    ref: ref,
                    song: song,
                  ),
                  isSongLiked: (song) => favoriteSongKeys.contains(
                    buildFavoriteSongKey(
                      songId: song.id,
                      platform: song.platform.isEmpty
                          ? selectedPlatformId
                          : song.platform,
                    ),
                  ),
                  onLikeSong: (song) => _toggleSongFavorite(
                    ref: ref,
                    song: song,
                    fallbackPlatformId: selectedPlatformId,
                  ),
                  isCurrentSong: (song) =>
                      isCurrentSongTrack(currentTrack, song),
                  resolveSongCover: (song) => _resolveDiscoverSongCover(
                    config: config,
                    platforms: globalPlatforms,
                    platformId: discoverState.selectedPlatformId,
                    song: song,
                  ),
                  resolveAlbumCover: (album) => _resolveDiscoverGridCover(
                    platforms: globalPlatforms,
                    selectedPlatformId: discoverState.selectedPlatformId,
                    itemPlatformId: album.platform,
                    cover: album.cover,
                  ),
                  resolvePlaylistCover: (playlist) => _resolveDiscoverGridCover(
                    platforms: globalPlatforms,
                    selectedPlatformId: discoverState.selectedPlatformId,
                    itemPlatformId: playlist.platform,
                    cover: playlist.cover,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _playDiscoverSong({
    required BuildContext context,
    required WidgetRef ref,
    required List<SongInfo> songs,
    required int startIndex,
  }) async {
    if (songs.isEmpty || startIndex < 0 || startIndex >= songs.length) {
      return;
    }
    final selectedPlatformId = ref
        .read(homeDiscoverControllerProvider)
        .selectedPlatformId;
    final playerController = ref.read(playerControllerProvider.notifier);
    final config = ref.read(appConfigProvider);
    final platforms =
        ref.read(onlinePlatformsProvider).valueOrNull ??
        const <OnlinePlatform>[];
    try {
      final tracks = songs
          .map((song) {
            final artworkUrl = _resolveDiscoverSongCover(
              config: config,
              platforms: platforms,
              platformId: selectedPlatformId,
              song: song,
            );
            return PlayerTrack(
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
              artworkUrl: artworkUrl.isEmpty ? null : artworkUrl,
              platform: selectedPlatformId,
            );
          })
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

  void _showDiscoverSongActions({
    required BuildContext context,
    required WidgetRef ref,
    required SongInfo song,
  }) {
    final platformId = ref
        .read(homeDiscoverControllerProvider)
        .selectedPlatformId;
    if (platformId == null || platformId.trim().isEmpty) {
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
    final platforms =
        ref.read(onlinePlatformsProvider).valueOrNull ??
        const <OnlinePlatform>[];
    final sourceLabel = AppI18n.format(
      ref.read(appConfigProvider),
      'song.source',
      <String, String>{
        'platform': resolvePlatformLabel(platformId, platforms: platforms),
      },
    );
    final artworkUrl = _resolveDiscoverSongCover(
      config: config,
      platforms: platforms,
      platformId: platformId,
      song: song,
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
          ref: ref,
          songId: song.id,
          title: title,
          links: song.links,
          artist: subtitle,
          album: albumTitle.isEmpty ? null : albumTitle,
          albumId: albumId.isEmpty ? null : albumId,
          artists: song.artists,
          mvId: song.mvId,
          artworkUrl: artworkUrl,
          platformId: platformId,
        ),
      ),
      onPlayNext: () => unawaited(
        _insertNextFromOnlineSong(
          ref: ref,
          songId: song.id,
          title: title,
          links: song.links,
          artist: subtitle,
          album: albumTitle.isEmpty ? null : albumTitle,
          albumId: albumId.isEmpty ? null : albumId,
          artists: song.artists,
          mvId: song.mvId,
          artworkUrl: artworkUrl,
          platformId: platformId,
        ),
      ),
      onAddToPlaylist: () => unawaited(
        _appendFromOnlineSong(
          ref: ref,
          songId: song.id,
          title: title,
          links: song.links,
          artist: subtitle,
          album: albumTitle.isEmpty ? null : albumTitle,
          albumId: albumId.isEmpty ? null : albumId,
          artists: song.artists,
          mvId: song.mvId,
          artworkUrl: artworkUrl,
          platformId: platformId,
        ),
      ),
      onWatchMv: () => _openDiscoverSongMvDetail(
        context: context,
        platformId: platformId,
        song: song,
      ),
      onViewComment: () => _openSongComments(
        context: context,
        ref: ref,
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

  Future<void> _toggleSongFavorite({
    required WidgetRef ref,
    required SongInfo song,
    required String fallbackPlatformId,
  }) async {
    final platform = song.platform.isEmpty ? fallbackPlatformId : song.platform;
    final liked = ref.read(
      favoriteSongStatusProvider.select(
        (state) => state.songKeys.contains(
          buildFavoriteSongKey(songId: song.id, platform: platform),
        ),
      ),
    );
    try {
      await ref
          .read(onlineControllerProvider.notifier)
          .toggleSongFavorite(
            songId: song.id,
            platform: platform,
            like: !liked,
          );
    } catch (error) {
      AppMessageService.showError('$error');
    }
  }

  String _resolveDiscoverSongCover({
    required AppConfigState config,
    required List<OnlinePlatform> platforms,
    required String? platformId,
    required SongInfo song,
  }) {
    final resolvedPlatform = (platformId ?? '').trim();
    if (resolvedPlatform.isEmpty) {
      return song.cover;
    }
    return resolveSongCoverUrl(
      baseUrl: config.apiBaseUrl,
      token: config.authToken ?? '',
      platforms: platforms,
      platformId: resolvedPlatform,
      songId: song.id,
      cover: song.cover,
      size: 300,
    );
  }

  String _resolveDiscoverGridCover({
    required List<OnlinePlatform> platforms,
    required String? selectedPlatformId,
    required String itemPlatformId,
    required String cover,
  }) {
    final platformId = itemPlatformId.trim().isNotEmpty
        ? itemPlatformId.trim()
        : (selectedPlatformId ?? '').trim();
    if (platformId.isEmpty) {
      return cover;
    }
    final resolved = resolveTemplateCoverUrl(
      platforms: platforms,
      platformId: platformId,
      cover: cover,
      size: 300,
    );
    return resolved.isEmpty ? cover : resolved;
  }

  PlayerTrack _buildOnlineTrack({
    required String songId,
    required String title,
    required List<LinkInfo> links,
    required String artist,
    String? album,
    String? albumId,
    List<SongInfoArtistInfo> artists = const <SongInfoArtistInfo>[],
    String? mvId,
    required String artworkUrl,
    required String platformId,
  }) {
    return PlayerTrack(
      id: songId,
      title: title,
      links: links,
      artist: artist,
      album: album,
      albumId: albumId,
      artists: artists,
      mvId: mvId,
      artworkUrl: artworkUrl.isEmpty ? null : artworkUrl,
      platform: platformId,
    );
  }

  Future<void> _replaceQueueFromOnlineSong({
    required WidgetRef ref,
    required String songId,
    required String title,
    required List<LinkInfo> links,
    required String artist,
    String? album,
    String? albumId,
    List<SongInfoArtistInfo> artists = const <SongInfoArtistInfo>[],
    String? mvId,
    required String artworkUrl,
    required String platformId,
  }) async {
    final track = _buildOnlineTrack(
      songId: songId,
      title: title,
      links: links,
      artist: artist,
      album: album,
      albumId: albumId,
      artists: artists,
      mvId: mvId,
      artworkUrl: artworkUrl,
      platformId: platformId,
    );
    await ref.read(playerControllerProvider.notifier).replaceQueue(
      <PlayerTrack>[track],
    );
  }

  Future<void> _insertNextFromOnlineSong({
    required WidgetRef ref,
    required String songId,
    required String title,
    required List<LinkInfo> links,
    required String artist,
    String? album,
    String? albumId,
    List<SongInfoArtistInfo> artists = const <SongInfoArtistInfo>[],
    String? mvId,
    required String artworkUrl,
    required String platformId,
  }) async {
    final track = _buildOnlineTrack(
      songId: songId,
      title: title,
      links: links,
      artist: artist,
      album: album,
      albumId: albumId,
      artists: artists,
      mvId: mvId,
      artworkUrl: artworkUrl,
      platformId: platformId,
    );
    await ref.read(playerControllerProvider.notifier).insertNextTrack(track);
  }

  Future<void> _appendFromOnlineSong({
    required WidgetRef ref,
    required String songId,
    required String title,
    required List<LinkInfo> links,
    required String artist,
    String? album,
    String? albumId,
    List<SongInfoArtistInfo> artists = const <SongInfoArtistInfo>[],
    String? mvId,
    required String artworkUrl,
    required String platformId,
  }) async {
    final track = _buildOnlineTrack(
      songId: songId,
      title: title,
      links: links,
      artist: artist,
      album: album,
      albumId: albumId,
      artists: artists,
      mvId: mvId,
      artworkUrl: artworkUrl,
      platformId: platformId,
    );
    await ref.read(playerControllerProvider.notifier).appendTrack(track);
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

  void _openAlbumDetail({
    required BuildContext context,
    required String albumId,
    required String platformId,
    required String albumTitle,
  }) {
    final localeCode = Localizations.localeOf(context).languageCode;
    final uri = Uri(
      path: AppRoutes.albumDetail,
      queryParameters: <String, String>{
        'id': albumId,
        'platform': platformId,
        'title': albumTitle.isEmpty
            ? AppI18n.tByLocaleCode(localeCode, 'album.fallback_title')
            : albumTitle,
      },
    );
    context.push(uri.toString());
  }

  void _openSongComments({
    required BuildContext context,
    required WidgetRef ref,
    required String songId,
    required String platformId,
    required String title,
  }) {
    final localeCode = Localizations.localeOf(context).languageCode;
    if (!_platformSupports(
      ref: ref,
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

  void _openDiscoverSongMvDetail({
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
    final uri = Uri(
      path: AppRoutes.videoDetail,
      queryParameters: <String, String>{
        'type': 'mv',
        'id': mvId,
        'platform': platformId,
        'title': song.title,
      },
    );
    context.push(uri.toString());
  }

  bool _platformSupports({
    required WidgetRef ref,
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
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(successLabel)));
  }

  void _openDiscoverDetailPage({
    required BuildContext context,
    required String path,
    required String id,
    required String platform,
    required String title,
  }) {
    final resolvedPlatform = platform.trim();
    if (resolvedPlatform.isEmpty) {
      throw StateError(
        'Missing selected platform when opening discover detail.',
      );
    }
    context.push(
      Uri(
        path: path,
        queryParameters: <String, String>{
          'id': id,
          'platform': resolvedPlatform,
          'title': title,
        },
      ).toString(),
    );
  }

  void _openSearchPage({
    required BuildContext context,
    required String? platformId,
  }) {
    if (platformId == null || platformId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('平台未就绪')));
      return;
    }
    final uri = Uri(
      path: AppRoutes.onlineSearch,
      queryParameters: <String, String>{'platform': platformId},
    );
    context.push(uri.toString());
  }

  void _openEntry({
    required BuildContext context,
    required String? platformId,
    required _DiscoverEntry entry,
  }) {
    if (platformId == null || platformId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('平台未就绪')));
      return;
    }
    final uri = switch (entry.type) {
      _DiscoverEntryType.ranking => Uri(
        path: AppRoutes.rankingList,
        queryParameters: <String, String>{'platform': platformId},
      ),
      _DiscoverEntryType.playlist => Uri(
        path: AppRoutes.playlistPlaza,
        queryParameters: <String, String>{'platform': platformId},
      ),
      _DiscoverEntryType.artist => Uri(
        path: AppRoutes.artistPlaza,
        queryParameters: <String, String>{'platform': platformId},
      ),
      _DiscoverEntryType.video => Uri(
        path: AppRoutes.videoPlaza,
        queryParameters: <String, String>{'platform': platformId},
      ),
    };
    context.push(uri.toString());
  }
}

class _HomeHeroSection extends StatelessWidget {
  const _HomeHeroSection({
    required this.config,
    required this.searchPlaceholderPrimary,
    required this.onSearchTap,
    required this.onEntryTap,
    this.searchPlaceholderSecondary,
  });

  final AppConfigState config;
  final String searchPlaceholderPrimary;
  final String? searchPlaceholderSecondary;
  final VoidCallback onSearchTap;
  final ValueChanged<_DiscoverEntry> onEntryTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('现在想听什么', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 14),
        HomeSearchField(
          placeholderPrimary: searchPlaceholderPrimary,
          placeholderSecondary: searchPlaceholderSecondary,
          onTap: onSearchTap,
        ),
        const SizedBox(height: 14),
        _EntryRow(config: config, onTapEntry: onEntryTap),
      ],
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.config, required this.onTapEntry});

  final AppConfigState config;
  final ValueChanged<_DiscoverEntry> onTapEntry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _entries
          .asMap()
          .entries
          .map((entry) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: entry.key == _entries.length - 1 ? 0 : 8,
                ),
                child: _EntryTile(
                  icon: entry.value.icon,
                  title: AppI18n.t(config, entry.value.titleKey),
                  onTap: () => onTapEntry(entry.value),
                ),
              ),
            );
          })
          .toList(growable: false),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.icon, required this.title, this.onTap});

  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Column(
          children: <Widget>[
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: theme.colorScheme.primary, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeBackground extends StatelessWidget {
  const _HomeBackground();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              theme.colorScheme.primaryContainer.withValues(alpha: 0.10),
              theme.colorScheme.surface.withValues(alpha: 0.98),
              theme.scaffoldBackgroundColor,
            ],
          ),
        ),
      ),
    );
  }
}

class _PlatformBar extends StatelessWidget {
  const _PlatformBar({
    required this.selectedPlatformId,
    required this.onSelected,
    required this.chips,
  });

  final String? selectedPlatformId;
  final ValueChanged<String> onSelected;
  final List<_PlatformChipData> chips;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: chips
              .map(
                (chip) => _UnderlineTab(
                  label: chip.label,
                  selected: chip.id == selectedPlatformId,
                  enabled: true,
                  onTap: () => onSelected(chip.id),
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _UnderlineTab extends StatelessWidget {
  const _UnderlineTab({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return UnderlineTab(
      label: label,
      selected: selected,
      enabled: enabled,
      onTap: onTap,
    );
  }
}

class _PlatformChipData {
  const _PlatformChipData({required this.id, required this.label});

  final String id;
  final String label;
}

class _DiscoverEntry {
  const _DiscoverEntry({
    required this.type,
    required this.icon,
    required this.titleKey,
  });

  final _DiscoverEntryType type;
  final IconData icon;
  final String titleKey;
}
