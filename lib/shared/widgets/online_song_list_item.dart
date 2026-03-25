import 'package:flutter/material.dart';

import '../models/he_music_models.dart';
import 'song_list_item.dart';

class OnlineSongListItem extends StatelessWidget {
  const OnlineSongListItem({
    required this.song,
    this.coverUrl,
    this.isLiked = false,
    this.isCurrent = false,
    this.artistAlbumText,
    this.subtitleText = '',
    this.tags,
    this.showMoreVersionButton = false,
    this.onTap,
    this.onLikeTap,
    this.onMoreTap,
    this.onMoreVersionTap,
    super.key,
  });

  final SongInfo song;
  final String? coverUrl;
  final bool isLiked;
  final bool isCurrent;
  final String? artistAlbumText;
  final String subtitleText;
  final List<String>? tags;
  final bool showMoreVersionButton;
  final VoidCallback? onTap;
  final VoidCallback? onLikeTap;
  final VoidCallback? onMoreTap;
  final VoidCallback? onMoreVersionTap;

  @override
  Widget build(BuildContext context) {
    return SongListItem(
      data: SongListItemData.fromSongInfo(
        song: song,
        artistAlbumText: artistAlbumText,
        subtitleText: subtitleText,
        coverUrl: coverUrl,
        tags: tags,
        isCurrent: isCurrent,
        showMoreVersionButton: showMoreVersionButton,
      ),
      isLiked: isLiked,
      onTap: onTap,
      onLikeTap: onLikeTap,
      onMoreTap: onMoreTap,
      onMoreVersionTap: onMoreVersionTap,
    );
  }
}
