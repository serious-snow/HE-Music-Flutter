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
import '../../../../shared/helpers/song_batch_helpers.dart';
import '../../../../shared/models/he_music_models.dart';
import '../../../../shared/widgets/detail_description_sheet.dart';
import '../../../../shared/widgets/detail_page_shell.dart';
import '../../../../shared/widgets/music_detail_slivers.dart';
import '../../../../shared/widgets/online_song_list_item.dart';
import '../../../../shared/utils/cover_resolver.dart';
import '../../../../shared/widgets/select_user_playlist_sheet.dart';
import '../../../../shared/widgets/song_batch_action_bar.dart';
import '../../../../shared/widgets/song_list_component.dart';
import '../../../my/presentation/providers/user_playlist_song_providers.dart';
import '../../../player/domain/entities/player_queue_source.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../../../online/domain/entities/online_platform.dart';
import '../../../online/presentation/providers/online_providers.dart';
import '../../domain/entities/ranking_detail_request.dart';
import '../../domain/entities/ranking_song.dart';
import '../controllers/ranking_detail_controller.dart';

final rankingDetailControllerProvider =
    NotifierProvider.autoDispose<RankingDetailController, RankingDetailState>(
      RankingDetailController.new,
    );

class RankingDetailPage extends ConsumerStatefulWidget {
  const RankingDetailPage({
    required this.id,
    required this.platform,
    this.title,
    super.key,
  });

  final String id;
  final String platform;
  final String? title;

  @override
  ConsumerState<RankingDetailPage> createState() => _RankingDetailPageState();
}

class _RankingDetailPageState extends ConsumerState<RankingDetailPage> {
  late final RankingDetailRequest _request;
  late final DetailSongActionHandler<RankingSong> _songActions;
  bool _isBatchMode = false;
  bool _submittingBatch = false;
  Set<String> _selectedSongKeys = <String>{};

  @override
  void initState() {
    super.initState();
    _request = RankingDetailRequest(
      id: widget.id,
      platform: widget.platform,
      title: widget.title,
    );
    _songActions = DetailSongActionHandler<RankingSong>(
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
        routePath: AppRoutes.rankingDetail,
        queryParameters: <String, String>{
          'id': widget.id,
          'platform': widget.platform,
          if ((widget.title ?? '').trim().isNotEmpty) 'title': widget.title!,
        },
        title: widget.title ?? '榜单',
      ),
    );
    Future.microtask(() {
      ref.read(rankingDetailControllerProvider.notifier).initialize(_request);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rankingDetailControllerProvider);
    final controller = ref.read(rankingDetailControllerProvider.notifier);
    final title = state.detail?.info.name ?? widget.title ?? '榜单';

    return DetailPageShell(
      bottomBar: _isBatchMode
          ? SongBatchActionBar(
              enabled: _selectedSongs(state.songs).isNotEmpty,
              loading: _submittingBatch,
              onPlayPressed: () => unawaited(_playSelectedSongs(state.songs)),
              onAddToQueuePressed: () =>
                  unawaited(_appendSelectedSongsToQueue(state.songs)),
              onAddToPlaylistPressed: () =>
                  unawaited(_addSelectedSongsToPlaylist(state.songs)),
            )
          : null,
      child: state.loading
          ? DetailLoadingBody(title: widget.title ?? '榜单')
          : state.errorMessage != null
          ? DetailErrorBody(
              message: state.errorMessage!,
              onRetry: () => controller.retry(_request),
            )
          : _Body(
              request: _request,
              state: state,
              onLoadMore: () => controller.loadMore(_request),
              onPreviewCover: (title, coverUrl) =>
                  _previewCover(title, coverUrl),
              onPlaySong: (song, coverUrl, index) =>
                  _songActions.playAll(context, state.songs, startIndex: index),
              onMoreSong: (song, coverUrl) => _songActions.showSongActions(
                context: context,
                song: song,
                coverUrl: coverUrl,
              ),
              onPlayAll: () => _songActions.playAll(context, state.songs),
              batchMode: _isBatchMode,
              selectedSongKeys: _selectedSongKeys,
              selectedCount: _selectedSongs(state.songs).length,
              allSelected: areAllLoadedSongsSelected(
                state.songs,
                _selectedSongKeys,
                songIdOf: (song) => song.id,
                platformOf: (song) => song.platform,
              ),
              onEnterBatchMode: () => _setBatchMode(true),
              onCancelBatch: () => _setBatchMode(false),
              onSelectAllLoaded: () => _selectAllLoadedSongs(state.songs),
              onToggleSongSelection: _toggleSongSelection,
              onShowDescription: (text) =>
                  showDetailDescriptionSheet(context, title: title, text: text),
            ),
    );
  }

  Future<void> _previewCover(String title, String coverUrl) {
    return showDetailCoverPreview(
      context: context,
      ref: ref,
      title: title,
      imageUrl: coverUrl,
    );
  }

  void _setBatchMode(bool enabled) {
    setState(() {
      _isBatchMode = enabled;
      _submittingBatch = false;
      if (!enabled) {
        _selectedSongKeys = <String>{};
      }
    });
  }

  void _toggleSongSelection(RankingSong song) {
    final key = buildSongBatchKey(songId: song.id, platform: song.platform);
    setState(() {
      if (_selectedSongKeys.contains(key)) {
        _selectedSongKeys.remove(key);
      } else {
        _selectedSongKeys.add(key);
      }
    });
  }

  void _selectAllLoadedSongs(List<RankingSong> songs) {
    final nextSelection = buildLoadedSongBatchKeys(
      songs,
      songIdOf: (song) => song.id,
      platformOf: (song) => song.platform,
    );
    setState(() {
      _selectedSongKeys =
          nextSelection.isNotEmpty &&
              nextSelection.every(_selectedSongKeys.contains)
          ? <String>{}
          : nextSelection;
    });
  }

  List<IdPlatformInfo> _selectedSongs(List<RankingSong> songs) {
    return collectSelectedSongIdPlatforms(
      songs,
      _selectedSongKeys,
      songIdOf: (song) => song.id,
      platformOf: (song) => song.platform,
    );
  }

  List<RankingSong> _selectedSongItems(List<RankingSong> songs) {
    return collectSelectedSongItems(
      songs,
      _selectedSongKeys,
      songIdOf: (song) => song.id,
      platformOf: (song) => song.platform,
    );
  }

  Future<void> _playSelectedSongs(List<RankingSong> songs) async {
    final selectedSongs = _selectedSongItems(songs);
    if (selectedSongs.isEmpty || _submittingBatch) {
      return;
    }
    await _songActions.playAll(context, selectedSongs);
    if (!mounted) {
      return;
    }
    _setBatchMode(false);
  }

  Future<void> _appendSelectedSongsToQueue(List<RankingSong> songs) async {
    final selectedSongs = _selectedSongItems(songs);
    if (selectedSongs.isEmpty || _submittingBatch) {
      return;
    }
    setState(() {
      _submittingBatch = true;
    });
    try {
      await _songActions.appendAllToQueue(selectedSongs);
      if (!mounted) {
        return;
      }
      _setBatchMode(false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppI18n.t(ref.read(appConfigProvider), 'search.queue.appended'),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submittingBatch = false;
      });
      AppMessageService.showError(
        NetworkErrorMessage.resolve(error) ?? '$error',
      );
    }
  }

  Future<void> _addSelectedSongsToPlaylist(List<RankingSong> songs) async {
    final selectedSongs = _selectedSongs(songs);
    if (selectedSongs.isEmpty || _submittingBatch) {
      return;
    }
    final playlistId = await showSelectUserPlaylistSheet(context);
    if (playlistId == null || !mounted) {
      return;
    }
    setState(() {
      _submittingBatch = true;
    });
    try {
      await ref
          .read(userPlaylistSongApiClientProvider)
          .addSongs(playlistId: playlistId, songs: selectedSongs);
      if (!mounted) {
        return;
      }
      _setBatchMode(false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppI18n.t(ref.read(appConfigProvider), 'detail.batch.add_success'),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submittingBatch = false;
      });
      AppMessageService.showError(
        NetworkErrorMessage.resolve(error) ?? '$error',
      );
    }
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.request,
    required this.state,
    required this.onLoadMore,
    required this.onPreviewCover,
    required this.onPlaySong,
    required this.onMoreSong,
    required this.onPlayAll,
    required this.batchMode,
    required this.selectedSongKeys,
    required this.selectedCount,
    required this.allSelected,
    required this.onEnterBatchMode,
    required this.onCancelBatch,
    required this.onSelectAllLoaded,
    required this.onToggleSongSelection,
    required this.onShowDescription,
  });

  final RankingDetailRequest request;
  final RankingDetailState state;
  final Future<void> Function() onLoadMore;
  final void Function(String title, String coverUrl) onPreviewCover;
  final void Function(RankingSong, String coverUrl, int index) onPlaySong;
  final void Function(RankingSong, String coverUrl) onMoreSong;
  final VoidCallback onPlayAll;
  final bool batchMode;
  final Set<String> selectedSongKeys;
  final int selectedCount;
  final bool allSelected;
  final VoidCallback onEnterBatchMode;
  final VoidCallback onCancelBatch;
  final VoidCallback onSelectAllLoaded;
  final void Function(RankingSong song) onToggleSongSelection;
  final ValueChanged<String> onShowDescription;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = state.detail;
    final currentTrack = ref.watch(
      playerControllerProvider.select((player) => player.currentTrack),
    );
    if (detail == null) {
      return const Center(child: Text('No detail content.'));
    }
    final coverUrl = detail.info.coverUrl;
    final subtitle = detail.totalCount > 0 ? '${detail.totalCount} 首' : '';

    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return <Widget>[
          MusicDetailSliverAppBar(
            title: detail.info.name,
            subtitle: subtitle,
            coverUrl: coverUrl,
            description: detail.description,
            onPreviewCover: () => onPreviewCover(detail.info.name, coverUrl),
            onBack: () => Navigator.of(context).maybePop(),
            onShowDescription: () => onShowDescription(detail.description),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: MusicDetailPlayAllHeader(
              countText: '全部播放 ${state.songs.length}',
              onPlayAll: onPlayAll,
              onBatchAction: state.songs.isEmpty ? null : onEnterBatchMode,
              batchMode: batchMode,
              selectedCount: selectedCount,
              allSelected: allSelected,
              onSelectAll: state.songs.isEmpty ? null : onSelectAllLoaded,
              onCancelBatch: batchMode ? onCancelBatch : null,
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
          itemCount: state.songs.length,
          itemBuilder: (context, index) {
            final song = state.songs[index];
            final config = ref.read(appConfigProvider);
            final platforms =
                ref.read(onlinePlatformsProvider).valueOrNull ??
                const <OnlinePlatform>[];
            final songCover = resolveSongCoverUrl(
              baseUrl: config.apiBaseUrl,
              token: config.authToken ?? '',
              platforms: platforms,
              platformId: song.platform,
              songId: song.id,
              cover: song.cover,
              size: 300,
            );
            return OnlineSongListItem(
              song: song,
              coverUrl: songCover.trim().isEmpty ? null : songCover,
              isCurrent: isCurrentSongTrack(currentTrack, song),
              selectable: batchMode,
              selected: selectedSongKeys.contains(
                buildSongBatchKey(songId: song.id, platform: song.platform),
              ),
              showActions: !batchMode,
              onTap: batchMode
                  ? null
                  : () => onPlaySong(song, songCover, index),
              onSelectTap: () => onToggleSongSelection(song),
              onLikeTap: batchMode ? null : () {},
              onMoreTap: batchMode ? null : () => onMoreSong(song, songCover),
            );
          },
          initialLoading: state.loading && state.songs.isEmpty,
          enablePaging: true,
          loadingMore: state.loadingMore,
          hasMore: state.hasMore,
          onLoadMore: onLoadMore,
          empty: Center(
            child: Text(
              '暂无歌曲列表',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).hintColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
