import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/services/files/file_picker_service.dart';

class FakeFilePicker extends FilePicker {
  String? lastDialogTitle;
  String? lastFileName;
  FileType? lastType;
  List<String>? lastAllowedExtensions;

  String? directoryResult;
  String? saveResult;
  FilePickerResult? pickResult;

  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    bool lockParentWindow = false,
    String? initialDirectory,
  }) async {
    lastDialogTitle = dialogTitle;
    lastType = null;
    lastAllowedExtensions = null;
    return directoryResult;
  }

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async {
    lastDialogTitle = dialogTitle;
    lastFileName = fileName;
    lastType = type;
    lastAllowedExtensions = allowedExtensions;
    return saveResult;
  }

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    lastDialogTitle = dialogTitle;
    lastType = type;
    lastAllowedExtensions = allowedExtensions;
    return pickResult;
  }
}

void main() {
  late FakeFilePicker fake;
  FilePicker? previous;

  setUp(() {
    fake = FakeFilePicker();
    try {
      previous = FilePicker.platform;
    } catch (_) {
      previous = null;
    }
    FilePicker.platform = fake;
  });

  tearDown(() {
    if (previous != null) {
      FilePicker.platform = previous!;
    }
  });

  test('PlatformFilePickerService delegates getDirectoryPath', () async {
    fake.directoryResult = '/tmp';
    const service = PlatformFilePickerService();

    final result = await service.getDirectoryPath();

    expect(result, '/tmp');
    expect(fake.lastDialogTitle, isNull);
  });

  test('PlatformFilePickerService saveFile uses custom type when extensions',
      () async {
    fake.saveResult = '/tmp/file.json';
    const service = PlatformFilePickerService();

    final result = await service.saveFile(
      dialogTitle: 'save',
      fileName: 'file.json',
      allowedExtensions: ['json'],
    );

    expect(result, '/tmp/file.json');
    expect(fake.lastType, FileType.custom);
    expect(fake.lastAllowedExtensions, ['json']);
    expect(fake.lastFileName, 'file.json');
  });

  test('PlatformFilePickerService saveFile uses any type when no extensions',
      () async {
    fake.saveResult = '/tmp/file.any';
    const service = PlatformFilePickerService();

    await service.saveFile(dialogTitle: 'save');

    expect(fake.lastType, FileType.any);
    expect(fake.lastAllowedExtensions, isNull);
  });

  test('PlatformFilePickerService pickFile returns selected path', () async {
    fake.pickResult = FilePickerResult([
      PlatformFile(name: 'a.txt', size: 1, path: '/tmp/a.txt'),
    ]);
    const service = PlatformFilePickerService();

    final result = await service.pickFile(
      dialogTitle: 'pick',
      allowedExtensions: ['txt'],
    );

    expect(result, '/tmp/a.txt');
    expect(fake.lastType, FileType.custom);
    expect(fake.lastAllowedExtensions, ['txt']);
  });

  test('PlatformFilePickerService pickFile returns null when cancelled',
      () async {
    fake.pickResult = null;
    const service = PlatformFilePickerService();

    final result = await service.pickFile();

    expect(result, isNull);
    expect(fake.lastType, FileType.any);
  });
}
