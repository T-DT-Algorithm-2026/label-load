import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:label_load/services/files/atomic_file_writer.dart';

import '../test_helpers.dart';

class RenameFailingFile implements File {
  RenameFailingFile(this._delegate, {this.failRenameOnce = false});

  final File _delegate;
  final bool failRenameOnce;
  int _renameCalls = 0;

  @override
  String get path => _delegate.path;

  @override
  Future<File> writeAsString(
    String contents, {
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
    bool flush = false,
  }) {
    return _delegate.writeAsString(
      contents,
      mode: mode,
      encoding: encoding,
      flush: flush,
    );
  }

  @override
  Future<File> rename(String newPath) {
    if (failRenameOnce && _renameCalls == 0) {
      _renameCalls += 1;
      throw FileSystemException(
          'rename failed', path, const OSError('EEXIST', 17));
    }
    _renameCalls += 1;
    return _delegate.rename(newPath);
  }

  @override
  Future<bool> exists() => _delegate.exists();

  @override
  Future<File> delete({bool recursive = false}) {
    return _delegate.delete(recursive: recursive).then((_) => _delegate);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DefaultIOOverrides extends IOOverrides {}

class WriteFailingFile implements File {
  WriteFailingFile(this._delegate);

  final File _delegate;

  @override
  String get path => _delegate.path;

  @override
  Future<File> writeAsString(
    String contents, {
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
    bool flush = false,
  }) {
    throw FileSystemException('write failed', path);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('atomicWriteString', () {
    test('writes and replaces content without temp leftovers', () async {
      final dir = await createTempDir('label_load_atomic_');

      final path = p.join(dir.path, 'labels.txt');
      await atomicWriteString(path, 'first');
      await atomicWriteString(path, 'second');

      final content = await File(path).readAsString();
      expect(content, 'second');

      final tempFiles = dir
          .listSync()
          .whereType<File>()
          .where((file) => p.basename(file.path).startsWith('.labels.txt.tmp'))
          .toList();
      expect(tempFiles, isEmpty);
    });

    test('creates directory when missing', () async {
      final dir = await createTempDir('label_load_atomic_');

      final nested = p.join(dir.path, 'nested', 'labels.txt');
      await atomicWriteString(nested, 'content');

      expect(await File(nested).exists(), isTrue);
    });

    test('falls back to delete target when rename fails', () async {
      final dir = await createTempDir('label_load_atomic_');

      final path = p.join(dir.path, 'labels.txt');
      await File(path).writeAsString('old');

      final defaults = _DefaultIOOverrides();
      await IOOverrides.runZoned(
        () async {
          await atomicWriteString(path, 'new');
        },
        createFile: (filePath) {
          final file = defaults.createFile(filePath);
          final shouldFailRename =
              p.basename(filePath).startsWith('.labels.txt.tmp');
          return RenameFailingFile(
            file,
            failRenameOnce: shouldFailRename,
          );
        },
      );

      final content = await File(path).readAsString();
      expect(content, 'new');
    });

    test('reports and rethrows when write fails', () async {
      final dir = await createTempDir('label_load_atomic_');

      final path = p.join(dir.path, 'labels.txt');
      final defaults = _DefaultIOOverrides();

      await IOOverrides.runZoned(
        () async {
          await expectLater(
            () => atomicWriteString(path, 'fail'),
            throwsA(isA<FileSystemException>()),
          );
        },
        createFile: (filePath) {
          final file = defaults.createFile(filePath);
          return WriteFailingFile(file);
        },
      );
    });
  });
}
