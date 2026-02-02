import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/models/label_definition.dart';
import 'package:label_load/services/labels/label_definition_io.dart';
import 'package:label_load/services/files/text_file_repository.dart';

class MemoryTextRepository implements TextFileRepository {
  String? lastWritePath;
  String? lastWriteContent;
  String? readContent;
  bool existsValue = true;

  @override
  Future<bool> exists(String path) async => existsValue;

  @override
  Future<String> readString(String path) async {
    return readContent ?? '[]';
  }

  @override
  Future<void> writeString(String path, String content) async {
    lastWritePath = path;
    lastWriteContent = content;
  }
}

void main() {
  test('LabelDefinitionIo writes using injected repository', () async {
    final repo = MemoryTextRepository();
    final io = LabelDefinitionIo(repository: repo);

    final definitions = [
      LabelDefinition(classId: 0, name: 'cat', color: const Color(0xFF000000)),
    ];

    await io.exportToFile('labels.json', definitions);

    expect(repo.lastWritePath, 'labels.json');
    expect(repo.lastWriteContent, contains('cat'));
  });
}
