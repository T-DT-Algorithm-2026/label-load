import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:label_load/models/label.dart';
import 'package:label_load/models/label_definition.dart';
import 'package:label_load/services/image/image_repository.dart';
import 'package:label_load/services/labels/label_file_repository.dart';
import 'package:label_load/services/projects/project_repository.dart';

class FakeImageRepository implements ImageRepository {
  FakeImageRepository(this.paths);

  final List<String> paths;

  @override
  Future<List<String>> listImagePaths(String directoryPath) async {
    return paths;
  }

  @override
  Future<bool> exists(String path) async => true;

  @override
  Future<Uint8List> readBytes(String path) async =>
      Uint8List.fromList([1, 2, 3]);

  @override
  Future<void> deleteIfExists(String path) async {}
}

class FakeLabelRepository implements LabelFileRepository {
  List<Label>? lastWritten;
  String? lastWritePath;
  List<Label> readResult = [];

  @override
  Future<void> ensureDirectory(String directoryPath) async {}

  @override
  Future<bool> exists(String path) async => true;

  @override
  Future<void> deleteIfExists(String path) async {}

  @override
  Future<(List<Label>, List<String>)> readLabels(
    String labelPath,
    String Function(int) getName, {
    List<LabelDefinition>? labelDefinitions,
  }) async {
    return (readResult, <String>[]);
  }

  @override
  Future<void> writeLabels(
    String labelPath,
    List<Label> labels, {
    List<LabelDefinition>? labelDefinitions,
    List<String>? corruptedLines,
  }) async {
    lastWritePath = labelPath;
    lastWritten = labels;
  }
}

void main() {
  test('ProjectRepository delegates to repositories', () async {
    final imageRepo = FakeImageRepository(['a.jpg', 'b.jpg']);
    final labelRepo = FakeLabelRepository();
    labelRepo.readResult = [Label(id: 1)];

    final repository = ProjectRepository(
      imageRepository: imageRepo,
      labelRepository: labelRepo,
    );

    final images = await repository.listImageFiles('dir');
    expect(images, ['a.jpg', 'b.jpg']);

    final read = await repository.readLabels('labels.txt', (_) => 'name');
    expect(read.$1.length, 1);

    await repository.writeLabels('out.txt', [Label(id: 2)]);
    expect(labelRepo.lastWritePath, 'out.txt');
    expect(labelRepo.lastWritten!.first.id, 2);
  });

  test('ProjectRepository defaults use file system repositories', () async {
    final root = await Directory.systemTemp.createTemp('project_repo_');
    addTearDown(() => root.delete(recursive: true));

    final imageDir = Directory(path.join(root.path, 'images'));
    final labelDir = Directory(path.join(root.path, 'labels'));
    await imageDir.create();
    await labelDir.create();

    final imagePath = path.join(imageDir.path, 'img1.jpg');
    await File(imagePath).writeAsString('x');

    final labelPath = path.join(labelDir.path, 'img1.txt');
    await File(labelPath).writeAsString('0 0.5 0.5 0.2 0.2');

    final repository = ProjectRepository();
    final images = await repository.listImageFiles(imageDir.path);
    expect(images, [imagePath]);

    final result = await repository.readLabels(labelPath, (_) => 'class_0');
    expect(result.$1.length, 1);

    await repository.writeLabels(labelPath, [Label(id: 1)]);
    final updated = await File(labelPath).readAsString();
    expect(updated.startsWith('1 '), isTrue);
  });
}
