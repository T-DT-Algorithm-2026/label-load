import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:label_load/services/files/file_service.dart';
import 'package:label_load/services/gadgets/gadget_service.dart';

import '../test_helpers.dart';

void main() {
  group('File listing', () {
    test('FileService.getImageFiles sorts lexicographically', () async {
      final dir = await createTempDir('label_load_files_');

      const names = ['2.jpg', '10.jpg', '1.jpg'];
      for (final name in names) {
        await writeTextFile(dir, name, 'x');
      }

      final service = FileService();
      final files = await service.getImageFiles(dir.path);
      final expected = names.map((name) => p.join(dir.path, name)).toList()
        ..sort((a, b) => a.compareTo(b));

      expect(files, expected);
    });

    test('GadgetService.getImageFiles uses natural order', () async {
      final dir = await createTempDir('label_load_files_');

      const names = ['10.jpg', '2.jpg', '1.jpg'];
      for (final name in names) {
        await writeTextFile(dir, name, 'x');
      }

      final service = GadgetService();
      final files = await service.getImageFiles(dir.path);
      final basenames = files.map(p.basename).toList();

      expect(basenames, ['1.jpg', '2.jpg', '10.jpg']);
    });
  });
}
