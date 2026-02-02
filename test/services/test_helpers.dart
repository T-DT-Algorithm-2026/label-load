import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// 创建临时目录并在用例结束后自动清理。
Future<Directory> createTempDir(String prefix) async {
  final dir = await Directory.systemTemp.createTemp(prefix);
  addTearDown(() => dir.delete(recursive: true));
  return dir;
}

/// 写入文本文件并返回文件句柄。
Future<File> writeTextFile(
  Directory dir,
  String name,
  String contents,
) async {
  final file = File(p.join(dir.path, name));
  await file.writeAsString(contents);
  return file;
}

/// 写入二进制文件并返回文件句柄。
Future<File> writeBytesFile(
  Directory dir,
  String name,
  List<int> bytes,
) async {
  final file = File(p.join(dir.path, name));
  await file.writeAsBytes(bytes);
  return file;
}
