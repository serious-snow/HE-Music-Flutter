import 'dart:typed_data';

import '../../../../core/audio/local_audio_metadata_reader.dart';
import '../../domain/entities/local_song.dart';
import '../../domain/repositories/local_music_repository.dart';
import '../datasources/local_music_query_data_source.dart';

const _unknownArtist = '未知歌手';
const _unknownAlbum = '未知专辑';
const _minimumTrackDurationMilliseconds = 60 * 1000;
const _callRecordingKeywords = <String>[
  'callrecord',
  'call_record',
  'call-record',
  'call recorder',
  'call_rec',
  'call rec',
  'recordings/call',
  'recording/call',
  'phone call',
  '通话录音',
  '电话录音',
  '录音/通话',
  '录音/电话',
  '/recordings/',
  '/recorder/',
  '/sound_recorder/',
  '/miui/sound_recorder/',
];

class LocalMusicRepositoryImpl implements LocalMusicRepository {
  LocalMusicRepositoryImpl(this._dataSource, this._metadataReader);

  final LocalMusicQueryDataSource _dataSource;
  final LocalAudioMetadataReader _metadataReader;

  @override
  Future<bool> requestPermission() {
    return _dataSource.requestPermission();
  }

  @override
  Future<List<LocalSong>> scanSongs() async {
    final tracks = await _dataSource.scanSongs();
    final filteredTracks = tracks
        .where(_shouldKeepTrack)
        .toList(growable: false);
    return Future.wait(filteredTracks.map(_toLocalSong), eagerError: false);
  }

  bool _shouldKeepTrack(LocalMusicQueryTrack track) {
    if (track.duration <= _minimumTrackDurationMilliseconds) {
      return false;
    }
    final path = track.filePath.trim().toLowerCase();
    final fileName = Uri.file(track.filePath).pathSegments.last.toLowerCase();
    for (final keyword in _callRecordingKeywords) {
      if (path.contains(keyword) || fileName.contains(keyword)) {
        return false;
      }
    }
    return true;
  }

  Future<LocalSong> _toLocalSong(LocalMusicQueryTrack track) async {
    final metadata = await _metadataReader.read(
      track.filePath,
      fetchArtwork: true,
    );
    final fileName = Uri.file(track.filePath).pathSegments.last;
    final rawName = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
    final parsed = _parseFileName(rawName);
    final title = _pickText(
      primary: metadata?.title ?? track.title,
      fallback: parsed.title,
    );
    final artist = _pickText(
      primary: metadata?.artist ?? track.artist,
      fallback: parsed.artist,
    );
    final album = _pickText(
      primary: metadata?.album ?? track.album,
      fallback: parsed.album,
    );
    return LocalSong(
      id: track.id,
      title: title,
      filePath: track.filePath,
      artist: artist,
      album: album,
      duration: Duration(
        milliseconds: _pickDurationMilliseconds(
          metadata?.duration?.inMilliseconds ?? track.duration,
        ),
      ),
      mimeType: track.mimeType,
      size: track.size,
      artworkBytes: _pickArtworkBytes(track, metadata),
      embeddedLyrics: metadata?.embeddedLyrics,
    );
  }

  String _pickText({required String? primary, required String fallback}) {
    return _normalizeLocalValue(primary) ?? fallback;
  }

  int _pickDurationMilliseconds(int milliseconds) {
    return milliseconds > 0 ? milliseconds : 0;
  }

  String? _normalizeLocalValue(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty || normalized == '<unknown>') {
      return null;
    }
    return normalized;
  }

  Uint8List? _pickArtworkBytes(
    LocalMusicQueryTrack track,
    LocalAudioMetadata? metadata,
  ) {
    final metadataArtwork = metadata?.artworkBytes;
    if (metadataArtwork != null && metadataArtwork.isNotEmpty) {
      return metadataArtwork;
    }
    final artwork = track.artwork;
    if (artwork != null && artwork.isNotEmpty) {
      return Uint8List.fromList(artwork);
    }
    return null;
  }

  _ParsedLocalSongMeta _parseFileName(String rawName) {
    final normalized = rawName
        .replaceAll('_', ' ')
        .replaceAll(' - ', ' - ')
        .trim();
    final segments = normalized
        .split(' - ')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (segments.length >= 3) {
      return _ParsedLocalSongMeta(
        artist: segments.first,
        album: segments[1],
        title: segments.sublist(2).join(' - '),
      );
    }
    if (segments.length == 2) {
      return _ParsedLocalSongMeta(
        artist: segments.first,
        album: _unknownAlbum,
        title: segments.last,
      );
    }
    return _ParsedLocalSongMeta(
      artist: _unknownArtist,
      album: _unknownAlbum,
      title: normalized,
    );
  }
}

class _ParsedLocalSongMeta {
  const _ParsedLocalSongMeta({
    required this.title,
    required this.artist,
    required this.album,
  });

  final String title;
  final String artist;
  final String album;
}
