import '../entities/local_song.dart';

abstract class LocalMusicRepository {
  Future<bool> requestPermission();
  Future<List<LocalSong>> scanSongs();
}
