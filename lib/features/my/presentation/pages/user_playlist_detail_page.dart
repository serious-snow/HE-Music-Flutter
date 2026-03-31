import 'dart:async';

import 'package:flutter/foundation.dart';
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
import '../../../online/presentation/providers/online_providers.dart';
import '../../../player/domain/entities/player_queue_source.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../../../playlist/domain/entities/playlist_detail_content.dart';
import '../../../playlist/domain/entities/playlist_detail_song.dart';
import '../../../playlist/domain/entities/playlist_detail_state.dart';
import '../../domain/entities/user_playlist_detail_request.dart';
import '../providers/favorite_song_status_providers.dart';
import '../providers/my_overview_providers.dart';
import '../providers/my_playlist_shelf_providers.dart';
import '../providers/user_playlist_detail_providers.dart';

class UserPlaylistDetailPage extends ConsumerStatefulWidget {
  const UserPlaylistDetailPage({
    required this.id,
    required this.title,
    super.key,
  });

  final String id;
  final String title;

  @override
  ConsumerState<UserPlaylistDetailPage> createState() =>
      _UserPlaylistDetailPageState();
}

class _UserPlaylistDetailPageState
    extends ConsumerState<UserPlaylistDetailPage> {
  late final UserPlaylistDetailRequest _request;
  late final DetailSongActionHandler<PlaylistDetailSong> _songActions;

  @override
  void initState() {
    super.initState();
    _request = UserPlaylistDetailRequest(id: widget.id, title: widget.title);
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
        routePath: AppRoutes.userPlaylistDetail,
        queryParameters: <String, String>{
          'id': widget.id,
          'title': widget.title,
        },
        title: widget.title,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref
          .read(userPlaylistDetailControllerProvider.notifier)
          .initialize(_request);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(userPlaylistDetailControllerProvider);
    final controller = ref.read(userPlaylistDetailControllerProvider.notifier);
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
      child: Text(
        AppI18n.t(
          ref.read(appConfigProvider),
          'detail.no_user_playlist_content',
        ),
      ),
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

    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return <Widget>[
          MusicDetailSliverAppBar(
            title: title,
            subtitle: subtitle,
            coverUrl: coverUrl,
            description: description,
            metaItems: _buildMetaItems(context, content, songs.length),
            actions: <Widget>[
              IconButton(
                onPressed: () => _showPlaylistActions(context, content),
                icon: const Icon(Icons.more_horiz_rounded),
                tooltip: AppI18n.t(
                  ref.read(appConfigProvider),
                  'user_playlist.more',
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
    final effectiveSongCount = content.songCount.trim().isNotEmpty
        ? content.songCount.trim()
        : '$fallbackSongCount';
    if (effectiveSongCount.isNotEmpty) {
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
    final playCount = content.playCount.trim();
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

  Future<void> _showPlaylistActions(
    BuildContext context,
    PlaylistDetailContent content,
  ) async {
    final isDefaultPlaylist = content.isDefault;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(
                  AppI18n.t(ref.read(appConfigProvider), 'user_playlist.edit'),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(_openEditSheet(context, content));
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.delete_outline_rounded,
                  color: isDefaultPlaylist
                      ? Theme.of(context).disabledColor
                      : Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  AppI18n.t(
                    ref.read(appConfigProvider),
                    'user_playlist.delete',
                  ),
                  style: TextStyle(
                    color: isDefaultPlaylist
                        ? Theme.of(context).disabledColor
                        : Theme.of(context).colorScheme.error,
                  ),
                ),
                subtitle: isDefaultPlaylist
                    ? Text(
                        AppI18n.t(
                          ref.read(appConfigProvider),
                          'user_playlist.delete_disabled',
                        ),
                      )
                    : null,
                enabled: !isDefaultPlaylist,
                onTap: isDefaultPlaylist
                    ? null
                    : () {
                        Navigator.of(sheetContext).pop();
                        unawaited(_confirmDelete(context));
                      },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openEditSheet(
    BuildContext context,
    PlaylistDetailContent content,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await _showEditPlaylistForm(context, content);
    if (result == null) {
      return;
    }
    try {
      await ref
          .read(userPlaylistDetailControllerProvider.notifier)
          .updatePlaylist(
            request: _request,
            name: result.name,
            cover: result.cover,
            description: result.description,
          );
      ref.invalidate(myCreatedPlaylistsProvider);
      ref.invalidate(myOverviewControllerProvider);
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            AppI18n.t(ref.read(appConfigProvider), 'user_playlist.updated'),
          ),
        ),
      );
    } catch (error) {
      AppMessageService.showError(
        NetworkErrorMessage.resolve(error) ??
            AppI18n.t(
              ref.read(appConfigProvider),
              'user_playlist.update_failed',
            ),
      );
    }
  }

  Future<_EditPlaylistPayload?> _showEditPlaylistForm(
    BuildContext context,
    PlaylistDetailContent content,
  ) {
    final platform = defaultTargetPlatform;
    final useDialog =
        platform == TargetPlatform.macOS ||
        platform == TargetPlatform.windows ||
        platform == TargetPlatform.linux;
    if (useDialog) {
      return showDialog<_EditPlaylistPayload>(
        context: context,
        builder: (dialogContext) {
          return Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: _UserPlaylistEditSheet(
                initialName: content.title,
                initialCover: content.coverUrl,
                initialDescription: content.description,
                useBottomInsetPadding: false,
              ),
            ),
          );
        },
      );
    }
    return showModalBottomSheet<_EditPlaylistPayload>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return _UserPlaylistEditSheet(
          initialName: content.title,
          initialCover: content.coverUrl,
          initialDescription: content.description,
          useBottomInsetPadding: true,
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            AppI18n.t(
              ref.read(appConfigProvider),
              'user_playlist.delete_confirm_title',
            ),
          ),
          content: Text(
            AppI18n.t(
              ref.read(appConfigProvider),
              'user_playlist.delete_confirm_message',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                AppI18n.t(ref.read(appConfigProvider), 'common.cancel'),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                AppI18n.t(ref.read(appConfigProvider), 'user_playlist.delete'),
              ),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    try {
      await ref
          .read(userPlaylistDetailControllerProvider.notifier)
          .deletePlaylist(_request.id);
      ref.invalidate(myCreatedPlaylistsProvider);
      ref.invalidate(myOverviewControllerProvider);
      if (!mounted) {
        return;
      }
      navigator.maybePop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            AppI18n.t(ref.read(appConfigProvider), 'user_playlist.deleted'),
          ),
        ),
      );
    } catch (error) {
      AppMessageService.showError(
        NetworkErrorMessage.resolve(error) ??
            AppI18n.t(
              ref.read(appConfigProvider),
              'user_playlist.delete_failed',
            ),
      );
    }
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
      AppMessageService.showError(
        NetworkErrorMessage.resolve(error) ??
            AppI18n.t(
              ref.read(appConfigProvider),
              'user_playlist.favorite_failed',
            ),
      );
    }
  }
}

class _EditPlaylistPayload {
  const _EditPlaylistPayload({
    required this.name,
    required this.cover,
    required this.description,
  });

  final String name;
  final String cover;
  final String description;
}

class _UserPlaylistEditSheet extends StatefulWidget {
  const _UserPlaylistEditSheet({
    required this.initialName,
    required this.initialCover,
    required this.initialDescription,
    required this.useBottomInsetPadding,
  });

  final String initialName;
  final String initialCover;
  final String initialDescription;
  final bool useBottomInsetPadding;

  @override
  State<_UserPlaylistEditSheet> createState() => _UserPlaylistEditSheetState();
}

class _UserPlaylistEditSheetState extends State<_UserPlaylistEditSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _coverController;
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _coverController = TextEditingController(text: widget.initialCover);
    _descriptionController = TextEditingController(
      text: widget.initialDescription,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _coverController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = widget.useBottomInsetPadding
        ? MediaQuery.viewInsetsOf(context).bottom
        : 0.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              AppI18n.tByLocaleCode(
                Localizations.localeOf(context).languageCode,
                'user_playlist.edit',
              ),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: AppI18n.tByLocaleCode(
                  Localizations.localeOf(context).languageCode,
                  'user_playlist.field.name',
                ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _coverController,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: AppI18n.tByLocaleCode(
                  Localizations.localeOf(context).languageCode,
                  'user_playlist.field.cover',
                ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              minLines: 4,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: AppI18n.tByLocaleCode(
                  Localizations.localeOf(context).languageCode,
                  'user_playlist.field.description',
                ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                child: Text(
                  AppI18n.tByLocaleCode(
                    Localizations.localeOf(context).languageCode,
                    'user_playlist.save',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      return;
    }
    Navigator.of(context).pop(
      _EditPlaylistPayload(
        name: name,
        cover: _coverController.text.trim(),
        description: _descriptionController.text.trim(),
      ),
    );
  }
}
