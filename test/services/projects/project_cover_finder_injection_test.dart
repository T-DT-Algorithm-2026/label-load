import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/services/files/file_path_lister.dart';
import 'package:label_load/services/projects/project_cover_finder.dart';

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

class ThrowingFilePathLister implements FilePathLister {
  @override
  Stream<String> listFiles(String directoryPath) async* {
    throw Exception('list failed');
  }
}

void main() {
  test('ProjectCoverFinder uses injected lister', () async {
    final lister = FakeFilePathLister([
      '/tmp/readme.txt',
      '/tmp/cover.jpg',
      '/tmp/other.png',
    ]);
    final finder = ProjectCoverFinder(filePathLister: lister);
    final result = await finder.findFirstImagePath('/tmp');
    expect(result, '/tmp/cover.jpg');
  });

  test('ProjectCoverFinder returns null when lister throws', () async {
    final finder = ProjectCoverFinder(filePathLister: ThrowingFilePathLister());
    final result = await finder.findFirstImagePath('/tmp');
    expect(result, isNull);
  });
}
