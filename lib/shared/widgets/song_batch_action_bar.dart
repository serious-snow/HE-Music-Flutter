import 'package:flutter/material.dart';

import '../../app/i18n/app_i18n.dart';

class SongBatchActionBar extends StatelessWidget {
  const SongBatchActionBar({
    required this.enabled,
    this.loading = false,
    this.onPlayPressed,
    this.onAddToQueuePressed,
    this.onAddToPlaylistPressed,
    super.key,
  });

  final bool enabled;
  final bool loading;
  final VoidCallback? onPlayPressed;
  final VoidCallback? onAddToQueuePressed;
  final VoidCallback? onAddToPlaylistPressed;

  @override
  Widget build(BuildContext context) {
    final localeCode = Localizations.localeOf(context).languageCode;
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      elevation: 6,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: FilledButton.icon(
            onPressed: enabled && !loading
                ? () => _showActionsSheet(context, localeCode)
                : null,
            icon: loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.more_horiz_rounded),
            label: Text(
              AppI18n.tByLocaleCode(localeCode, 'detail.batch.action'),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showActionsSheet(BuildContext context, String localeCode) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.play_arrow_rounded),
                title: Text(
                  AppI18n.tByLocaleCode(localeCode, 'song.action.play'),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onPlayPressed?.call();
                },
              ),
              ListTile(
                leading: const Icon(Icons.queue_music_rounded),
                title: Text(
                  AppI18n.tByLocaleCode(localeCode, 'song.action.add_to_queue'),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onAddToQueuePressed?.call();
                },
              ),
              ListTile(
                leading: const Icon(Icons.playlist_add_rounded),
                title: Text(
                  AppI18n.tByLocaleCode(
                    localeCode,
                    'detail.batch.add_to_playlist',
                  ),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onAddToPlaylistPressed?.call();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
