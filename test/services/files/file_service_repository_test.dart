import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/services/files/file_service.dart';
import 'package:label_load/services/files/text_file_repository.dart';

class MemoryTextRepository implements TextFileRepository {
  bool existsValue = true;
  String content = '';
  String? lastReadPath;

  @override
  Future<bool> exists(String path) async => existsValue;

  @override
  Future<String> readString(String path) async {
    lastReadPath = path;
    return content;
  }

  @override
  Future<void> writeString(String path, String content) async {}
}

void main() {
  test('FileService.readLabels uses injected repository', () async {
    final repo = MemoryTextRepository();
    repo.content = '0 0.5 0.5 0.2 0.2';

    final service = FileService(repository: repo);
    final result = await service.readLabels('labels.txt', (_) => 'name');

    expect(repo.lastReadPath, 'labels.txt');
    expect(result.$1.length, 1);
    expect(result.$2, isEmpty);
  });
}
