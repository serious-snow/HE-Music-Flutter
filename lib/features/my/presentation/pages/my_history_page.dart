import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_message_service.dart';
import '../../../../app/config/app_config_controller.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/network/network_error_message.dart';
import '../../../../shared/utils/favorite_song_key.dart';
import '../../../player/domain/entities/player_history_item.dart';
import '../../../player/domain/entities/player_track.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../../../player/presentation/widgets/mini_player_bar.dart';
import '../../../online/presentation/providers/online_providers.dart';
import '../../../../shared/widgets/song_list_component.dart';
import '../../../../shared/widgets/song_list_item.dart';
import '../providers/favorite_song_status_providers.dart';
import '../providers/my_history_providers.dart';

class MyHistoryPage extends ConsumerWidget {
  const MyHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final state = ref.watch(myHistoryControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(AppI18n.t(config, 'my.history')),
        actions: <Widget>[
          IconButton(
            onPressed: () =>
                ref.read(myHistoryControllerProvider.notifier).clear(),
            tooltip: AppI18n.t(config, 'my.history.clear'),
            icon: const Icon(Icons.delete_sweep_rounded),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: state.when(
              data: (items) => _HistoryList(
                items: items,
                emptyText: AppI18n.t(config, 'my.history.empty'),
                onTap: (index) => _playHistory(context, ref, items, index),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => _HistoryErrorView(
                message: '$error',
                retryLabel: AppI18n.t(config, 'my.retry'),
                onRetry: () =>
                    ref.read(myHistoryControllerProvider.notifier).refresh(),
              ),
            ),
          ),
          MiniPlayerBar(onOpenFullPlayer: () => context.push(AppRoutes.player)),
        ],
      ),
    );
  }

  Future<void> _playHistory(
    BuildContext context,
    WidgetRef ref,
    List<PlayerHistoryItem> items,
    int startIndex,
  ) async {
    if (startIndex < 0 || startIndex >= items.length) {
      return;
    }
    final track = _toTrack(items[startIndex]);
    await ref
        .read(playerControllerProvider.notifier)
        .insertNextAndPlay(track);
  }

  PlayerTrack _toTrack(PlayerHistoryItem item) {
    final platform = item.platform?.trim() ?? '';
    return PlayerTrack(
      id: item.id,
      title: item.title.isEmpty ? item.id : item.title,
      artist: item.artist,
      album: item.album.isEmpty ? null : item.album,
      url: platform == 'local' ? item.url : '',
      artworkUrl: item.artworkUrl.isEmpty ? null : item.artworkUrl,
      platform: platform.isEmpty ? null : platform,
    );
  }
}

class _HistoryList extends ConsumerWidget {
  const _HistoryList({
    required this.items,
    required this.emptyText,
    required this.onTap,
  });

  final List<PlayerHistoryItem> items;
  final String emptyText;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return Center(child: Text(emptyText));
    }
    return SongListComponent(
      itemCount: items.length,
      enablePaging: false,
      itemBuilder: (context, index) {
        final item = items[index];
        final songId = item.id.trim();
        final platform = item.platform?.trim() ?? '';
        final canToggleFavorite = songId.isNotEmpty && platform.isNotEmpty;
        final isLiked = canToggleFavorite
            ? ref.watch(
                favoriteSongStatusProvider.select(
                  (state) => state.songKeys.contains(
                    buildFavoriteSongKey(songId: songId, platform: platform),
                  ),
                ),
              )
            : false;
        return SongListItem(
          data: SongListItemData(
            title: item.title.isEmpty ? item.id : item.title,
            artistAlbumText: item.artist.isEmpty ? '-' : item.artist,
            subtitleText: _playedText(item.playedAt),
            coverUrl: _cover(item.artworkUrl),
            tags: const <String>['历史'],
          ),
          isLiked: isLiked,
          onTap: () => onTap(index),
          onLikeTap: canToggleFavorite
              ? () => _toggleSongLike(
                  ref: ref,
                  songId: songId,
                  platform: platform,
                  liked: isLiked,
                )
              : null,
          onMoreTap: () => _showTodo(context, item.url),
        );
      },
    );
  }

  String? _cover(String value) {
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    return null;
  }

  String _playedText(int playedAt) {
    final safe = playedAt > 10000000000 ? playedAt : playedAt * 1000;
    final time = DateTime.fromMillisecondsSinceEpoch(safe);
    return '最近播放：${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  void _showTodo(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggleSongLike({
    required WidgetRef ref,
    required String songId,
    required String platform,
    required bool liked,
  }) async {
    try {
      await ref
          .read(onlineControllerProvider.notifier)
          .toggleSongFavorite(songId: songId, platform: platform, like: !liked);
    } catch (error) {
      AppMessageService.showError(
        NetworkErrorMessage.resolve(error) ?? '收藏操作失败，请稍后重试',
      );
    }
  }
}

class _HistoryErrorView extends StatelessWidget {
  const _HistoryErrorView({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: Text(retryLabel)),
          ],
        ),
      ),
    );
  }
}
