import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:label_load/models/ai_config.dart';
import 'package:label_load/models/label.dart';
import 'package:label_load/models/label_definition.dart';
import 'package:label_load/services/inference/batch_inference_service.dart';
import 'package:label_load/services/image/image_repository.dart';
import 'package:label_load/services/inference/inference_engine.dart';
import 'package:label_load/services/inference/inference_service.dart';
import 'package:label_load/services/labels/label_file_repository.dart';
import 'package:label_load/services/gpu/gpu_info.dart';

class FakeBatchRunner implements BatchInferenceRunner {
  FakeBatchRunner({
    required this.responses,
    this.loadResult = true,
    this.gpuAvailable = false,
    this.throwOnBatch = false,
  });

  final Map<String, List<Label>> responses;
  final bool loadResult;
  final bool gpuAvailable;
  final bool throwOnBatch;
  bool initialized = false;
  int batchCalls = 0;

  @override
  void initialize() {
    initialized = true;
  }

  @override
  bool isGpuAvailable() => gpuAvailable;

  @override
  Future<bool> loadModel(String path, {bool useGpu = false}) async {
    return loadResult;
  }

  @override
  Future<List<List<Label>>> runBatchInference(
    List<String> imagePaths,
    AiConfig config,
    List<LabelDefinition> labelDefinitions,
  ) async {
    batchCalls += 1;
    if (throwOnBatch) {
      throw Exception('batch failed');
    }
    return imagePaths.map((path) => responses[path] ?? <Label>[]).toList();
  }
}

class FakeImageRepository implements ImageRepository {
  FakeImageRepository(this.paths);

  final List<String> paths;

  @override
  Future<List<String>> listImagePaths(String directoryPath) async => paths;

  @override
  Future<bool> exists(String path) async => true;

  @override
  Future<Uint8List> readBytes(String path) async =>
      Uint8List.fromList([1, 2, 3]);

  @override
  Future<void> deleteIfExists(String path) async {}
}

class FakeLabelRepository implements LabelFileRepository {
  FakeLabelRepository({
    Set<String>? existingPaths,
    Map<String, List<Label>>? existingLabels,
  })  : _existingPaths = existingPaths ?? <String>{},
        _existingLabels = existingLabels ?? <String, List<Label>>{};

  final Set<String> _existingPaths;
  final Map<String, List<Label>> _existingLabels;
  final Map<String, List<Label>> writtenLabels = {};
  final Map<String, List<String>> writtenCorrupted = {};

  @override
  Future<void> ensureDirectory(String directoryPath) async {}

  @override
  Future<bool> exists(String path) async => _existingPaths.contains(path);

  @override
  Future<void> deleteIfExists(String path) async {}

  @override
  Future<(List<Label>, List<String>)> readLabels(
    String labelPath,
    String Function(int p1) getName, {
    List<LabelDefinition>? labelDefinitions,
  }) async {
    return (_existingLabels[labelPath] ?? <Label>[], <String>['bad']);
  }

  @override
  Future<void> writeLabels(
    String labelPath,
    List<Label> labels, {
    List<LabelDefinition>? labelDefinitions,
    List<String>? corruptedLines,
  }) async {
    writtenLabels[labelPath] = labels;
    writtenCorrupted[labelPath] = corruptedLines ?? <String>[];
  }
}

class _StubEngine implements InferenceEngine {
  @override
  bool get hasModel => false;

  @override
  bool initialize() => true;

  @override
  bool loadModel(String path, {bool useGpu = false}) => true;

  @override
  void unloadModel() {}

  @override
  Iterable<dynamic> detect(
    Uint8List rgbaBytes,
    int width,
    int height, {
    required double confThreshold,
    required double nmsThreshold,
    required ModelType modelType,
    required int numKeypoints,
  }) =>
      const [];

  @override
  List<List<dynamic>> detectBatch(
    List<Uint8List> rgbaBytesList,
    List<(int, int)> sizes, {
    required double confThreshold,
    required double nmsThreshold,
    required ModelType modelType,
    required int numKeypoints,
  }) =>
      const [];

  @override
  bool isGpuAvailable() => false;

  @override
  GpuInfo getGpuInfo() => const GpuInfo(
        cudaAvailable: false,
        tensorrtAvailable: false,
        coremlAvailable: false,
        directmlAvailable: false,
        deviceName: '',
        cudaDeviceCount: 0,
      );

  @override
  String getAvailableProviders() => '';

  @override
  String get lastError => '';

  @override
  int get lastErrorCode => 0;

  @override
  void dispose() {}
}

class StubInferenceService extends InferenceService {
  StubInferenceService() : super(engine: _StubEngine());

  bool initialized = false;
  bool loadCalled = false;
  bool batchCalled = false;

  @override
  bool initialize() {
    initialized = true;
    return true;
  }

  @override
  bool isGpuAvailable() => true;

  @override
  Future<bool> loadModel(String path, {bool useGpu = false}) async {
    loadCalled = true;
    return true;
  }

  @override
  Future<List<List<Label>>> runBatchInference(
    List<String> imagePaths,
    AiConfig config,
    List<LabelDefinition> labelDefinitions,
  ) async {
    batchCalled = true;
    return imagePaths.map((_) => <Label>[]).toList();
  }
}

void main() {
  group('BatchInferenceService', () {
    test('merges labels in append mode and applies classIdOffset', () async {
      final rootDir = await Directory.systemTemp.createTemp('batch_infer_');
      addTearDown(() => rootDir.delete(recursive: true));

      final imageDir = Directory(path.join(rootDir.path, 'images'));
      final labelDir = Directory(path.join(rootDir.path, 'labels'));
      await imageDir.create();
      await labelDir.create();

      final imagePath = path.join(imageDir.path, 'img1.jpg');
      await File(imagePath).writeAsString('x');

      final labelPath = path.join(labelDir.path, 'img1.txt');
      await File(labelPath)
          .writeAsString('0 0.500000 0.500000 0.200000 0.200000');

      final runner = FakeBatchRunner(
        responses: {
          imagePath: [
            Label(
              id: 0,
              x: 0.1,
              y: 0.2,
              width: 0.3,
              height: 0.4,
            ),
          ],
        },
      );

      final service = BatchInferenceService(runner: runner);
      final config = AiConfig(
        modelPath: 'model.onnx',
        labelSaveMode: LabelSaveMode.append,
        classIdOffset: 1,
      );
      final definitions = [
        LabelDefinition(
          classId: 0,
          name: 'class_0',
          color: const Color(0xFF000000),
          type: LabelType.box,
        ),
      ];

      List<LabelDefinition>? updatedDefinitions;
      final summary = await service.run(
        imageDir: imageDir.path,
        labelDir: labelDir.path,
        config: config,
        definitions: definitions,
        useGpu: false,
        onDefinitionsUpdated: (defs) => updatedDefinitions = defs,
      );

      final content = await File(labelPath).readAsString();
      final lines = content.trim().split('\n');

      expect(summary.modelLoaded, isTrue);
      expect(lines.length, 2);
      expect(lines.first.startsWith('0 '), isTrue);
      expect(lines.last.startsWith('1 '), isTrue);
      expect(updatedDefinitions, isNotNull);
      expect(updatedDefinitions!.length, 2);
    });

    test('sanitizes points for box definitions', () async {
      final rootDir = await Directory.systemTemp.createTemp('batch_infer_');
      addTearDown(() => rootDir.delete(recursive: true));

      final imageDir = Directory(path.join(rootDir.path, 'images'));
      final labelDir = Directory(path.join(rootDir.path, 'labels'));
      await imageDir.create();
      await labelDir.create();

      final imagePath = path.join(imageDir.path, 'img2.jpg');
      await File(imagePath).writeAsString('x');

      final runner = FakeBatchRunner(
        responses: {
          imagePath: [
            Label(
              id: 0,
              x: 0.1,
              y: 0.2,
              width: 0.3,
              height: 0.4,
              points: [LabelPoint(x: 0.2, y: 0.3, visibility: 2)],
              extraData: ['extra'],
            ),
          ],
        },
      );

      final service = BatchInferenceService(runner: runner);
      final config = AiConfig(
        modelPath: 'model.onnx',
        labelSaveMode: LabelSaveMode.overwrite,
      );
      final definitions = [
        LabelDefinition(
          classId: 0,
          name: 'class_0',
          color: const Color(0xFF000000),
          type: LabelType.box,
        ),
      ];

      final summary = await service.run(
        imageDir: imageDir.path,
        labelDir: labelDir.path,
        config: config,
        definitions: definitions,
        useGpu: false,
      );

      final labelPath = path.join(labelDir.path, 'img2.txt');
      final content = await File(labelPath).readAsString();
      final parts = content.trim().split(RegExp(r'\s+'));

      expect(summary.processedImages, 1);
      expect(parts.length, 5);
    });

    test('returns early when no images', () async {
      final runner = FakeBatchRunner(responses: {});
      final service = BatchInferenceService(
        runner: runner,
        imageRepository: FakeImageRepository([]),
      );

      final summary = await service.run(
        imageDir: '/images',
        labelDir: '/labels',
        config: AiConfig(modelPath: 'model.onnx'),
        definitions: const [],
        useGpu: false,
      );

      expect(summary.totalImages, 0);
      expect(summary.modelLoaded, isTrue);
      expect(runner.initialized, isFalse);
    });

    test('returns modelLoaded false when loadModel fails', () async {
      final runner = FakeBatchRunner(
        responses: {},
        loadResult: false,
      );
      final service = BatchInferenceService(
        runner: runner,
        imageRepository: FakeImageRepository(['/img/1.jpg']),
        labelRepository: FakeLabelRepository(),
      );

      final summary = await service.run(
        imageDir: '/images',
        labelDir: '/labels',
        config: AiConfig(modelPath: 'model.onnx'),
        definitions: const [],
        useGpu: false,
      );

      expect(summary.modelLoaded, isFalse);
      expect(summary.processedImages, 0);
    });

    test('stops when shouldContinue returns false', () async {
      final runner = FakeBatchRunner(responses: {
        '/img/1.jpg': [Label(id: 0)],
      });
      final service = BatchInferenceService(
        runner: runner,
        imageRepository: FakeImageRepository(['/img/1.jpg']),
        labelRepository: FakeLabelRepository(),
      );

      var called = false;
      final summary = await service.run(
        imageDir: '/images',
        labelDir: '/labels',
        config: AiConfig(modelPath: 'model.onnx'),
        definitions: const [],
        useGpu: false,
        shouldContinue: () {
          if (!called) {
            called = true;
            return false;
          }
          return false;
        },
      );

      expect(summary.processedImages, 0);
      expect(runner.batchCalls, 0);
    });

    test('counts failed batches when inference throws', () async {
      final runner = FakeBatchRunner(
        responses: const {},
        throwOnBatch: true,
      );
      final service = BatchInferenceService(
        runner: runner,
        imageRepository: FakeImageRepository(['/img/1.jpg']),
        labelRepository: FakeLabelRepository(),
      );

      final summary = await service.run(
        imageDir: '/images',
        labelDir: '/labels',
        config: AiConfig(modelPath: 'model.onnx'),
        definitions: const [],
        useGpu: false,
      );

      expect(summary.failedBatches, 1);
      expect(summary.lastError, isNotNull);
      expect(summary.processedImages, 0);
    });

    test('uses gpu batch size and fires callbacks', () async {
      final images = List.generate(33, (i) => '/img/$i.jpg');
      final runner = FakeBatchRunner(
        responses: {
          for (final path in images) path: [Label(id: 0)]
        },
        gpuAvailable: true,
      );
      final labelRepo = FakeLabelRepository();
      final service = BatchInferenceService(
        runner: runner,
        imageRepository: FakeImageRepository(images),
        labelRepository: labelRepo,
      );

      final inferred = <String>[];
      final summary = await service.run(
        imageDir: '/images',
        labelDir: '/labels',
        config: AiConfig(modelPath: 'model.onnx'),
        definitions: const [],
        useGpu: true,
        onInferredImage: inferred.add,
      );

      expect(summary.processedImages, 33);
      expect(inferred.length, 33);
      expect(runner.batchCalls, 2);
    });

    test('InferenceServiceBatchRunner delegates to service', () async {
      final service = StubInferenceService();
      final runner = InferenceServiceBatchRunner(service);

      runner.initialize();
      expect(service.initialized, isTrue);
      expect(runner.isGpuAvailable(), isTrue);

      final loaded = await runner.loadModel('model.onnx', useGpu: true);
      expect(loaded, isTrue);
      expect(service.loadCalled, isTrue);

      final result = await runner.runBatchInference(
        ['/img/1.jpg'],
        AiConfig(modelPath: 'model.onnx'),
        const [],
      );
      expect(result.length, 1);
      expect(service.batchCalled, isTrue);
    });

    test('onProgress receives start and end updates', () async {
      final runner = FakeBatchRunner(
        responses: {
          '/img/1.jpg': [Label(id: 0)],
          '/img/2.jpg': [Label(id: 0)],
        },
      );
      final service = BatchInferenceService(
        runner: runner,
        imageRepository: FakeImageRepository(['/img/1.jpg', '/img/2.jpg']),
        labelRepository: FakeLabelRepository(),
      );

      final progress = <(int, int)>[];
      await service.run(
        imageDir: '/images',
        labelDir: '/labels',
        config: AiConfig(modelPath: 'model.onnx'),
        definitions: const [],
        useGpu: false,
        onProgress: (current, total) => progress.add((current, total)),
      );

      expect(progress.first, (0, 2));
      expect(progress.any((p) => p.$1 == 1 && p.$2 == 2), isTrue);
      expect(progress.last, (2, 2));
    });
  });
}
