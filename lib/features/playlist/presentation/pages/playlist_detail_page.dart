import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/app_message_service.dart';
import '../../../../app/config/app_config_controller.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/network/network_error_message.dart';
import '../../../../shared/constants/layout_tokens.dart';
import '../../../../shared/helpers/current_track_helper.dart';
import '../../../../shared/helpers/detail_cover_preview_helper.dart';
import '../../../../shared/helpers/detail_song_action_handler.dart';
import '../../../../shared/utils/compact_number_formatter.dart';
import '../../../../shared/utils/favorite_song_key.dart';
import '../../../../shared/widgets/detail_description_sheet.dart';
import '../../../../shared/widgets/detail_page_shell.dart';
import '../../../../shared/widgets/music_detail_slivers.dart';
import '../../../../shared/widgets/online_song_list_item.dart';
import '../../../../shared/widgets/song_list_component.dart';
import '../../../my/presentation/providers/favorite_collection_status_providers.dart';
import '../../../my/presentation/providers/favorite_song_status_providers.dart';
import '../../../online/presentation/providers/online_providers.dart';
import '../../../player/domain/entities/player_queue_source.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../../domain/entities/playlist_detail_content.dart';
import '../../domain/entities/playlist_detail_request.dart';
import '../../domain/entities/playlist_detail_song.dart';
import '../../domain/entities/playlist_detail_state.dart';
import '../providers/playlist_detail_providers.dart';

class PlaylistDetailPage extends ConsumerStatefulWidget {
  const PlaylistDetailPage({
    required this.id,
    required this.platform,
    required this.title,
    super.key,
  });

  final String id;
  final String platform;
  final String title;

  @override
  ConsumerState<PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends ConsumerState<PlaylistDetailPage> {
  late final PlaylistDetailRequest _request;
  late final DetailSongActionHandler<PlaylistDetailSong> _songActions;

  @override
  void initState() {
    super.initState();
    _request = PlaylistDetailRequest(
      id: widget.id,
      platform: widget.platform,
      title: widget.title,
    );
    _songActions = DetailSongActionHandler<PlaylistDetailSong>(
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
        routePath: AppRoutes.playlistDetail,
        queryParameters: <String, String>{
          'id': widget.id,
          'platform': widget.platform,
          'title': widget.title,
        },
        title: widget.title,
      ),
    );
    Future.microtask(() {
      ref.read(playlistDetailControllerProvider.notifier).initialize(_request);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playlistDetailControllerProvider);
    final controller = ref.read(playlistDetailControllerProvider.notifier);
    final content = state.content;

    if (content == null) {
      if (state.loading) {
        return DetailPageShell(child: DetailLoadingBody(title: widget.title));
      }
      return DetailPageShell(
        child: _buildPlaceholderBody(
          context: context,
          state: state,
          onRetry: () => controller.retry(_request),
        ),
      );
    }

    return DetailPageShell(
      child: _buildDetailBody(context: context, content: content),
    );
  }

  Widget _buildPlaceholderBody({
    required BuildContext context,
    required PlaylistDetailState state,
    required VoidCallback onRetry,
  }) {
    if (state.loading) {
      return DetailLoadingBody(title: widget.title);
    }
    if (state.errorMessage != null) {
      return DetailErrorBody(message: state.errorMessage!, onRetry: onRetry);
    }
    return Center(
      child: Text(AppI18n.t(ref.read(appConfigProvider), 'detail.no_playlist_content')),
    );
  }

  Widget _buildDetailBody({
    required BuildContext context,
    required PlaylistDetailContent content,
  }) {
    final title = content.title.trim().isEmpty ? widget.title : content.title;
    final subtitle = content.subtitle.trim();
    final coverUrl = content.coverUrl.trim();
    final description = content.description;
    final songs = content.songs;
    final currentTrack = ref.watch(
      playerControllerProvider.select((state) => state.currentTrack),
    );
    final isFavorited = ref.watch(
      favoriteCollectionStatusProvider.select(
        (state) => state.playlistKeys.contains(
          '${widget.id.trim()}|${widget.platform.trim()}',
        ),
      ),
    );
    final metaItems = _buildMetaItems(context, content, songs.length);

    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return <Widget>[
          MusicDetailSliverAppBar(
            title: title,
            subtitle: subtitle,
            coverUrl: coverUrl,
            description: description,
            metaItems: metaItems,
            actions: <Widget>[
              IconButton(
                onPressed: () => unawaited(
                  _togglePlaylistFavorite(
                    isFavorited,
                    title: title,
                    coverUrl: coverUrl,
                    creator: subtitle,
                  ),
                ),
                icon: Icon(
                  isFavorited
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                ),
                tooltip: isFavorited
                    ? AppI18n.t(
                        ref.read(appConfigProvider),
                        'detail.favorite.remove_playlist',
                      )
                    : AppI18n.t(
                        ref.read(appConfigProvider),
                        'detail.favorite.add_playlist',
                      ),
              ),
            ],
            onPreviewCover: () => _previewCover(title, coverUrl),
            onBack: () => Navigator.of(context).maybePop(),
            onShowDescription: () => showDetailDescriptionSheet(
              context,
              title: title,
              text: description,
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: MusicDetailPlayAllHeader(
              countText: AppI18n.format(
                ref.read(appConfigProvider),
                'detail.play_all_count',
                <String, String>{'count': '${songs.length}'},
              ),
              onPlayAll: () => _songActions.playAll(context, songs),
            ),
          ),
        ];
      },
      body: Padding(
        padding: const EdgeInsets.fromLTRB(
          LayoutTokens.listItemInnerGutter,
          0,
          LayoutTokens.listItemInnerGutter,
          0,
        ),
        child: SongListComponent(
          itemCount: songs.length,
          itemBuilder: (context, index) {
            final song = songs[index];
            final songCover = _songActions.resolveCoverUrl(song);
            final isLiked = ref.watch(
              favoriteSongStatusProvider.select(
                (state) => state.songKeys.contains(
                  buildFavoriteSongKey(
                    songId: song.id,
                    platform: song.platform,
                  ),
                ),
              ),
            );
            return OnlineSongListItem(
              song: song,
              coverUrl: songCover.trim().isEmpty ? null : songCover,
              isCurrent: isCurrentSongTrack(currentTrack, song),
              isLiked: isLiked,
              onTap: () => unawaited(
                _songActions.playAll(context, songs, startIndex: index),
              ),
              onLikeTap: () => unawaited(_toggleSongLike(song)),
              onMoreTap: () => _songActions.showSongActions(
                context: context,
                song: song,
                coverUrl: songCover,
              ),
            );
          },
          enablePaging: false,
          empty: Center(
            child: Text(
              AppI18n.t(ref.read(appConfigProvider), 'detail.empty_songs'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).hintColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<MusicDetailMetaItem> _buildMetaItems(
    BuildContext context,
    PlaylistDetailContent content,
    int fallbackSongCount,
  ) {
    final locale = Localizations.localeOf(context);
    final items = <MusicDetailMetaItem>[];
    final playCount = content.playCount.trim();
    final songCount = content.songCount.trim();
    if (playCount.isNotEmpty) {
      items.add(
        MusicDetailMetaItem(
          icon: Icons.headphones_rounded,
          label: AppI18n.format(
            ref.read(appConfigProvider),
            'detail.play_count',
            <String, String>{
              'count': formatCompactPlayCount(playCount, locale),
            },
          ),
        ),
      );
    }
    final effectiveSongCount = songCount.isNotEmpty
        ? songCount
        : '$fallbackSongCount';
    if (effectiveSongCount.trim().isNotEmpty) {
      items.add(
        MusicDetailMetaItem(
          icon: Icons.music_note_rounded,
          label: AppI18n.format(
            ref.read(appConfigProvider),
            'detail.track_count',
            <String, String>{'count': effectiveSongCount},
          ),
        ),
      );
    }
    return items;
  }

  Future<void> _previewCover(String title, String coverUrl) {
    return showDetailCoverPreview(
      context: context,
      ref: ref,
      title: title,
      imageUrl: coverUrl,
    );
  }

  Future<void> _toggleSongLike(PlaylistDetailSong song) async {
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

  Future<void> _togglePlaylistFavorite(
    bool isFavorited, {
    required String title,
    required String coverUrl,
    required String creator,
  }) async {
    try {
      await ref
          .read(onlineControllerProvider.notifier)
          .togglePlaylistFavorite(
            playlistId: widget.id,
            platform: widget.platform,
            name: title,
            cover: coverUrl,
            creator: creator,
            like: !isFavorited,
          );
    } catch (error) {
      AppMessageService.showError(
        NetworkErrorMessage.resolve(error) ??
            AppI18n.t(
              ref.read(appConfigProvider),
              'detail.favorite.playlist_failed',
            ),
      );
    }
  }
}
