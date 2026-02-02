import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:label_load/models/label.dart';
import 'package:label_load/models/label_definition.dart';
import 'package:label_load/services/labels/label_file_repository.dart';

import '../test_helpers.dart';

void main() {
  test('FileLabelRepository writes and reads labels', () async {
    final root = await createTempDir('label_repo_');

    final labelDir = path.join(root.path, 'labels');
    final labelPath = path.join(labelDir, 'img1.txt');

    final repo = FileLabelRepository();
    await repo.ensureDirectory(labelDir);
    expect(await Directory(labelDir).exists(), isTrue);

    final definitions = [
      LabelDefinition(
        classId: 0,
        name: 'class_0',
        color: const Color(0xFF000000),
        type: LabelType.box,
      ),
    ];

    final labels = [
      Label(id: 0, x: 0.1, y: 0.2, width: 0.3, height: 0.4),
    ];

    await repo.writeLabels(
      labelPath,
      labels,
      labelDefinitions: definitions,
    );

    final result = await repo.readLabels(
      labelPath,
      (id) => definitions.first.name,
      labelDefinitions: definitions,
    );

    expect(result.$1.length, 1);
    expect(result.$2, isEmpty);
    expect(result.$1.first.id, 0);
  });

  test('FileLabelRepository deleteIfExists removes file', () async {
    final root = await createTempDir('label_repo_');

    final labelPath = path.join(root.path, 'to_delete.txt');
    await writeTextFile(root, 'to_delete.txt', '0 0.1 0.2 0.3 0.4');

    final repo = FileLabelRepository();
    expect(await repo.exists(labelPath), isTrue);
    await repo.deleteIfExists(labelPath);
    expect(await repo.exists(labelPath), isFalse);

    await repo.deleteIfExists(labelPath);
  });
}
