import 'dart:io';

import 'package:local_audio_scan/local_audio_scan.dart' as local_audio_scan;

class LocalMusicQueryTrack {
  const LocalMusicQueryTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.filePath,
    required this.mimeType,
    required this.size,
    this.artwork,
  });

  final String id;
  final String title;
  final String artist;
  final String album;
  final int duration;
  final String filePath;
  final String mimeType;
  final int size;
  final List<int>? artwork;
}

class LocalMusicQueryDataSource {
  final local_audio_scan.LocalAudioScanner _scanner =
      local_audio_scan.LocalAudioScanner();

  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      return _scanner.requestPermission();
    }
    if (Platform.isMacOS) {
      return true;
    }
    return false;
  }

  Future<List<LocalMusicQueryTrack>> scanSongs() async {
    if (Platform.isAndroid) {
      final tracks = await _scanner.scanTracks(
        includeArtwork: true,
        filterJunkAudio: true,
      );
      return tracks
          .map(
            (track) => LocalMusicQueryTrack(
              id: track.id,
              title: track.title,
              artist: track.artist,
              album: track.album,
              duration: track.duration,
              filePath: track.filePath,
              mimeType: track.mimeType,
              size: track.size,
              artwork: track.artwork,
            ),
          )
          .toList(growable: false);
    }
    if (Platform.isMacOS) {
      return _scanMacOsTracks();
    }
    return const <LocalMusicQueryTrack>[];
  }

  Future<List<LocalMusicQueryTrack>> _scanMacOsTracks() async {
    final home = Platform.environment['HOME']?.trim() ?? '';
    if (home.isEmpty) {
      return const <LocalMusicQueryTrack>[];
    }
    final musicDirectory = Directory('$home/Music');
    if (!await musicDirectory.exists()) {
      return const <LocalMusicQueryTrack>[];
    }

    final results = <LocalMusicQueryTrack>[];
    await for (final entity in musicDirectory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) {
        continue;
      }
      final path = entity.path;
      if (!_isSupportedAudioFile(path)) {
        continue;
      }
      final stat = await entity.stat();
      results.add(
        LocalMusicQueryTrack(
          id: path,
          title: '',
          artist: '',
          album: '',
          duration: 0,
          filePath: path,
          mimeType: _guessMimeType(path),
          size: stat.size,
        ),
      );
    }
    return results;
  }

  bool _isSupportedAudioFile(String path) {
    final normalized = path.trim().toLowerCase();
    return normalized.endsWith('.mp3') ||
        normalized.endsWith('.flac') ||
        normalized.endsWith('.m4a') ||
        normalized.endsWith('.aac') ||
        normalized.endsWith('.wav') ||
        normalized.endsWith('.ogg') ||
        normalized.endsWith('.opus') ||
        normalized.endsWith('.ape') ||
        normalized.endsWith('.aiff') ||
        normalized.endsWith('.aif');
  }

  String _guessMimeType(String path) {
    final normalized = path.trim().toLowerCase();
    if (normalized.endsWith('.mp3')) {
      return 'audio/mpeg';
    }
    if (normalized.endsWith('.flac')) {
      return 'audio/flac';
    }
    if (normalized.endsWith('.m4a')) {
      return 'audio/mp4';
    }
    if (normalized.endsWith('.aac')) {
      return 'audio/aac';
    }
    if (normalized.endsWith('.wav') ||
        normalized.endsWith('.aiff') ||
        normalized.endsWith('.aif')) {
      return 'audio/wav';
    }
    if (normalized.endsWith('.ogg') || normalized.endsWith('.opus')) {
      return 'audio/ogg';
    }
    if (normalized.endsWith('.ape')) {
      return 'audio/ape';
    }
    return '';
  }
}
