import 'package:flutter/material.dart';

import '../models/he_music_models.dart';
import 'song_list_item.dart';

class OnlineSongListItem extends StatelessWidget {
  const OnlineSongListItem({
    required this.song,
    this.coverUrl,
    this.isLiked = false,
    this.isCurrent = false,
    this.selectable = false,
    this.selected = false,
    this.showActions = true,
    this.artistAlbumText,
    this.subtitleText = '',
    this.tags,
    this.showMoreVersionButton = false,
    this.onTap,
    this.onSelectTap,
    this.onLikeTap,
    this.onMoreTap,
    this.onMoreVersionTap,
    super.key,
  });

  final SongInfo song;
  final String? coverUrl;
  final bool isLiked;
  final bool isCurrent;
  final bool selectable;
  final bool selected;
  final bool showActions;
  final String? artistAlbumText;
  final String subtitleText;
  final List<String>? tags;
  final bool showMoreVersionButton;
  final VoidCallback? onTap;
  final VoidCallback? onSelectTap;
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
      selectable: selectable,
      selected: selected,
      showActions: showActions,
      onTap: onTap,
      onSelectTap: onSelectTap,
      onLikeTap: onLikeTap,
      onMoreTap: onMoreTap,
      onMoreVersionTap: onMoreVersionTap,
    );
  }
}
