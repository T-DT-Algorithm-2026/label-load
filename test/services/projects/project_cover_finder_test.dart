import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/services/projects/project_cover_finder.dart';

import '../test_helpers.dart';

void main() {
  test('ProjectCoverFinder returns first image', () async {
    final root = await createTempDir('cover_finder_');

    await writeTextFile(root, 'a.txt', 'x');
    final image = await writeTextFile(root, 'cover.png', 'img');

    const finder = ProjectCoverFinder();
    final result = await finder.findFirstImagePath(root.path);

    expect(result, image.path);
  });

  test('ProjectCoverFinder returns null when no image', () async {
    final root = await createTempDir('cover_finder_');

    await writeTextFile(root, 'a.txt', 'x');

    const finder = ProjectCoverFinder();
    final result = await finder.findFirstImagePath(root.path);

    expect(result, isNull);
  });
}
