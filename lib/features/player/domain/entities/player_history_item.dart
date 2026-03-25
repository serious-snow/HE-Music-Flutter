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
  });

  final String id;
  final String title;
  final String artist;
  final String album;
  final String artworkUrl;
  final String url;
  final int playedAt;
  final String? platform;
}
