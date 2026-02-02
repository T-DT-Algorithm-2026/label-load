import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:label_load/models/label_definition.dart';
import 'package:label_load/services/labels/label_definition_io.dart';

import '../test_helpers.dart';

void main() {
  test('LabelDefinitionIo exports and imports definitions', () async {
    final root = await createTempDir('label_defs_');

    final filePath = path.join(root.path, 'labels.json');
    final io = LabelDefinitionIo();

    final definitions = [
      LabelDefinition(
        classId: 1,
        name: 'cat',
        color: const Color(0xFF123456),
        type: LabelType.box,
      ),
      LabelDefinition(
        classId: 2,
        name: 'dog',
        color: const Color(0xFF654321),
        type: LabelType.polygon,
      ),
    ];

    await io.exportToFile(filePath, definitions);
    final imported = await io.importFromFile(filePath);

    expect(imported.length, 2);
    expect(imported[0].classId, 1);
    expect(imported[0].name, 'cat');
    expect(imported[1].type, LabelType.polygon);
  });

  test('LabelDefinitionIo uses fallback class id when missing', () async {
    final root = await createTempDir('label_defs_');

    final filePath = path.join(root.path, 'labels.json');
    await writeTextFile(
        root, 'labels.json', '[{"name":"x","color":4278190080}]');

    final io = LabelDefinitionIo();
    final imported = await io.importFromFile(filePath);

    expect(imported.length, 1);
    expect(imported.first.classId, 0);
  });
}
