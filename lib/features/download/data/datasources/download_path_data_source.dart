import 'dart:io';

import 'package:path_provider/path_provider.dart';

const _downloadDirName = 'HEMusic';

class DownloadPathDataSource {
  Future<Directory> ensureDownloadDirectory() async {
    final baseDir =
        await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
    final targetDir = Directory('${baseDir.path}/$_downloadDirName');
    try {
      if (await targetDir.exists()) {
        return targetDir;
      }
      return await targetDir.create(recursive: true);
    } on FileSystemException {
      final fallbackBaseDir = await getApplicationDocumentsDirectory();
      final fallbackDir = Directory(
        '${fallbackBaseDir.path}/$_downloadDirName',
      );
      if (await fallbackDir.exists()) {
        return fallbackDir;
      }
      return fallbackDir.create(recursive: true);
    }
  }
}
