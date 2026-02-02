import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/services/files/file_service.dart';
import 'package:label_load/models/label.dart';
import 'package:label_load/models/label_definition.dart';
import 'package:path/path.dart' as p;

import '../test_helpers.dart';

void main() {
  test('FileService reports parse failures and returns corrupted lines',
      () async {
    final root = await createTempDir('file_service_');
    final labelPath = p.join(root.path, 'bad.txt');
    await writeTextFile(root, 'bad.txt', 'bad_line');

    FlutterErrorDetails? captured;
    final original = FlutterError.onError;
    FlutterError.onError = (details) => captured = details;
    addTearDown(() => FlutterError.onError = original);

    final service = FileService();
    final result = await service.readLabels(labelPath, (_) => 'name');

    expect(result.$1, isEmpty);
    expect(result.$2, ['bad_line']);
    expect(captured, isNotNull);
  });

  test('FileService returns empty when label file missing', () async {
    final root = await createTempDir('file_service_');

    final service = FileService();
    final result = await service.readLabels(
      p.join(root.path, 'missing.txt'),
      (_) => 'name',
    );

    expect(result.$1, isEmpty);
    expect(result.$2, isEmpty);
  });

  test('FileService writes labels with corrupted lines preserved', () async {
    final root = await createTempDir('file_service_');

    final labelPath = p.join(root.path, 'labels.txt');
    final definitions = [
      LabelDefinition(
        classId: 0,
        name: 'poly',
        color: const Color(0xFF000000),
        type: LabelType.polygon,
      ),
    ];
    final labels = [
      Label(
        id: 0,
        points: [
          LabelPoint(x: 0.1, y: 0.2),
          LabelPoint(x: 0.2, y: 0.3),
          LabelPoint(x: 0.3, y: 0.4),
        ],
      ),
    ];

    final service = FileService();
    await service.writeLabels(
      labelPath,
      labels,
      labelDefinitions: definitions,
      corruptedLines: ['bad line'],
    );

    final content = await File(labelPath).readAsString();
    final lines = content.trim().split('\n');
    expect(lines.length, 2);
    expect(lines.last, 'bad line');
    expect(lines.first.split(' ').length, 7);
  });

  test('FileService reads class names from classes file', () async {
    final root = await createTempDir('file_service_');

    await writeTextFile(root, 'classes.names', 'a\nb\n');

    final service = FileService();
    final names = await service.readClassNames(root.path);

    expect(names, ['a', 'b']);
  });

  test('FileService writes class names to classes.txt', () async {
    final root = await createTempDir('file_service_');

    final service = FileService();
    await service.writeClassNames(root.path, ['x', 'y']);

    final content = await File(p.join(root.path, 'classes.txt')).readAsString();
    expect(content.trim(), 'x\ny');
  });

  test('FileService getImageFiles lists supported images', () async {
    final root = await createTempDir('file_service_');
    await writeTextFile(root, 'a.jpg', 'a');
    await writeTextFile(root, 'b.png', 'b');
    await writeTextFile(root, 'c.txt', 'c');

    final service = FileService();
    final images = await service.getImageFiles(root.path);

    expect(images.length, 2);
    expect(images.any((p) => p.endsWith('a.jpg')), isTrue);
    expect(images.any((p) => p.endsWith('b.png')), isTrue);
  });
}
