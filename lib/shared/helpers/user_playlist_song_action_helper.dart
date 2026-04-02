import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_message_service.dart';
import '../../app/config/app_config_controller.dart';
import '../../app/i18n/app_i18n.dart';
import '../../core/network/network_error_message.dart';
import '../../features/my/presentation/providers/user_playlist_song_providers.dart';
import '../models/he_music_models.dart';
import '../widgets/select_user_playlist_sheet.dart';

Future<void> addSingleSongToUserPlaylist({
  required BuildContext context,
  required WidgetRef ref,
  required IdPlatformInfo song,
}) async {
  final playlistId = await showSelectUserPlaylistSheet(context);
  if (playlistId == null || !context.mounted) {
    return;
  }
  try {
    await ref
        .read(userPlaylistSongApiClientProvider)
        .addSongs(playlistId: playlistId, songs: <IdPlatformInfo>[song]);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppI18n.t(ref.read(appConfigProvider), 'detail.batch.add_success'),
        ),
      ),
    );
  } catch (error) {
    AppMessageService.showError(NetworkErrorMessage.resolve(error) ?? '$error');
  }
}
