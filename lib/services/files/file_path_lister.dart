import 'dart:io';

/// Abstraction for listing file paths under a directory.
abstract class FilePathLister {
  /// Returns a stream of file paths in [directoryPath].
  Stream<String> listFiles(String directoryPath);
}

/// [FilePathLister] implementation backed by [Directory.list].
class DirectoryFilePathLister implements FilePathLister {
  const DirectoryFilePathLister();

  @override
  Stream<String> listFiles(String directoryPath) async* {
    final dir = Directory(directoryPath);
    if (!await dir.exists()) return;
    await for (final entity in dir.list()) {
      if (entity is File) {
        yield entity.path;
      }
    }
  }
}
