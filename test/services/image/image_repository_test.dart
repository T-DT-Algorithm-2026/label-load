import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:label_load/services/image/image_repository.dart';

import '../test_helpers.dart';

void main() {
  test('FileImageRepository lists images and reads bytes', () async {
    final root = await createTempDir('image_repo_');

    final imageA = await writeBytesFile(root, 'a.jpg', const [1, 2, 3]);
    final imageB = await writeBytesFile(root, 'b.png', const [4, 5]);
    await writeTextFile(root, 'note.txt', 'skip');

    final repo = FileImageRepository();
    final paths = await repo.listImagePaths(root.path);

    expect(paths, [imageA.path, imageB.path]);
    expect(await repo.exists(imageA.path), isTrue);
    expect(await repo.exists(path.join(root.path, 'missing.jpg')), isFalse);

    final bytes = await repo.readBytes(imageB.path);
    expect(bytes, [4, 5]);
  });

  test('FileImageRepository deleteIfExists removes file safely', () async {
    final root = await createTempDir('image_repo_');

    final target = await writeBytesFile(root, 'delete.jpg', const [1]);

    final repo = FileImageRepository();
    await repo.deleteIfExists(target.path);
    expect(await target.exists(), isFalse);

    await repo.deleteIfExists(path.join(root.path, 'missing.jpg'));
  });
}
