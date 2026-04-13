import 'package:flutter/material.dart';

import '../../app/i18n/app_i18n.dart';
import 'adaptive_action_menu.dart';

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
          child: Builder(
            builder: (buttonContext) => FilledButton.icon(
              onPressed: enabled && !loading
                  ? () => _showActionsSheet(buttonContext, localeCode)
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
      ),
    );
  }

  Future<void> _showActionsSheet(BuildContext context, String localeCode) {
    return showAdaptiveActionMenu<VoidCallback>(
      context: context,
      anchorContext: context,
      items: <AdaptiveActionMenuItem<VoidCallback>>[
        AdaptiveActionMenuItem<VoidCallback>(
          value: onPlayPressed ?? () {},
          label: AppI18n.tByLocaleCode(localeCode, 'song.action.play'),
          icon: Icons.play_arrow_rounded,
          enabled: onPlayPressed != null,
        ),
        AdaptiveActionMenuItem<VoidCallback>(
          value: onAddToQueuePressed ?? () {},
          label: AppI18n.tByLocaleCode(localeCode, 'song.action.add_to_queue'),
          icon: Icons.queue_music_rounded,
          enabled: onAddToQueuePressed != null,
        ),
        AdaptiveActionMenuItem<VoidCallback>(
          value: onAddToPlaylistPressed ?? () {},
          label: AppI18n.tByLocaleCode(
            localeCode,
            'detail.batch.add_to_playlist',
          ),
          icon: Icons.playlist_add_rounded,
          enabled: onAddToPlaylistPressed != null,
        ),
      ],
    ).then((callback) {
      callback?.call();
    });
  }
}
