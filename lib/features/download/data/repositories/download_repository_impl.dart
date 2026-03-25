import '../../domain/repositories/download_repository.dart';
import '../datasources/download_file_data_source.dart';
import '../datasources/download_path_data_source.dart';

const _fallbackExtension = 'mp3';
const _safeNameFallback = 'audio';

class DownloadRepositoryImpl implements DownloadRepository {
  DownloadRepositoryImpl(this._fileDataSource, this._pathDataSource);

  final DownloadFileDataSource _fileDataSource;
  final DownloadPathDataSource _pathDataSource;

  @override
  Future<String> resolveSavePath({
    required String title,
    required String url,
  }) async {
    final extension = _resolveExtension(url);
    final safeTitle = _sanitize(title);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final dir = await _pathDataSource.ensureDownloadDirectory();
    return '${dir.path}/${safeTitle}_$timestamp.$extension';
  }

  @override
  Future<void> downloadFile({
    required String url,
    required String savePath,
    required DownloadProgressCallback onProgress,
  }) {
    return _fileDataSource.download(
      url: url,
      savePath: savePath,
      onProgress: onProgress,
    );
  }

  String _resolveExtension(String url) {
    final uri = Uri.parse(url);
    final last = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    final dotIndex = last.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex == last.length - 1) {
      return _fallbackExtension;
    }
    return last.substring(dotIndex + 1).toLowerCase();
  }

  String _sanitize(String input) {
    final value = input.trim();
    if (value.isEmpty) {
      return _safeNameFallback;
    }
    final sanitized = value.replaceAll(
      RegExp(r'[^a-zA-Z0-9_\-\u4e00-\u9fa5]+'),
      '_',
    );
    return sanitized.isEmpty ? _safeNameFallback : sanitized;
  }
}
