import 'dart:typed_data';

class LocalSong {
  const LocalSong({
    required this.id,
    required this.title,
    required this.filePath,
    required this.artist,
    required this.album,
    required this.duration,
    required this.mimeType,
    required this.size,
    this.artworkBytes,
    this.embeddedLyrics,
  });

  final String id;
  final String title;
  final String filePath;
  final String artist;
  final String album;
  final Duration duration;
  final String mimeType;
  final int size;
  final Uint8List? artworkBytes;
  final String? embeddedLyrics;

  String get formatLabel {
    final path = filePath.trim().toLowerCase();
    if (path.contains('.flac')) {
      return 'FLAC';
    }
    if (path.contains('.wav')) {
      return 'WAV';
    }
    if (path.contains('.ape')) {
      return 'APE';
    }
    if (path.contains('.aac')) {
      return 'AAC';
    }
    if (path.contains('.ogg')) {
      return 'OGG';
    }
    if (path.contains('.m4a')) {
      return 'M4A';
    }
    if (path.contains('.mp3')) {
      return 'MP3';
    }
    final normalizedMime = mimeType.trim().toLowerCase();
    if (normalizedMime.contains('flac')) {
      return 'FLAC';
    }
    if (normalizedMime.contains('wav')) {
      return 'WAV';
    }
    if (normalizedMime.contains('ape')) {
      return 'APE';
    }
    if (normalizedMime.contains('aac')) {
      return 'AAC';
    }
    if (normalizedMime.contains('ogg')) {
      return 'OGG';
    }
    if (normalizedMime.contains('m4a') || normalizedMime.contains('mp4')) {
      return 'M4A';
    }
    if (normalizedMime.contains('mpeg') || normalizedMime.contains('mp3')) {
      return 'MP3';
    }
    return '';
  }
}
