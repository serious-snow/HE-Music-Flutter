import 'player_play_mode.dart';

class PlayerHistoryItem {
  const PlayerHistoryItem({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.artworkUrl,
    required this.url,
    required this.playedAt,
    this.platform,
    this.isRadioMode = false,
    this.currentRadioId,
    this.currentRadioPlatform,
    this.currentRadioPageIndex,
    this.previousPlayModeBeforeRadio,
  });

  final String id;
  final String title;
  final String artist;
  final String album;
  final String artworkUrl;
  final String url;
  final int playedAt;
  final String? platform;
  final bool isRadioMode;
  final String? currentRadioId;
  final String? currentRadioPlatform;
  final int? currentRadioPageIndex;
  final PlayerPlayMode? previousPlayModeBeforeRadio;
}
