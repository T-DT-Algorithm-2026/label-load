import 'dart:io';
import 'package:path/path.dart' as p;
import '../app/app_error.dart';
import '../app/error_reporter.dart';

/// 原子写入文件（尽量避免中途写入导致的损坏）
Future<void> atomicWriteString(String path, String content) async {
  try {
    final dir = Directory(p.dirname(path));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final tmpName =
        '.${p.basename(path)}.tmp${DateTime.now().microsecondsSinceEpoch}';
    final tmpPath = p.join(dir.path, tmpName);
    final tmpFile = File(tmpPath);

    await tmpFile.writeAsString(content);

    // Prefer atomic rename; fall back to delete + rename for platforms that
    // disallow overwriting.
    try {
      await tmpFile.rename(path);
    } catch (_) {
      final target = File(path);
      if (await target.exists()) {
        await target.delete();
      }
      await tmpFile.rename(path);
    }
  } catch (e, stack) {
    ErrorReporter.report(
      e,
      AppErrorCode.ioOperationFailed,
      stackTrace: stack,
      details: 'atomic write: $path ($e)',
    );
    rethrow;
  }
}
