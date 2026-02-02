import 'dart:io';

import 'atomic_file_writer.dart';

/// Repository abstraction for reading and writing UTF-8 text files.
abstract class TextFileRepository {
  /// Returns whether a file exists at [path].
  Future<bool> exists(String path);

  /// Reads the full file content from [path].
  Future<String> readString(String path);

  /// Writes [content] to [path].
  Future<void> writeString(String path, String content);
}

/// File-system backed [TextFileRepository] with atomic writes.
class FileTextRepository implements TextFileRepository {
  @override
  Future<bool> exists(String path) {
    return File(path).exists();
  }

  @override
  Future<String> readString(String path) {
    return File(path).readAsString();
  }

  @override
  Future<void> writeString(String path, String content) {
    return atomicWriteString(path, content);
  }
}
