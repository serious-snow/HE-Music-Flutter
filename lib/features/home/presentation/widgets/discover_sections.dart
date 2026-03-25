import 'package:flutter/material.dart';

import '../../../../app/config/app_config_state.dart';
import '../../../../shared/models/he_music_models.dart';
import '../../../../shared/utils/playlist_song_count_text.dart';
import '../../../../shared/widgets/animated_skeleton.dart';
import '../../../../shared/widgets/media_grid_card.dart';
import '../../../../shared/widgets/online_song_list_item.dart';
import '../../../../shared/widgets/plaza_loading_skeleton.dart';
import '../../../../shared/widgets/video_list_card.dart';
import '../../domain/entities/home_discover_item.dart';
import '../../domain/entities/home_discover_section.dart';
import '../../domain/entities/home_discover_state.dart';

class DiscoverSections extends StatelessWidget {
  const DiscoverSections({
    required this.loadingText,
    required this.emptyText,
    required this.retryText,
    required this.titleOf,
    required this.state,
    required this.onRetry,
    required this.onTapSong,
    required this.onTapAlbum,
    required this.onTapPlaylist,
    required this.onTapVideo,
    required this.onMoreSong,
    required this.isSongLiked,
    required this.onLikeSong,
    required this.isCurrentSong,
    required this.config,
    this.resolveSongCover,
    super.key,
  });

  final String loadingText;
  final String emptyText;
  final String retryText;
  final String Function(HomeDiscoverSection) titleOf;
  final HomeDiscoverState state;
  final VoidCallback onRetry;
  final void Function(List<SongInfo> songs, int index) onTapSong;
  final ValueChanged<AlbumInfo> onTapAlbum;
  final ValueChanged<PlaylistInfo> onTapPlaylist;
  final ValueChanged<MvInfo> onTapVideo;
  final ValueChanged<SongInfo> onMoreSong;
  final bool Function(SongInfo song) isSongLiked;
  final Future<void> Function(SongInfo song) onLikeSong;
  final bool Function(SongInfo song) isCurrentSong;
  final AppConfigState config;
  final String Function(SongInfo item)? resolveSongCover;

  @override
  Widget build(BuildContext context) {
    if (state.loading) {
      return const _DiscoverLoadingSkeleton();
    }
    if (state.errorMessage != null) {
      return _ErrorBlock(
        message: state.errorMessage!,
        retryText: retryText,
        onRetry: onRetry,
      );
    }
    if (state.sections.every((section) => section.isEmpty)) {
      return _EmptyBlock(label: emptyText);
    }
    return Column(
      children: state.sections
          .map((section) {
            return _SectionBlock(
              title: titleOf(section),
              section: section,
              onTapSong: onTapSong,
              onTapAlbum: onTapAlbum,
              onTapPlaylist: onTapPlaylist,
              onTapVideo: onTapVideo,
              onMoreSong: onMoreSong,
              isSongLiked: isSongLiked,
              onLikeSong: onLikeSong,
              isCurrentSong: isCurrentSong,
              config: config,
              resolveSongCover: resolveSongCover,
            );
          })
          .toList(growable: false),
    );
  }
}

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({
    required this.title,
    required this.section,
    required this.onTapSong,
    required this.onTapAlbum,
    required this.onTapPlaylist,
    required this.onTapVideo,
    required this.onMoreSong,
    required this.isSongLiked,
    required this.onLikeSong,
    required this.isCurrentSong,
    required this.config,
    this.resolveSongCover,
  });

  final String title;
  final HomeDiscoverSection section;
  final void Function(List<SongInfo> songs, int index) onTapSong;
  final ValueChanged<AlbumInfo> onTapAlbum;
  final ValueChanged<PlaylistInfo> onTapPlaylist;
  final ValueChanged<MvInfo> onTapVideo;
  final ValueChanged<SongInfo> onMoreSong;
  final bool Function(SongInfo song) isSongLiked;
  final Future<void> Function(SongInfo song) onLikeSong;
  final bool Function(SongInfo song) isCurrentSong;
  final AppConfigState config;
  final String Function(SongInfo item)? resolveSongCover;

  @override
  Widget build(BuildContext context) {
    if (section.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _buildSectionContent(context: context),
        ],
      ),
    );
  }

  Widget _buildSectionContent({required BuildContext context}) {
    return switch (section.type) {
      HomeDiscoverItemType.song => Column(
        children: section.songs
            .asMap()
            .entries
            .map((entry) => _buildSongItem(context, entry.key, entry.value))
            .toList(growable: false),
      ),
      HomeDiscoverItemType.album ||
      HomeDiscoverItemType.playlist => LayoutBuilder(
        builder: (context, constraints) {
          const spacing = 10.0;
          final itemWidth = (constraints.maxWidth - spacing) / 2;
          final albumItems = section.albums;
          final playlistItems = section.playlists;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children:
                (section.type == HomeDiscoverItemType.album
                        ? albumItems.map(
                            (item) => SizedBox(
                              width: itemWidth,
                              child: _DiscoverGridCard(
                                type: section.type,
                                title: item.name,
                                subtitle: item.artistText,
                                coverUrl: item.cover,
                                songCount: item.songCount,
                                playCount: item.playCount,
                                localeCode: config.localeCode,
                                onTap: () => onTapAlbum(item),
                              ),
                            ),
                          )
                        : playlistItems.map(
                            (item) => SizedBox(
                              width: itemWidth,
                              child: _DiscoverGridCard(
                                type: section.type,
                                title: item.name,
                                subtitle: item.creator,
                                coverUrl: item.cover,
                                songCount: item.songCount,
                                playCount: item.playCount,
                                localeCode: config.localeCode,
                                onTap: () => onTapPlaylist(item),
                              ),
                            ),
                          ))
                    .toList(growable: false),
          );
        },
      ),
      HomeDiscoverItemType.video => Column(
        children: section.videos
            .map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: VideoListCard(
                  title: item.name,
                  creator: item.creator,
                  duration: '${item.duration}',
                  coverUrl: item.cover,
                  playCount: item.playCount,
                  onTap: () => onTapVideo(item),
                ),
              ),
            )
            .toList(growable: false),
      ),
    };
  }

  Widget _buildSongItem(BuildContext context, int index, SongInfo item) {
    final resolvedCover = resolveSongCover?.call(item) ?? item.cover;
    return OnlineSongListItem(
      song: item,
      artistAlbumText: item.artistAlbumText,
      subtitleText: item.displaySubtitle,
      coverUrl: resolvedCover.isEmpty ? null : resolvedCover,
      isCurrent: isCurrentSong(item),
      isLiked: isSongLiked(item),
      onTap: () => onTapSong(section.songs, index),
      onLikeTap: () => onLikeSong(item),
      onMoreTap: () => onMoreSong(item),
    );
  }
}

class _DiscoverGridCard extends StatelessWidget {
  const _DiscoverGridCard({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.coverUrl,
    required this.localeCode,
    this.songCount,
    this.playCount,
    required this.onTap,
  });

  final HomeDiscoverItemType type;
  final String title;
  final String subtitle;
  final String coverUrl;
  final String localeCode;
  final String? songCount;
  final String? playCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isAlbum = type == HomeDiscoverItemType.album;
    final caption = !isAlbum
        ? buildPlaylistSongCountText(
            count: songCount ?? '',
            localeCode: localeCode,
          )
        : null;
    return MediaGridCard(
      kind: isAlbum ? MediaGridCardKind.album : MediaGridCardKind.playlist,
      title: title,
      subtitle: subtitle,
      caption: caption,
      coverUrl: coverUrl,
      playCount: playCount,
      onTap: onTap,
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
      child: Text(label),
    );
  }
}

class _DiscoverLoadingSkeleton extends StatelessWidget {
  const _DiscoverLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: <Widget>[
        _SongSectionSkeleton(),
        SizedBox(height: 18),
        _GridSectionSkeleton(),
        SizedBox(height: 18),
        _GridSectionSkeleton(),
        SizedBox(height: 18),
        _VideoSectionSkeleton(),
      ],
    );
  }
}

class _SectionTitleSkeleton extends StatelessWidget {
  const _SectionTitleSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SectionTitleSkeleton();
  }
}

class _SongSectionSkeleton extends StatelessWidget {
  const _SongSectionSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const <Widget>[
        _SectionTitleSkeleton(),
        _SongRowSkeleton(),
        _SongRowSkeleton(),
        _SongRowSkeleton(),
        _SongRowSkeleton(),
      ],
    );
  }
}

class _SongRowSkeleton extends StatelessWidget {
  const _SongRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: const <Widget>[
          SkeletonBox(width: 56, height: 56, radius: 16),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SkeletonBox(width: double.infinity, height: 14, radius: 7),
                SizedBox(height: 8),
                SkeletonBox(width: 168, height: 12, radius: 6),
              ],
            ),
          ),
          SizedBox(width: 12),
          SkeletonBox(width: 18, height: 18, radius: 9),
        ],
      ),
    );
  }
}

class _GridSectionSkeleton extends StatelessWidget {
  const _GridSectionSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _SectionTitleSkeleton(),
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 10.0;
            final itemWidth = (constraints.maxWidth - spacing) / 2;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: List<Widget>.generate(
                4,
                (_) => SizedBox(
                  width: itemWidth,
                  child: const GridCardSkeleton(),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _VideoSectionSkeleton extends StatelessWidget {
  const _VideoSectionSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const <Widget>[
        _SectionTitleSkeleton(),
        VideoCardSkeleton(),
        SizedBox(height: 10),
        VideoCardSkeleton(),
      ],
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({
    required this.message,
    required this.retryText,
    required this.onRetry,
  });

  final String message;
  final String retryText;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(message)),
          const SizedBox(width: 12),
          OutlinedButton(onPressed: onRetry, child: Text(retryText)),
        ],
      ),
    );
  }
}
