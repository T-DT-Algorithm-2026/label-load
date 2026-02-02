import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:label_load/services/gadgets/gadget_repository.dart';

void main() {
  test('listLabelFiles excludes classes.txt and uses natural order', () async {
    final root = await Directory.systemTemp.createTemp('gadget_repo_');
    addTearDown(() => root.delete(recursive: true));

    await File(path.join(root.path, '10.txt')).writeAsString('a');
    await File(path.join(root.path, '2.txt')).writeAsString('b');
    await File(path.join(root.path, 'classes.txt')).writeAsString('ignore');

    final repo = FileGadgetRepository();
    final files = await repo.listLabelFiles(root.path);

    expect(files.length, 2);
    expect(path.basename(files.first), '2.txt');
    expect(path.basename(files.last), '10.txt');
  });

  test('readClassNames/writeClassNames round trip', () async {
    final root = await Directory.systemTemp.createTemp('gadget_repo_');
    addTearDown(() => root.delete(recursive: true));

    final repo = FileGadgetRepository();
    await repo.writeClassNames(root.path, ['cat', 'dog']);

    final names = await repo.readClassNames(root.path);
    expect(names, ['cat', 'dog']);
  });

  test('listImageFiles/listVideoFiles use natural order', () async {
    final root = await Directory.systemTemp.createTemp('gadget_repo_');
    addTearDown(() => root.delete(recursive: true));

    await File(path.join(root.path, '10.jpg')).writeAsString('a');
    await File(path.join(root.path, '2.jpg')).writeAsString('b');
    await File(path.join(root.path, '3.mp4')).writeAsString('c');
    await File(path.join(root.path, '12.mp4')).writeAsString('d');

    final repo = FileGadgetRepository();
    final images = await repo.listImageFiles(root.path);
    final videos = await repo.listVideoFiles(root.path);

    expect(path.basename(images.first), '2.jpg');
    expect(path.basename(images.last), '10.jpg');
    expect(path.basename(videos.first), '3.mp4');
    expect(path.basename(videos.last), '12.mp4');
  });

  test('readLines filters empty lines and writeLines persists', () async {
    final root = await Directory.systemTemp.createTemp('gadget_repo_');
    addTearDown(() => root.delete(recursive: true));

    final filePath = path.join(root.path, 'data.txt');
    await File(filePath).writeAsString('a\n\nb\n');

    final repo = FileGadgetRepository();
    final lines = await repo.readLines(filePath);
    expect(lines, ['a', 'b']);

    await repo.writeLines(filePath, ['x', 'y']);
    final updated = await repo.readLines(filePath);
    expect(updated, ['x', 'y']);
  });

  test('renameFile renames file', () async {
    final root = await Directory.systemTemp.createTemp('gadget_repo_');
    addTearDown(() => root.delete(recursive: true));

    final from = path.join(root.path, 'old.txt');
    final to = path.join(root.path, 'new.txt');
    await File(from).writeAsString('content');

    final repo = FileGadgetRepository();
    await repo.renameFile(from, to);

    expect(await File(to).exists(), isTrue);
    expect(await File(from).exists(), isFalse);
  });
}
