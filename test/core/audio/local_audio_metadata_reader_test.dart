import 'dart:typed_data';

import 'package:audiotags/audiotags.dart' as at;
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/core/audio/local_audio_metadata_reader.dart';

void main() {
  test('reader maps audiotags tag into local audio metadata', () async {
    final reader = LocalAudioMetadataReader(
      readTag: (_) async => at.Tag(
        title: '夜曲',
        artists: const <String>['周杰伦'],
        album: '十一月的萧邦',
        albumArtists: const <String>[],
        lyrics: '[00:01.00]一群嗜血的蚂蚁',
        duration: 245000,
        bitrate: 320,
        sampleRate: 44100,
        bpm: 120,
        pictures: <at.Picture>[
          at.Picture(
            pictureType: at.PictureType.coverFront,
            mimeType: at.MimeType.png,
            bytes: Uint8List.fromList(<int>[1, 2, 3]),
          ),
        ],
      ),
      fileExists: (_) async => true,
    );

    final metadata = await reader.read('/tmp/night.mp3', fetchArtwork: true);

    expect(metadata, isNotNull);
    expect(metadata!.title, '夜曲');
    expect(metadata.artist, '周杰伦');
    expect(metadata.album, '十一月的萧邦');
    expect(metadata.embeddedLyrics, '[00:01.00]一群嗜血的蚂蚁');
    expect(metadata.duration, const Duration(milliseconds: 245000));
    expect(metadata.bitrate, 320);
    expect(metadata.sampleRate, 44100);
    expect(metadata.artworkBytes, Uint8List.fromList(<int>[1, 2, 3]));
  });

  test('reader normalizes v2.4 multi artist separator for display', () async {
    final reader = LocalAudioMetadataReader(
      readTag: (_) async => at.Tag(
        title: '夜曲',
        artists: const <String>['周杰伦', '五月天', '林俊杰'],
        album: '十一月的萧邦',
        albumArtists: const <String>[],
        pictures: const <at.Picture>[],
      ),
      fileExists: (_) async => true,
    );

    final metadata = await reader.read('/tmp/night.mp3');

    expect(metadata, isNotNull);
    expect(metadata!.artist, '周杰伦 / 五月天 / 林俊杰');
  });
}
