import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/services/files/file_listing.dart';
import 'package:label_load/services/files/file_path_lister.dart';

class FakeFilePathLister implements FilePathLister {
  FakeFilePathLister(this.paths);

  final List<String> paths;

  @override
  Stream<String> listFiles(String directoryPath) async* {
    for (final path in paths) {
      yield path;
    }
  }
}

void main() {
  test('FileListing uses injected file path lister', () async {
    final lister = FakeFilePathLister([
      '/tmp/1.txt',
      '/tmp/2.jpg',
      '/tmp/3.png',
    ]);

    final result = await FileListing.listByExtensions(
      '/tmp',
      ['.jpg', '.png'],
      filePathLister: lister,
    );

    expect(result, ['/tmp/2.jpg', '/tmp/3.png']);
  });
}
