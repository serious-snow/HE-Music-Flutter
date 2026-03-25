import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_message_service.dart';
import '../../../../app/config/app_config_controller.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/network/network_error_message.dart';
import '../../../../shared/helpers/current_track_helper.dart';
import '../../../../shared/helpers/detail_cover_preview_helper.dart';
import '../../../../shared/helpers/detail_song_action_handler.dart';
import '../../../../shared/utils/compact_number_formatter.dart';
import '../../../../shared/utils/cover_resolver.dart';
import '../../../../shared/utils/favorite_song_key.dart';
import '../../../../shared/widgets/detail_description_sheet.dart';
import '../../../../shared/widgets/detail_loading_skeleton.dart';
import '../../../../shared/widgets/detail_page_shell.dart';
import '../../../../shared/widgets/online_song_list_item.dart';
import '../../../my/presentation/providers/favorite_collection_status_providers.dart';
import '../../../my/presentation/providers/favorite_song_status_providers.dart';
import '../../../player/domain/entities/player_queue_source.dart';
import '../../../player/domain/entities/player_track.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../../../online/domain/entities/online_platform.dart';
import '../../../online/presentation/providers/online_providers.dart';
import '../../domain/entities/artist_detail_album.dart';
import '../../domain/entities/artist_detail_content.dart';
import '../../domain/entities/artist_detail_request.dart';
import '../../domain/entities/artist_detail_song.dart';
import '../../domain/entities/artist_detail_state.dart';
import '../../domain/entities/artist_detail_video.dart';
import '../../domain/repositories/artist_detail_repository.dart';
import '../providers/artist_detail_providers.dart';

enum _ArtistDetailTab { songs, albums, videos }

class ArtistDetailPage extends ConsumerStatefulWidget {
  const ArtistDetailPage({
    required this.id,
    required this.platform,
    required this.title,
    super.key,
  });

  final String id;
  final String platform;
  final String title;

  @override
  ConsumerState<ArtistDetailPage> createState() => _ArtistDetailPageState();
}

class _ArtistDetailPageState extends ConsumerState<ArtistDetailPage>
    with SingleTickerProviderStateMixin {
  late final ArtistDetailRequest _request;
  late final DetailSongActionHandler<ArtistDetailSong> _songActions;
  late final TabController _tabController;

  List<ArtistDetailSong> _songs = const <ArtistDetailSong>[];
  List<ArtistDetailAlbum> _albums = const <ArtistDetailAlbum>[];
  List<ArtistDetailVideo> _videos = const <ArtistDetailVideo>[];

  bool _songsLoading = false;
  bool _albumsLoading = false;
  bool _videosLoading = false;

  String? _songsError;
  String? _albumsError;
  String? _videosError;

  @override
  void initState() {
    super.initState();
    _request = ArtistDetailRequest(
      id: widget.id,
      platform: widget.platform,
      title: widget.title,
    );
    _songActions = DetailSongActionHandler<ArtistDetailSong>(
      ref: ref,
      songIdOf: (song) => song.id,
      songTitleOf: (song) => song.title,
      songArtistOf: (song) => song.artist,
      songPlatformOf: (song) => song.platform,
      songCoverOf: (song) => song.cover,
      songArtistsOf: (song) => song.artists,
      songAlbumIdOf: (song) => song.album?.id,
      songAlbumTitleOf: (song) => song.album?.name,
      queueSource: PlayerQueueSource(
        routePath: AppRoutes.artistDetail,
        queryParameters: <String, String>{
          'id': widget.id,
          'platform': widget.platform,
          'title': widget.title,
        },
        title: widget.title,
      ),
    );
    _tabController = TabController(length: 3, vsync: this)
      ..addListener(_handleTabChanged);
    Future.microtask(() async {
      await ref
          .read(artistDetailControllerProvider.notifier)
          .initialize(_request);
      await _loadSongs();
    });
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_handleTabChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(artistDetailControllerProvider);
    final currentTrack = ref.watch(
      playerControllerProvider.select((player) => player.currentTrack),
    );
    final controller = ref.read(artistDetailControllerProvider.notifier);
    final content = state.content;
    final platforms =
        ref.watch(onlinePlatformsProvider).valueOrNull ??
        const <OnlinePlatform>[];

    if (content == null) {
      if (state.loading) {
        return DetailPageShell(
          child: ArtistDetailLoadingBody(title: widget.title),
        );
      }
      return DetailPageShell(
        child: _buildPlaceholderBody(
          context: context,
          state: state,
          onRetry: () => controller.retry(_request),
        ),
      );
    }

    final title = content.title.trim().isEmpty ? widget.title : content.title;
    final coverUrl = resolveTemplateCoverUrl(
      platforms: platforms,
      platformId: content.platform,
      cover: content.coverUrl,
      size: 600,
    );
    final isFavorited = ref.watch(
      favoriteCollectionStatusProvider.select(
        (state) => state.artistKeys.contains(
          '${widget.id.trim()}|${widget.platform.trim()}',
        ),
      ),
    );

    return DetailPageShell(
      child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return <Widget>[
            _ArtistSliverHeader(
              title: title,
              subtitle: content.subtitle.trim(),
              coverUrl: coverUrl,
              description: content.description,
              songCount: _normalizeCount(content.songCount),
              albumCount: _normalizeCount(content.albumCount),
              videoCount: _normalizeCount(content.videoCount),
              onBack: () => Navigator.of(context).maybePop(),
              onPreviewCover: () => _previewCover(title, coverUrl),
              onShowDescription: () => showDetailDescriptionSheet(
                context,
                title: title,
                text: content.description,
              ),
              actions: <Widget>[
                IconButton(
                  onPressed: () => unawaited(
                    _toggleArtistFavorite(isFavorited, content: content),
                  ),
                  icon: Icon(
                    isFavorited
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: isFavorited
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
                  tooltip: isFavorited
                      ? AppI18n.t(
                          ref.read(appConfigProvider),
                          'detail.favorite.remove_artist',
                        )
                      : AppI18n.t(
                          ref.read(appConfigProvider),
                          'detail.favorite.add_artist',
                        ),
                ),
              ],
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _ArtistTabBarHeader(
                child: Material(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: false,
                    dividerColor: Colors.transparent,
                    splashFactory: NoSplash.splashFactory,
                    overlayColor: WidgetStateProperty.all(Colors.transparent),
                    labelStyle: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                    unselectedLabelStyle: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                    tabs: <Tab>[
                      Tab(text: AppI18n.t(ref.read(appConfigProvider), 'artist.tab.song')),
                      Tab(text: AppI18n.t(ref.read(appConfigProvider), 'artist.tab.album')),
                      Tab(text: AppI18n.t(ref.read(appConfigProvider), 'artist.tab.video')),
                    ],
                  ),
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: <Widget>[
            _ArtistSongsTab(
              songs: _songs,
              currentTrack: currentTrack,
              loading: _songsLoading,
              error: _songsError,
              onRetry: _loadSongs,
              onPlayAll: _songs.isEmpty
                  ? null
                  : () => _songActions.playAll(context, _songs),
              resolveSongCover: _songActions.resolveCoverUrl,
              onTapSong: (song, coverUrl, index) =>
                  _songActions.playAll(context, _songs, startIndex: index),
              isSongLiked: (song) => ref.read(
                favoriteSongStatusProvider.select(
                  (state) => state.songKeys.contains(
                    buildFavoriteSongKey(
                      songId: song.id,
                      platform: song.platform,
                    ),
                  ),
                ),
              ),
              onLikeSong: _toggleSongLike,
              onMoreSong: (song, coverUrl) => _songActions.showSongActions(
                context: context,
                song: song,
                coverUrl: coverUrl,
              ),
            ),
            _ArtistAlbumsTab(
              albums: _albums,
              loading: _albumsLoading,
              error: _albumsError,
              platforms: platforms,
              onRetry: _loadAlbums,
              onTapAlbum: _openAlbumDetail,
            ),
            _ArtistVideosTab(
              videos: _videos,
              loading: _videosLoading,
              error: _videosError,
              platforms: platforms,
              onRetry: _loadVideos,
              onTapVideo: _openVideoDetail,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderBody({
    required BuildContext context,
    required ArtistDetailState state,
    required VoidCallback onRetry,
  }) {
    if (state.loading) {
      return ArtistDetailLoadingBody(title: widget.title);
    }
    if (state.errorMessage != null) {
      return DetailErrorBody(message: state.errorMessage!, onRetry: onRetry);
    }
    return const Center(child: Text('No artist detail content.'));
  }

  String _normalizeCount(String value) {
    final parsed = int.tryParse(value.trim());
    if (parsed == null || parsed < 0) {
      return '0';
    }
    return '$parsed';
  }

  Future<void> _previewCover(String title, String coverUrl) {
    return showDetailCoverPreview(
      context: context,
      ref: ref,
      title: title,
      imageUrl: coverUrl,
    );
  }

  void _handleTabChanged() {
    if (_tabController.indexIsChanging) {
      return;
    }
    switch (_ArtistDetailTab.values[_tabController.index]) {
      case _ArtistDetailTab.songs:
        if (_songs.isEmpty && !_songsLoading && _songsError == null) {
          unawaited(_loadSongs());
        }
      case _ArtistDetailTab.albums:
        if (_albums.isEmpty && !_albumsLoading && _albumsError == null) {
          unawaited(_loadAlbums());
        }
      case _ArtistDetailTab.videos:
        if (_videos.isEmpty && !_videosLoading && _videosError == null) {
          unawaited(_loadVideos());
        }
    }
  }

  Future<void> _loadSongs() async {
    if (_songsLoading) {
      return;
    }
    setState(() {
      _songsLoading = true;
      _songsError = null;
    });
    try {
      final songs = await _repository.fetchSongs(_request);
      if (!mounted) {
        return;
      }
      setState(() {
        _songs = songs;
        _songsLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _songsLoading = false;
        _songsError = '$error';
      });
    }
  }

  Future<void> _toggleSongLike(ArtistDetailSong song) async {
    final liked = ref.read(
      favoriteSongStatusProvider.select(
        (state) => state.songKeys.contains(
          buildFavoriteSongKey(songId: song.id, platform: song.platform),
        ),
      ),
    );
    try {
      await ref
          .read(onlineControllerProvider.notifier)
          .toggleSongFavorite(
            songId: song.id,
            platform: song.platform,
            like: !liked,
          );
    } catch (error) {
      AppMessageService.showError('$error');
    }
  }

  Future<void> _toggleArtistFavorite(
    bool isFavorited, {
    required ArtistDetailContent content,
  }) async {
    try {
      await ref
          .read(onlineControllerProvider.notifier)
          .toggleArtistFavorite(
            artistId: widget.id,
            platform: widget.platform,
            name: content.title,
            cover: content.coverUrl,
            like: !isFavorited,
          );
    } catch (error) {
      AppMessageService.showError(
        NetworkErrorMessage.resolve(error) ??
            AppI18n.t(
              ref.read(appConfigProvider),
              'detail.favorite.artist_failed',
            ),
      );
    }
  }

  Future<void> _loadAlbums() async {
    if (_albumsLoading) {
      return;
    }
    setState(() {
      _albumsLoading = true;
      _albumsError = null;
    });
    try {
      final albums = await _repository.fetchAlbums(_request);
      if (!mounted) {
        return;
      }
      setState(() {
        _albums = albums;
        _albumsLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _albumsLoading = false;
        _albumsError = '$error';
      });
    }
  }

  Future<void> _loadVideos() async {
    if (_videosLoading) {
      return;
    }
    setState(() {
      _videosLoading = true;
      _videosError = null;
    });
    try {
      final videos = await _repository.fetchVideos(_request);
      if (!mounted) {
        return;
      }
      setState(() {
        _videos = videos;
        _videosLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _videosLoading = false;
        _videosError = '$error';
      });
    }
  }

  void _openAlbumDetail(ArtistDetailAlbum album) {
    final uri = Uri(
      path: AppRoutes.albumDetail,
      queryParameters: <String, String>{
        'type': 'album',
        'id': album.id,
        'platform': album.platform,
        'title': album.name,
      },
    );
    context.push(uri.toString());
  }

  void _openVideoDetail(ArtistDetailVideo video) {
    final uri = Uri(
      path: AppRoutes.videoDetail,
      queryParameters: <String, String>{
        'type': 'mv',
        'id': video.id,
        'platform': video.platform,
        'title': video.name,
      },
    );
    context.push(uri.toString());
  }

  ArtistDetailRepository get _repository {
    return ref.read(artistDetailRepositoryProvider);
  }
}

class _ArtistTabBarHeader extends SliverPersistentHeaderDelegate {
  const _ArtistTabBarHeader({required this.child});

  final Widget child;

  @override
  double get minExtent => 48;

  @override
  double get maxExtent => 48;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox(height: maxExtent, child: child);
  }

  @override
  bool shouldRebuild(covariant _ArtistTabBarHeader oldDelegate) {
    return oldDelegate.child != child;
  }
}

class _ArtistSliverHeader extends StatelessWidget {
  const _ArtistSliverHeader({
    required this.title,
    required this.subtitle,
    required this.coverUrl,
    required this.description,
    required this.songCount,
    required this.albumCount,
    required this.videoCount,
    required this.onBack,
    required this.onPreviewCover,
    required this.onShowDescription,
    this.actions = const <Widget>[],
  });

  static const double expandedHeight = 308;

  final String title;
  final String subtitle;
  final String coverUrl;
  final String description;
  final String songCount;
  final String albumCount;
  final String videoCount;
  final VoidCallback onBack;
  final VoidCallback onPreviewCover;
  final VoidCallback onShowDescription;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SliverAppBar(
      pinned: true,
      expandedHeight: expandedHeight,
      automaticallyImplyLeading: false,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final topPadding = MediaQuery.paddingOf(context).top;
          final minHeight = topPadding + kToolbarHeight;
          final progress =
              ((constraints.maxHeight - minHeight) /
                      (expandedHeight - minHeight))
                  .clamp(0.0, 1.0);
          final collapse = (1.0 - progress).clamp(0.0, 1.0);
          final toolbarOpacity = (collapse - 0.2).clamp(0.0, 1.0);
          final backgroundOpacity = 1.0 - (1.0 - collapse) * (1.0 - collapse);
          final toolbarBg = Color.lerp(
            Colors.transparent,
            theme.scaffoldBackgroundColor,
            backgroundOpacity,
          )!;
          final iconColor = Color.lerp(
            Colors.white,
            theme.iconTheme.color ?? Colors.black,
            toolbarOpacity,
          )!;
          final titleColor = Color.lerp(
            Colors.white,
            theme.textTheme.titleMedium?.color ?? Colors.black,
            toolbarOpacity,
          )!;
          final collapsedOverlayStyle = theme.brightness == Brightness.dark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark;
          final overlayStyle =
              (toolbarOpacity > 0.58
                      ? collapsedOverlayStyle
                      : SystemUiOverlayStyle.light)
                  .copyWith(statusBarColor: Colors.transparent);
          final bottomPanelColor = theme.colorScheme.surface.withValues(
            alpha: 0.94 - 0.18 * collapse,
          );
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: overlayStyle,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                ClipRect(
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      _ArtistHeaderImage(url: coverUrl),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: <Color>[
                              Colors.black.withValues(
                                alpha: 0.18 + 0.14 * collapse,
                              ),
                              Colors.black.withValues(
                                alpha: 0.04 + 0.06 * collapse,
                              ),
                              Colors.transparent,
                            ],
                            stops: const <double>[0, 0.32, 0.62],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 170,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: <Color>[
                                  bottomPanelColor.withValues(alpha: 0.0),
                                  bottomPanelColor.withValues(alpha: 0.42),
                                  bottomPanelColor,
                                ],
                                stops: const <double>[0.0, 0.46, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (coverUrl.trim().isNotEmpty)
                        Positioned.fill(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: onPreviewCover,
                          ),
                        ),
                      Align(
                        alignment: Alignment.bottomLeft,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                          child: Opacity(
                            opacity: progress,
                            child: _ArtistHeaderMeta(
                              title: title,
                              subtitle: subtitle,
                              description: description,
                              songCount: songCount,
                              albumCount: albumCount,
                              videoCount: videoCount,
                              onShowDescription: onShowDescription,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    color: toolbarBg,
                    child: SafeArea(
                      bottom: false,
                      child: SizedBox(
                        height: kToolbarHeight,
                        child: Row(
                          children: <Widget>[
                            IconButton(
                              onPressed: onBack,
                              icon: Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: iconColor,
                              ),
                            ),
                            Expanded(
                              child: Opacity(
                                opacity: toolbarOpacity,
                                child: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: titleColor,
                                  ),
                                ),
                              ),
                            ),
                            if (actions.isNotEmpty) ...<Widget>[
                              ...actions,
                              const SizedBox(width: 4),
                            ],
                            const SizedBox(width: 12),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ArtistHeaderMeta extends StatelessWidget {
  const _ArtistHeaderMeta({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.songCount,
    required this.albumCount,
    required this.videoCount,
    required this.onShowDescription,
  });

  final String title;
  final String subtitle;
  final String description;
  final String songCount;
  final String albumCount;
  final String videoCount;
  final VoidCallback onShowDescription;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    return SizedBox(
      height: 114,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          if (subtitle.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.92,
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              _ArtistMetaIcon(
                icon: Icons.music_note_rounded,
                label: AppI18n.formatByLocaleCode(
                  Localizations.localeOf(context).languageCode,
                  'artist.meta.song_count',
                  <String, String>{'count': songCount.toString()},
                ),
              ),
              const SizedBox(width: 14),
              _ArtistMetaIcon(
                icon: Icons.album_rounded,
                label: AppI18n.formatByLocaleCode(
                  Localizations.localeOf(context).languageCode,
                  'artist.meta.album_count',
                  <String, String>{'count': albumCount.toString()},
                ),
              ),
              const SizedBox(width: 14),
              _ArtistMetaIcon(
                icon: Icons.videocam_rounded,
                label: AppI18n.formatByLocaleCode(
                  Localizations.localeOf(context).languageCode,
                  'artist.meta.video_count',
                  <String, String>{'count': videoCount.toString()},
                ),
              ),
            ],
          ),
          if (description.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            InkWell(
              onTap: onShowDescription,
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      description.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.92,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.keyboard_arrow_right_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.80,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ArtistMetaIcon extends StatelessWidget {
  const _ArtistMetaIcon({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(
      context,
    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.90);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }
}

class _ArtistHeaderImage extends StatelessWidget {
  const _ArtistHeaderImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.trim().isEmpty) {
      return Container(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
      );
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
        );
      },
    );
  }
}

class _ArtistSongsTab extends StatelessWidget {
  const _ArtistSongsTab({
    required this.songs,
    required this.currentTrack,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onPlayAll,
    required this.resolveSongCover,
    required this.onTapSong,
    required this.isSongLiked,
    required this.onLikeSong,
    required this.onMoreSong,
  });

  final List<ArtistDetailSong> songs;
  final PlayerTrack? currentTrack;
  final bool loading;
  final String? error;
  final Future<void> Function() onRetry;
  final VoidCallback? onPlayAll;
  final String Function(ArtistDetailSong song) resolveSongCover;
  final Future<void> Function(ArtistDetailSong song, String coverUrl, int index)
  onTapSong;
  final bool Function(ArtistDetailSong song) isSongLiked;
  final Future<void> Function(ArtistDetailSong song) onLikeSong;
  final void Function(ArtistDetailSong song, String coverUrl) onMoreSong;

  @override
  Widget build(BuildContext context) {
    final localeCode = Localizations.localeOf(context).languageCode;
    return CustomScrollView(
      key: const PageStorageKey<String>('artist-detail-songs'),
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: _InlinePlayAllRow(
            countText: AppI18n.formatByLocaleCode(
              localeCode,
              'detail.play_all_count',
              <String, String>{'count': '${songs.length}'},
            ),
            enabled: songs.isNotEmpty,
            onTap: onPlayAll,
          ),
        ),
        if (loading && songs.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: true,
            child: ArtistSongsLoadingView(),
          )
        else if (error != null && songs.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _TabErrorView(message: error!, onRetry: onRetry),
          )
        else if (songs.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _TabEmptyView(
              message: AppI18n.tByLocaleCode(localeCode, 'artist.empty.song'),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final song = songs[index];
              final songCover = resolveSongCover(song);
              return OnlineSongListItem(
                song: song,
                coverUrl: songCover.trim().isEmpty ? null : songCover,
                isCurrent: isCurrentSongTrack(currentTrack, song),
                isLiked: isSongLiked(song),
                onTap: () => unawaited(onTapSong(song, songCover, index)),
                onLikeTap: () => unawaited(onLikeSong(song)),
                onMoreTap: () => onMoreSong(song, songCover),
              );
            }, childCount: songs.length),
          ),
      ],
    );
  }
}

class _ArtistAlbumsTab extends StatelessWidget {
  const _ArtistAlbumsTab({
    required this.albums,
    required this.loading,
    required this.error,
    required this.platforms,
    required this.onRetry,
    required this.onTapAlbum,
  });

  final List<ArtistDetailAlbum> albums;
  final bool loading;
  final String? error;
  final List<OnlinePlatform> platforms;
  final Future<void> Function() onRetry;
  final ValueChanged<ArtistDetailAlbum> onTapAlbum;

  @override
  Widget build(BuildContext context) {
    final localeCode = Localizations.localeOf(context).languageCode;
    return CustomScrollView(
      key: const PageStorageKey<String>('artist-detail-albums'),
      slivers: <Widget>[
        if (loading && albums.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: true,
            child: ArtistAlbumsLoadingView(),
          )
        else if (error != null && albums.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _TabErrorView(message: error!, onRetry: onRetry),
          )
        else if (albums.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _TabEmptyView(
              message: AppI18n.tByLocaleCode(localeCode, 'artist.empty.album'),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final album = albums[index];
              return _ArtistAlbumItem(
                album: album,
                coverUrl: resolveTemplateCoverUrl(
                  platforms: platforms,
                  platformId: album.platform,
                  cover: album.cover,
                  size: 300,
                ),
                onTap: () => onTapAlbum(album),
              );
            }, childCount: albums.length),
          ),
      ],
    );
  }
}

class _ArtistVideosTab extends StatelessWidget {
  const _ArtistVideosTab({
    required this.videos,
    required this.loading,
    required this.error,
    required this.platforms,
    required this.onRetry,
    required this.onTapVideo,
  });

  final List<ArtistDetailVideo> videos;
  final bool loading;
  final String? error;
  final List<OnlinePlatform> platforms;
  final Future<void> Function() onRetry;
  final ValueChanged<ArtistDetailVideo> onTapVideo;

  @override
  Widget build(BuildContext context) {
    final localeCode = Localizations.localeOf(context).languageCode;
    return CustomScrollView(
      key: const PageStorageKey<String>('artist-detail-videos'),
      slivers: <Widget>[
        if (loading && videos.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: true,
            child: ArtistVideosLoadingView(),
          )
        else if (error != null && videos.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _TabErrorView(message: error!, onRetry: onRetry),
          )
        else if (videos.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _TabEmptyView(
              message: AppI18n.tByLocaleCode(localeCode, 'artist.empty.video'),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final video = videos[index];
              return _ArtistVideoItem(
                video: video,
                coverUrl: resolveTemplateCoverUrl(
                  platforms: platforms,
                  platformId: video.platform,
                  cover: video.cover,
                  size: 480,
                ),
                onTap: () => onTapVideo(video),
              );
            }, childCount: videos.length),
          ),
      ],
    );
  }
}

class _InlinePlayAllRow extends StatelessWidget {
  const _InlinePlayAllRow({
    required this.countText,
    required this.enabled,
    required this.onTap,
  });

  final String countText;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectivePrimary = enabled
        ? theme.colorScheme.primary
        : theme.hintColor.withValues(alpha: 0.55);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 8, 10, 8),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.play_circle_fill_rounded,
                size: 22,
                color: effectivePrimary,
              ),
              const SizedBox(width: 8),
              Text(
                countText,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: enabled ? null : theme.hintColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArtistAlbumItem extends StatelessWidget {
  const _ArtistAlbumItem({
    required this.album,
    required this.coverUrl,
    required this.onTap,
  });

  final ArtistDetailAlbum album;
  final String coverUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: <Widget>[
            _SquareCover(url: coverUrl, icon: Icons.album_rounded),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    album.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _albumArtistText(album).isEmpty
                        ? AppI18n.tByLocaleCode(
                            Localizations.localeOf(context).languageCode,
                            'artist.unknown_artist',
                          )
                        : _albumArtistText(album),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _albumMeta(album),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor.withValues(alpha: 0.86),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _albumMeta(ArtistDetailAlbum album) {
    final values = <String>[];
    if (album.songCount.trim().isNotEmpty && album.songCount.trim() != '0') {
      values.add('${album.songCount} 首');
    }
    final publishDate = _formatPublishDate(album.publishTime);
    if (publishDate.isNotEmpty) {
      values.add(publishDate);
    }
    if (values.isEmpty) {
      return AppI18n.tByLocaleCode(
        WidgetsBinding.instance.platformDispatcher.locale.languageCode,
        'artist.tab.album',
      );
    }
    return values.join(' · ');
  }

  String _albumArtistText(ArtistDetailAlbum album) {
    final names = album.artists
        .map((item) => item.name.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    return names.join(' / ');
  }

  String _formatPublishDate(String raw) {
    final normalized = raw.trim();
    if (normalized.isEmpty) {
      return '';
    }
    final timestamp = int.tryParse(normalized);
    DateTime? date;
    if (timestamp != null) {
      final milliseconds = timestamp > 100000000000
          ? timestamp
          : timestamp * 1000;
      date = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    } else {
      date = DateTime.tryParse(normalized);
    }
    if (date == null) {
      return normalized;
    }
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}

class _ArtistVideoItem extends StatelessWidget {
  const _ArtistVideoItem({
    required this.video,
    required this.coverUrl,
    required this.onTap,
  });

  final ArtistDetailVideo video;
  final String coverUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _VideoCover(
              url: coverUrl,
              durationLabel: formatDurationSecondsLabel('${video.duration}'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    video.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    video.creator.trim().isEmpty ? '未知作者' : video.creator,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    video.playCount.trim().isEmpty
                        ? '0 播放'
                        : '${formatCompactPlayCount(video.playCount, locale)} 播放',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor.withValues(alpha: 0.86),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SquareCover extends StatelessWidget {
  const _SquareCover({required this.url, required this.icon});

  final String url;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 22, color: Theme.of(context).hintColor),
    );
    if (url.trim().isEmpty) {
      return fallback;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        url,
        width: 58,
        height: 58,
        fit: BoxFit.cover,
        cacheWidth: 180,
        errorBuilder: (context, error, stackTrace) => fallback,
      ),
    );
  }
}

class _VideoCover extends StatelessWidget {
  const _VideoCover({required this.url, required this.durationLabel});

  final String url;
  final String durationLabel;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: 112,
      height: 64,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        Icons.video_library_rounded,
        size: 24,
        color: Theme.of(context).hintColor,
      ),
    );
    return Stack(
      children: <Widget>[
        if (url.trim().isEmpty)
          fallback
        else
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              url,
              width: 112,
              height: 64,
              fit: BoxFit.cover,
              cacheWidth: 280,
              errorBuilder: (context, error, stackTrace) => fallback,
            ),
          ),
        Positioned(
          right: 6,
          bottom: 6,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text(
                durationLabel,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TabErrorView extends StatelessWidget {
  const _TabErrorView({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => unawaited(onRetry()),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabEmptyView extends StatelessWidget {
  const _TabEmptyView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor),
      ),
    );
  }
}
