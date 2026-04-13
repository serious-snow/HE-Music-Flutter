import 'package:flutter/material.dart';

import '../../app/i18n/app_i18n.dart';
import 'adaptive_action_menu.dart';

Future<void> showSongActionsSheet({
  required BuildContext context,
  BuildContext? anchorContext,
  Offset? anchorPosition,
  required String? coverUrl,
  required String title,
  required String subtitle,
  required bool hasMv,
  required String sourceLabel,
  required VoidCallback onPlay,
  required VoidCallback onPlayNext,
  required VoidCallback onAddToPlaylist,
  VoidCallback? onDownload,
  VoidCallback? onAddToUserPlaylist,
  required VoidCallback onWatchMv,
  VoidCallback? onViewComment,
  String? albumActionLabel,
  VoidCallback? onViewAlbum,
  String? artistActionLabel,
  VoidCallback? onViewArtists,
  required VoidCallback onCopySongName,
  VoidCallback? onCopySongShareLink,
  VoidCallback? onSearchSameName,
  required VoidCallback onCopySongId,
}) {
  final localeCode = Localizations.localeOf(context).languageCode;
  final actions = <AdaptiveActionMenuItem<VoidCallback>>[
    AdaptiveActionMenuItem<VoidCallback>(
      value: onPlay,
      label: AppI18n.tByLocaleCode(localeCode, 'song.action.play'),
      icon: Icons.play_arrow_rounded,
    ),
    AdaptiveActionMenuItem<VoidCallback>(
      value: onPlayNext,
      label: AppI18n.tByLocaleCode(localeCode, 'song.action.play_next'),
      icon: Icons.skip_next_rounded,
    ),
    AdaptiveActionMenuItem<VoidCallback>(
      value: onAddToPlaylist,
      label: AppI18n.tByLocaleCode(localeCode, 'song.action.add_to_queue'),
      icon: Icons.playlist_add_rounded,
    ),
    if (onDownload != null)
      AdaptiveActionMenuItem<VoidCallback>(
        value: onDownload,
        label: AppI18n.tByLocaleCode(localeCode, 'player.action.download'),
        icon: Icons.download_rounded,
      ),
    if (onAddToUserPlaylist != null)
      AdaptiveActionMenuItem<VoidCallback>(
        value: onAddToUserPlaylist,
        label: AppI18n.tByLocaleCode(
          localeCode,
          'detail.batch.add_to_playlist',
        ),
        icon: Icons.library_add_rounded,
      ),
    AdaptiveActionMenuItem<VoidCallback>(
      value: onWatchMv,
      label: AppI18n.tByLocaleCode(localeCode, 'player.action.watch_mv'),
      icon: Icons.ondemand_video_rounded,
      enabled: hasMv,
    ),
    if (onViewComment != null)
      AdaptiveActionMenuItem<VoidCallback>(
        value: onViewComment,
        label: AppI18n.tByLocaleCode(localeCode, 'player.action.comments'),
        icon: Icons.forum_rounded,
      ),
    if (albumActionLabel != null && onViewAlbum != null)
      AdaptiveActionMenuItem<VoidCallback>(
        value: onViewAlbum,
        label: albumActionLabel,
        icon: Icons.album_outlined,
      ),
    if (artistActionLabel != null && onViewArtists != null)
      AdaptiveActionMenuItem<VoidCallback>(
        value: onViewArtists,
        label: artistActionLabel,
        icon: Icons.person_outline_rounded,
      ),
    AdaptiveActionMenuItem<VoidCallback>(
      value: onCopySongName,
      label: AppI18n.tByLocaleCode(localeCode, 'song.action.copy_name'),
      icon: Icons.drive_file_rename_outline_rounded,
      startsNewSection: true,
    ),
    AdaptiveActionMenuItem<VoidCallback>(
      value: onCopySongId,
      label: AppI18n.tByLocaleCode(localeCode, 'song.action.copy_id'),
      icon: Icons.copy_rounded,
    ),
    if (onCopySongShareLink != null)
      AdaptiveActionMenuItem<VoidCallback>(
        value: onCopySongShareLink,
        label: AppI18n.tByLocaleCode(localeCode, 'player.action.copy_share'),
        icon: Icons.share_rounded,
      ),
    if (onSearchSameName != null)
      AdaptiveActionMenuItem<VoidCallback>(
        value: onSearchSameName,
        label: AppI18n.tByLocaleCode(localeCode, 'player.action.search_same'),
        icon: Icons.search_rounded,
      ),
  ];
  return showAdaptiveActionMenu<VoidCallback>(
    context: context,
    items: actions,
    anchorContext: anchorContext,
    anchorPosition: anchorPosition,
    mobileHeader: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.60,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _SongHeader(coverUrl: coverUrl, title: title, subtitle: subtitle),
          const Divider(height: 1),
        ],
      ),
    ),
    mobileFooter: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _SourceInfoRow(label: sourceLabel),
        const SizedBox(height: 8),
      ],
    ),
  ).then((callback) {
    callback?.call();
  });
}

class _SourceInfoRow extends StatelessWidget {
  const _SourceInfoRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      enabled: false,
      minTileHeight: 40,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Icon(
        Icons.info_outline_rounded,
        size: 20,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(
        label,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SongHeader extends StatelessWidget {
  const _SongHeader({
    required this.coverUrl,
    required this.title,
    required this.subtitle,
  });

  final String? coverUrl;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Row(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: coverUrl == null || coverUrl!.trim().isEmpty
                ? Container(
                    width: 48,
                    height: 48,
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.music_note_rounded),
                  )
                : Image.network(
                    coverUrl!,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 48,
                      height: 48,
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.music_note_rounded),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).hintColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
