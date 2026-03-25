import '../../../../shared/models/he_music_models.dart';
import '../../domain/entities/online_platform.dart';

enum SearchType { song, playlist, album, artist }

extension SearchTypeApi on SearchType {
  String get apiType {
    return switch (this) {
      SearchType.song => 'song',
      SearchType.playlist => 'playlist',
      SearchType.album => 'album',
      SearchType.artist => 'artist',
    };
  }
}

extension SearchTypePlatformFeature on SearchType {
  BigInt get requiredPlatformFeatureFlag {
    return switch (this) {
      SearchType.song => PlatformFeatureSupportFlag.searchSong,
      SearchType.playlist => PlatformFeatureSupportFlag.searchPlaylist,
      SearchType.album => PlatformFeatureSupportFlag.searchAlbum,
      SearchType.artist => PlatformFeatureSupportFlag.searchSinger,
    };
  }
}

String displayTitle(SearchType type, Map<String, dynamic> item) {
  if (type == SearchType.song) {
    return searchSongInfo(item).name;
  }
  return switch (type) {
    SearchType.playlist => searchPlaylistInfo(item).name,
    SearchType.album => searchAlbumInfo(item).name,
    SearchType.artist => searchArtistInfo(item).name,
    SearchType.song => searchSongInfo(item).name,
  };
}

String displaySubtitle(SearchType type, Map<String, dynamic> item) {
  return switch (type) {
    SearchType.song => songSubtitle(item),
    SearchType.playlist =>
      searchPlaylistInfo(item).creator.isEmpty
          ? '-'
          : searchPlaylistInfo(item).creator,
    SearchType.album => _artistNames(searchAlbumInfo(item).artists),
    SearchType.artist => _artistSearchSubtitle(searchArtistInfo(item)),
  };
}

String artistSongCount(Map<String, dynamic> item) {
  return _countText(searchArtistInfo(item).songCount);
}

String artistAlbumCount(Map<String, dynamic> item) {
  return _countText(searchArtistInfo(item).albumCount);
}

String artistVideoCount(Map<String, dynamic> item) {
  return _countText(searchArtistInfo(item).mvCount);
}

String songTitle(Map<String, dynamic> item) {
  return _safeText(searchSongInfo(item).name);
}

String songSubtitle(Map<String, dynamic> item) {
  return _safeText(searchSongInfo(item).artist);
}

String songAlias(Map<String, dynamic> item) {
  return _safeText(searchSongInfo(item).subtitle);
}

String songAlbum(Map<String, dynamic> item) {
  return _safeText(searchSongInfo(item).album?.name);
}

String songAlbumId(Map<String, dynamic> item) {
  return _safeText(searchSongInfo(item).album?.id);
}

String songPrimaryArtistId(Map<String, dynamic> item) {
  final artists = searchSongInfo(item).artists;
  if (artists.isEmpty) {
    return '-';
  }
  return _safeText(artists.first.id);
}

String songDurationText(Map<String, dynamic> item) {
  final seconds = searchSongInfo(item).duration;
  if (seconds <= 0) {
    return '--:--';
  }
  final minute = seconds ~/ 60;
  final second = seconds % 60;
  final minuteText = minute.toString().padLeft(2, '0');
  final secondText = second.toString().padLeft(2, '0');
  return '$minuteText:$secondText';
}

String songArtistAlbumText(Map<String, dynamic> item) {
  final artist = songSubtitle(item);
  final album = songAlbum(item);
  if (artist == '-' && album == '-') {
    return '-';
  }
  if (artist == '-') {
    return album;
  }
  if (album == '-') {
    return artist;
  }
  return '$artist - $album';
}

bool songHasMoreVersion(Map<String, dynamic> item) {
  return searchSongInfo(item).sublist.isNotEmpty;
}

String songMvId(Map<String, dynamic> item) {
  return _safeText(searchSongInfo(item).mvId);
}

List<Map<String, dynamic>> songSublist(Map<String, dynamic> item) {
  final value = item['sublist'];
  if (value is! List || value.isEmpty) {
    return const <Map<String, dynamic>>[];
  }
  return value
      .map((entry) => mergeSongWithParent(item, _asMap(entry)))
      .toList(growable: false);
}

Map<String, dynamic> mergeSongWithParent(
  Map<String, dynamic> parent,
  Map<String, dynamic> song,
) {
  final merged = <String, dynamic>{...parent, ...song};
  merged['platform'] = _pick(merged['platform'], parent['platform']);
  merged['cover'] = _pick(merged['cover'], parent['cover']);
  merged['subtitle'] = _pick(merged['subtitle'], parent['subtitle']);
  merged['artists'] = _pick(merged['artists'], parent['artists']);
  merged['album'] = _pick(merged['album'], parent['album']);
  return merged;
}

dynamic _pick(dynamic value, dynamic fallback) {
  final parsed = text(value);
  if (parsed == '-') {
    return fallback;
  }
  return value;
}

bool songIsOriginal(Map<String, dynamic> item) {
  return searchSongInfo(item).originalType == 1;
}

bool songHasMv(Map<String, dynamic> item) {
  final mvId = _safeText(searchSongInfo(item).mvId);
  return mvId != '-' && mvId != '0';
}

String artistText(dynamic value) {
  return _safeText(_artistNames(_artistsFromDynamic(value)));
}

SongInfo searchSongInfo(Map<String, dynamic> item) {
  return SongInfo.fromMap(
    item,
    fallbackPlatform: _safePlatform(item['platform']),
  );
}

PlaylistInfo searchPlaylistInfo(Map<String, dynamic> item) {
  return PlaylistInfo.fromMap(
    item,
    fallbackPlatform: _safePlatform(item['platform']),
  );
}

AlbumInfo searchAlbumInfo(Map<String, dynamic> item) {
  return AlbumInfo.fromMap(
    item,
    fallbackPlatform: _safePlatform(item['platform']),
  );
}

ArtistInfo searchArtistInfo(Map<String, dynamic> item) {
  return ArtistInfo.fromMap(
    item,
    fallbackPlatform: _safePlatform(item['platform']),
  );
}

String _artistSearchSubtitle(ArtistInfo artist) {
  final platform = _safeText(artist.platform);
  final alias = artist.alias.trim();
  if (alias.isEmpty) {
    return platform;
  }
  return '$platform · $alias';
}

String text(dynamic value) {
  if (value == null) {
    return '-';
  }
  final parsed = '$value'.trim();
  if (parsed.isEmpty) {
    return '-';
  }
  return parsed;
}

String _countText(dynamic value) {
  final parsed = int.tryParse('${value ?? ''}');
  if (parsed == null || parsed < 0) {
    return '0';
  }
  return '$parsed';
}

String _safeText(String? value) {
  final parsed = (value ?? '').trim();
  if (parsed.isEmpty) {
    return '-';
  }
  return parsed;
}

String _string(dynamic value) => '${value ?? ''}'.trim();

String _safePlatform(dynamic value) {
  final platform = _string(value);
  if (platform.isEmpty) {
    return '-';
  }
  return platform;
}

List<SongInfoArtistInfo> _artistsFromDynamic(dynamic value) {
  if (value is List) {
    return value
        .map((entry) {
          if (entry is Map<String, dynamic>) {
            return SongInfoArtistInfo.fromMap(entry);
          }
          if (entry is Map) {
            return SongInfoArtistInfo.fromMap(
              entry.map((key, item) => MapEntry('$key', item)),
            );
          }
          return SongInfoArtistInfo(id: '', name: '$entry'.trim());
        })
        .where((entry) => entry.name.isNotEmpty)
        .toList(growable: false);
  }
  final text = _string(value);
  if (text.isEmpty) {
    return const <SongInfoArtistInfo>[];
  }
  return <SongInfoArtistInfo>[SongInfoArtistInfo(id: '', name: text)];
}

String _artistNames(List<SongInfoArtistInfo> artists) {
  final names = artists
      .map((entry) => entry.name.trim())
      .where((entry) => entry.isNotEmpty)
      .toList(growable: false);
  if (names.isEmpty) {
    return '';
  }
  return names.join('/');
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, entry) => MapEntry('$key', entry));
  }
  return <String, dynamic>{};
}
