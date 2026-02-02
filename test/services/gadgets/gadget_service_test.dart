import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:label_load/services/gadgets/gadget_repository.dart';
import 'package:label_load/services/gadgets/gadget_service.dart';

class MemoryGadgetRepository implements GadgetRepository {
  MemoryGadgetRepository({
    List<String>? imageFiles,
    List<String>? videoFiles,
    List<String>? labelFiles,
    Map<String, List<String>>? linesByPath,
  })  : _imageFiles = imageFiles ?? <String>[],
        _videoFiles = videoFiles ?? <String>[],
        _labelFiles = labelFiles ?? <String>[],
        _linesByPath = linesByPath ?? <String, List<String>>{};

  final List<String> _imageFiles;
  final List<String> _videoFiles;
  final List<String> _labelFiles;
  final Map<String, List<String>> _linesByPath;
  final List<(String, String)> renameCalls = [];
  final Set<String> failRename = {};
  List<String> classNames = [];

  @override
  Future<List<String>> listImageFiles(String directoryPath) async =>
      _imageFiles;

  @override
  Future<List<String>> listVideoFiles(String directoryPath) async =>
      _videoFiles;

  @override
  Future<List<String>> listLabelFiles(String directoryPath) async =>
      _labelFiles;

  @override
  Future<void> renameFile(String from, String to) async {
    renameCalls.add((from, to));
    if (failRename.contains(from)) {
      throw Exception('rename failed');
    }
  }

  @override
  Future<List<String>> readLines(String path) async {
    return _linesByPath[path] ?? <String>[];
  }

  @override
  Future<void> writeLines(String path, List<String> lines) async {
    _linesByPath[path] = lines;
  }

  @override
  Future<List<String>> readClassNames(String labelDir) async => classNames;

  @override
  Future<void> writeClassNames(
    String labelDir,
    List<String> classNames,
  ) async {
    this.classNames = classNames;
  }
}

void main() {
  group('GadgetService basic delegates', () {
    test('lists files via repository', () async {
      final repo = MemoryGadgetRepository(
        imageFiles: ['a.jpg'],
        videoFiles: ['b.mp4'],
        labelFiles: ['c.txt'],
      );
      final service = GadgetService(repository: repo);

      expect(await service.getImageFiles('/tmp'), ['a.jpg']);
      expect(await service.getVideoFiles('/tmp'), ['b.mp4']);
      expect(await service.getLabelFiles('/tmp'), ['c.txt']);
    });

    test('readLines delegates to repository', () async {
      final repo = MemoryGadgetRepository(
        linesByPath: {
          '/tmp/a.txt': ['a', 'b']
        },
      );
      final service = GadgetService(repository: repo);

      final lines = await service.readLines('/tmp/a.txt');
      expect(lines, ['a', 'b']);
    });

    test('readClassNames/writeClassNames delegate', () async {
      final repo = MemoryGadgetRepository();
      final service = GadgetService(repository: repo);

      await service.writeClassNames('/labels', ['cat', 'dog']);
      final names = await service.readClassNames('/labels');

      expect(names, ['cat', 'dog']);
    });
  });

  group('GadgetService batchRename', () {
    test('renames to temp then final and reports progress', () async {
      final repo = MemoryGadgetRepository(
        imageFiles: [
          p.join('/tmp', '0.jpg'),
          p.join('/tmp', '1.jpg'),
        ],
      );
      final service = GadgetService(repository: repo);

      final progress = <(int, int)>[];
      final result = await service.batchRename(
        '/tmp',
        onProgress: (current, total) => progress.add((current, total)),
      );

      expect(result, (2, 0));
      expect(repo.renameCalls.length, 4);
      expect(progress.length, 4);
      expect(progress.first, (1, 4));
      expect(progress.last, (4, 4));
    });

    test('counts failures when rename fails', () async {
      final repo = MemoryGadgetRepository(
        imageFiles: [
          p.join('/tmp', '0.jpg'),
          p.join('/tmp', '1.jpg'),
        ],
      );
      repo.failRename.add(p.join('/tmp', '1.jpg'));
      final service = GadgetService(repository: repo);

      final result = await service.batchRename('/tmp');

      expect(result.$1, 1);
      expect(result.$2, 1);
    });
  });

  group('GadgetService label transforms', () {
    test('xyxy2xywh converts and counts failures', () async {
      const labelPath = '/labels/a.txt';
      final repo = MemoryGadgetRepository(
        labelFiles: [labelPath],
        linesByPath: {
          labelPath: [
            '0 0 0 1 1 extra',
            'bad',
          ],
        },
      );
      final service = GadgetService(repository: repo);

      final result = await service.xyxy2xywh('/labels');

      expect(result, (1, 1));
      final written = repo.readLines(labelPath);
      expect(
        await written,
        ['0 0.5 0.5 1.0 1.0 extra'],
      );
    });

    test('bboxExpand clamps to valid range', () async {
      const labelPath = '/labels/b.txt';
      final repo = MemoryGadgetRepository(
        labelFiles: [labelPath],
        linesByPath: {
          labelPath: ['0 0.9 0.9 0.4 0.4'],
        },
      );
      final service = GadgetService(repository: repo);

      final result = await service.bboxExpand(
        '/labels',
        ratioX: 2,
        ratioY: 2,
      );

      expect(result, (1, 0));
      final output = (await repo.readLines(labelPath)).first;
      final parts = output.split(' ');
      expect(parts.first, '0');
      expect(double.parse(parts[1]), closeTo(0.75, 1e-6));
      expect(double.parse(parts[2]), closeTo(0.75, 1e-6));
      expect(double.parse(parts[3]), closeTo(0.5, 1e-6));
      expect(double.parse(parts[4]), closeTo(0.5, 1e-6));
    });

    test('checkAndFix fixes out-of-bounds and removes duplicates', () async {
      const labelPath = '/labels/c.txt';
      final repo = MemoryGadgetRepository(
        labelFiles: [labelPath],
        linesByPath: {
          labelPath: [
            '0 0.9 0.9 0.4 0.4',
            '0 0.9 0.9 0.4 0.4',
            'bad',
          ],
        },
      );
      final service = GadgetService(repository: repo);

      final result = await service.checkAndFix('/labels');

      expect(result, (1, 1));
      final written = await repo.readLines(labelPath);
      expect(written.length, 1);
      final parts = written.first.split(' ');
      expect(parts.first, '0');
      expect(double.parse(parts[1]), lessThanOrEqualTo(1.0));
      expect(double.parse(parts[2]), lessThanOrEqualTo(1.0));
    });

    test('deleteKeypoints trims to 5 columns', () async {
      const labelPath = '/labels/d.txt';
      final repo = MemoryGadgetRepository(
        labelFiles: [labelPath],
        linesByPath: {
          labelPath: ['0 0.1 0.2 0.3 0.4 0.5 0.6'],
        },
      );
      final service = GadgetService(repository: repo);

      final result = await service.deleteKeypoints('/labels');

      expect(result, (1, 0));
      final written = await repo.readLines(labelPath);
      expect(written.first, '0 0.1 0.2 0.3 0.4');
    });

    test('addBboxFromKeypoints calculates bbox and keeps points', () async {
      const labelPath = '/labels/e.txt';
      final repo = MemoryGadgetRepository(
        labelFiles: [labelPath],
        linesByPath: {
          labelPath: ['1 0.2 0.2 0.4 0.4 0.3 0.5'],
        },
      );
      final service = GadgetService(repository: repo);

      final result = await service.addBboxFromKeypoints('/labels');

      expect(result, (1, 0));
      final parts = (await repo.readLines(labelPath)).first.split(' ');
      expect(parts.first, '1');
      expect(double.parse(parts[1]), closeTo(0.3, 1e-6));
      expect(double.parse(parts[2]), closeTo(0.35, 1e-6));
      expect(double.parse(parts[3]), closeTo(0.2, 1e-6));
      expect(double.parse(parts[4]), closeTo(0.3, 1e-6));
      expect(parts.sublist(5), ['0.2', '0.2', '0.4', '0.4', '0.3', '0.5']);
    });

    test('addBboxFromKeypoints counts invalid lines', () async {
      const labelPath = '/labels/f.txt';
      final repo = MemoryGadgetRepository(
        labelFiles: [labelPath],
        linesByPath: {
          labelPath: ['1 0.2 0.2 0.4'],
        },
      );
      final service = GadgetService(repository: repo);

      final result = await service.addBboxFromKeypoints('/labels');

      expect(result, (1, 1));
    });
  });

  group('GadgetService label edits', () {
    test('convertLabels remaps ids and drops deleted classes', () async {
      const labelPath = '/labels/g.txt';
      final repo = MemoryGadgetRepository(
        labelFiles: [labelPath],
        linesByPath: {
          labelPath: [
            '0 0.1 0.2 0.3 0.4',
            '1 0.1 0.2 0.3 0.4',
            '3 0.1 0.2 0.3 0.4',
            'bad line',
          ],
        },
      );
      final service = GadgetService(repository: repo);

      final result = await service.convertLabels('/labels', [2, -1]);

      expect(result.$1, 1);
      expect(result.$2, 2);
      final written = await repo.readLines(labelPath);
      expect(written, ['2 0.1 0.2 0.3 0.4']);
    });

    test('deleteClassFromLabels removes class and reports counts', () async {
      const labelPath = '/labels/h.txt';
      final repo = MemoryGadgetRepository(
        labelFiles: [labelPath],
        linesByPath: {
          labelPath: [
            '0 0.1 0.2 0.3 0.4',
            '1 0.1 0.2 0.3 0.4',
            '1 0.2 0.3 0.3 0.4',
          ],
        },
      );
      final service = GadgetService(repository: repo);

      final result = await service.deleteClassFromLabels('/labels', 1);

      expect(result, (1, 2));
      final written = await repo.readLines(labelPath);
      expect(written.length, 1);
      expect(written.first.startsWith('0 '), isTrue);
    });
  });
}
