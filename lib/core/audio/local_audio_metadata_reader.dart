import 'dart:io';
import 'dart:typed_data';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';

class LocalAudioMetadata {
  const LocalAudioMetadata({
    this.title,
    this.artist,
    this.album,
    this.duration,
    this.artworkBytes,
    this.embeddedLyrics,
    this.bitrate,
    this.sampleRate,
  });

  final String? title;
  final String? artist;
  final String? album;
  final Duration? duration;
  final Uint8List? artworkBytes;
  final String? embeddedLyrics;
  final int? bitrate;
  final int? sampleRate;
}

class LocalAudioMetadataReader {
  Future<LocalAudioMetadata?> read(
    String filePath, {
    bool fetchArtwork = false,
  }) async {
    final normalizedPath = filePath.trim();
    if (normalizedPath.isEmpty) {
      return null;
    }

    final file = File(normalizedPath);
    if (!await file.exists()) {
      return null;
    }

    try {
      final metadata = await Future<LocalAudioMetadata>.sync(() {
        final parsed = readMetadata(file, getImage: fetchArtwork);
        return LocalAudioMetadata(
          title: _normalizeText(parsed.title),
          artist: _normalizeText(parsed.artist),
          album: _normalizeText(parsed.album),
          duration: parsed.duration,
          artworkBytes: _pickArtwork(parsed.pictures),
          embeddedLyrics: _normalizeText(parsed.lyrics),
          bitrate: parsed.bitrate,
          sampleRate: parsed.sampleRate,
        );
      });

      if (_isEmpty(metadata)) {
        return null;
      }
      return metadata;
    } catch (_) {
      return null;
    }
  }

  bool _isEmpty(LocalAudioMetadata metadata) {
    return metadata.title == null &&
        metadata.artist == null &&
        metadata.album == null &&
        metadata.duration == null &&
        metadata.artworkBytes == null &&
        metadata.embeddedLyrics == null &&
        metadata.bitrate == null &&
        metadata.sampleRate == null;
  }

  String? _normalizeText(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty || normalized == '<unknown>') {
      return null;
    }
    return normalized;
  }

  Uint8List? _pickArtwork(List<Picture> pictures) {
    if (pictures.isEmpty) {
      return null;
    }
    for (final picture in pictures) {
      if (picture.pictureType == PictureType.coverFront &&
          picture.bytes.isNotEmpty) {
        return picture.bytes;
      }
    }
    for (final picture in pictures) {
      if (picture.bytes.isNotEmpty) {
        return picture.bytes;
      }
    }
    return null;
  }
}
