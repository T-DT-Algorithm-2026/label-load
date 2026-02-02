import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:label_load/models/ai_config.dart';
import 'package:label_load/models/label_definition.dart';
import 'package:label_load/services/app/app_error.dart';
import 'package:label_load/services/gpu/gpu_info.dart';
import 'package:label_load/services/image/image_repository.dart';
import 'package:label_load/services/inference/inference_engine.dart';
import 'package:label_load/services/inference/inference_service.dart';

class FakeDetection {
  FakeDetection({
    required this.classId,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.keypoints = const [],
  });

  final int classId;
  final double x;
  final double y;
  final double width;
  final double height;
  final List<FakeKeypoint> keypoints;
}

class FakeKeypoint {
  FakeKeypoint(this.x, this.y, this.visibility);
  final double x;
  final double y;
  final double visibility;
}

class FakeInferenceEngine implements InferenceEngine {
  bool hasModelValue = true;
  bool initializeValue = true;
  bool loadModelValue = true;
  bool throwOnLoadModel = false;
  bool gpuAvailable = false;
  String providers = 'CPU';
  String error = '';
  int errorCode = 0;

  int loadCalls = 0;
  int unloadCalls = 0;
  int disposeCalls = 0;

  Iterable<dynamic> detectResult = const [];
  List<List<dynamic>> detectBatchResult = const [];

  @override
  bool get hasModel => hasModelValue;

  @override
  bool initialize() => initializeValue;

  @override
  bool loadModel(String path, {bool useGpu = false}) {
    loadCalls++;
    if (throwOnLoadModel) {
      throw StateError('load failed');
    }
    return loadModelValue;
  }

  @override
  void unloadModel() => unloadCalls++;

  @override
  Iterable<dynamic> detect(
    Uint8List rgbaBytes,
    int width,
    int height, {
    required double confThreshold,
    required double nmsThreshold,
    required ModelType modelType,
    required int numKeypoints,
  }) {
    return detectResult;
  }

  @override
  List<List<dynamic>> detectBatch(
    List<Uint8List> rgbaBytesList,
    List<(int, int)> sizes, {
    required double confThreshold,
    required double nmsThreshold,
    required ModelType modelType,
    required int numKeypoints,
  }) {
    return detectBatchResult;
  }

  @override
  bool isGpuAvailable() => gpuAvailable;

  @override
  GpuInfo getGpuInfo() => const GpuInfo(
        cudaAvailable: false,
        tensorrtAvailable: false,
        coremlAvailable: false,
        directmlAvailable: false,
        deviceName: 'Fake',
        cudaDeviceCount: 0,
      );

  @override
  String getAvailableProviders() => providers;

  @override
  String get lastError => error;

  @override
  int get lastErrorCode => errorCode;

  @override
  void dispose() => disposeCalls++;
}

class FakeImageRepository implements ImageRepository {
  final Map<String, Uint8List> files = {};

  @override
  Future<List<String>> listImagePaths(String directoryPath) async => [];

  @override
  Future<bool> exists(String path) async => files.containsKey(path);

  @override
  Future<Uint8List> readBytes(String path) async => files[path]!;

  @override
  Future<void> deleteIfExists(String path) async {}
}

Uint8List _pngBytes() {
  final image = img.Image(width: 1, height: 1);
  image.setPixel(0, 0, img.ColorUint8.rgb(255, 0, 0));
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('InferenceService initialize delegates to engine', () {
    final engine = FakeInferenceEngine()..initializeValue = true;
    final service = InferenceService(engine: engine);

    expect(service.initialize(), isTrue);
  });

  test('InferenceService uses engineFactory when engine not provided', () {
    final engine = FakeInferenceEngine()..initializeValue = true;
    final service = InferenceService(engineFactory: () => engine);

    expect(service.initialize(), isTrue);
  });

  test('InferenceService.instance returns preset instance', () {
    final engine = FakeInferenceEngine();
    final instance = InferenceService(engine: engine);

    InferenceService.setInstance(instance);
    final resolved = InferenceService.instance;

    expect(identical(resolved, instance), isTrue);
    InferenceService.resetInstance();
  });

  test('InferenceService exposes loading state', () {
    final engine = FakeInferenceEngine();
    final service = InferenceService(engine: engine);

    expect(service.isLoading, isFalse);
  });

  test('InferenceService allows swapping image repository in tests', () {
    final engine = FakeInferenceEngine();
    final service = InferenceService(engine: engine);
    final repo = FakeImageRepository();

    service.setImageRepository(repo);

    expect(
        service.runBatchInference(['/missing.png'], AiConfig(), []), completes);
  });

  test('InferenceService loadModel returns false when engine fails', () async {
    final engine = FakeInferenceEngine()
      ..loadModelValue = false
      ..errorCode = 12
      ..error = 'fail';
    final service = InferenceService(engine: engine);

    final result = await service.loadModel('/model.onnx');

    expect(result, isFalse);
    expect(service.loadedModelPath, isNull);
  });

  test('InferenceService loadModel reports error code when details missing',
      () async {
    final engine = FakeInferenceEngine()
      ..loadModelValue = false
      ..errorCode = 7
      ..error = '';
    final service = InferenceService(engine: engine);

    final result = await service.loadModel('/model.onnx');

    expect(result, isFalse);
  });

  test('InferenceService loadModel handles exceptions', () async {
    final engine = FakeInferenceEngine()..throwOnLoadModel = true;
    final service = InferenceService(engine: engine);

    final result = await service.loadModel('/model.onnx');

    expect(result, isFalse);
  });

  test('InferenceService skips reload for same model path', () async {
    final engine = FakeInferenceEngine()
      ..loadModelValue = true
      ..hasModelValue = true;
    final service = InferenceService(engine: engine);

    final first = await service.loadModel('/model.onnx');
    final second = await service.loadModel('/model.onnx');

    expect(first, isTrue);
    expect(second, isTrue);
    expect(engine.loadCalls, 1);
  });

  test('InferenceService unloads model and clears path', () async {
    final engine = FakeInferenceEngine()..hasModelValue = true;
    final service = InferenceService(engine: engine);

    await service.loadModel('/model.onnx');
    service.unloadModel();

    expect(engine.unloadCalls, 2);
    expect(service.loadedModelPath, isNull);
  });

  test('runInference throws when model not loaded', () async {
    final engine = FakeInferenceEngine()..hasModelValue = false;
    final service = InferenceService(engine: engine);

    expect(
      () => service.runInference('/x.png', AiConfig(), []),
      throwsA(isA<AppError>()
          .having((e) => e.code, 'code', AppErrorCode.aiModelNotLoaded)),
    );
  });

  test('runInference throws when image missing', () async {
    final engine = FakeInferenceEngine()..hasModelValue = true;
    final repo = FakeImageRepository();
    final service = InferenceService(engine: engine, imageRepository: repo);

    expect(
      () => service.runInference('/missing.png', AiConfig(), []),
      throwsA(isA<AppError>()
          .having((e) => e.code, 'code', AppErrorCode.imageFileNotFound)),
    );
  });

  test('runInference throws when decode fails', () async {
    final engine = FakeInferenceEngine()..hasModelValue = true;
    final repo = FakeImageRepository()
      ..files['/bad.png'] = Uint8List.fromList([1, 2, 3]);
    final service = InferenceService(engine: engine, imageRepository: repo);

    expect(
      () => service.runInference('/bad.png', AiConfig(), []),
      throwsA(isA<AppError>()
          .having((e) => e.code, 'code', AppErrorCode.imageDecodeFailed)),
    );
  });

  test('runInference maps detections to labels', () async {
    final engine = FakeInferenceEngine()..hasModelValue = true;
    engine.detectResult = [
      FakeDetection(
        classId: 1,
        x: 0.5,
        y: 0.5,
        width: 0.2,
        height: 0.3,
        keypoints: [FakeKeypoint(0.1, 0.2, 0.9)],
      ),
    ];
    final repo = FakeImageRepository()..files['/ok.png'] = _pngBytes();
    final service = InferenceService(engine: engine, imageRepository: repo);
    final defs = [
      LabelDefinition(classId: 1, name: 'cat', color: const Color(0xFF000000)),
    ];

    final labels = await service.runInference('/ok.png', AiConfig(), defs);

    expect(labels.length, 1);
    expect(labels[0].name, 'cat');
    expect(labels[0].points, isNotEmpty);
  });

  test('runInference throws when engine reports error code', () async {
    final engine = FakeInferenceEngine()
      ..hasModelValue = true
      ..errorCode = 99
      ..error = '';
    final repo = FakeImageRepository()..files['/ok.png'] = _pngBytes();
    final service = InferenceService(engine: engine, imageRepository: repo);

    expect(
      () => service.runInference('/ok.png', AiConfig(), []),
      throwsA(isA<AppError>()
          .having((e) => e.code, 'code', AppErrorCode.aiInferenceFailed)),
    );
  });

  test('runBatchInference returns empty lists for invalid images', () async {
    final engine = FakeInferenceEngine()..hasModelValue = true;
    final repo = FakeImageRepository();
    final service = InferenceService(engine: engine, imageRepository: repo);

    final results = await service.runBatchInference(
      ['/missing.png'],
      AiConfig(),
      [],
    );

    expect(results.length, 1);
    expect(results[0], isEmpty);
  });

  test('runBatchInference throws when model not loaded', () async {
    final engine = FakeInferenceEngine()..hasModelValue = false;
    final service = InferenceService(engine: engine);

    expect(
      () => service.runBatchInference(['/x.png'], AiConfig(), []),
      throwsA(isA<AppError>()
          .having((e) => e.code, 'code', AppErrorCode.aiModelNotLoaded)),
    );
  });

  test('runBatchInference maps results and preserves order', () async {
    final engine = FakeInferenceEngine()..hasModelValue = true;
    engine.detectBatchResult = [
      [
        FakeDetection(
          classId: 0,
          x: 0.1,
          y: 0.2,
          width: 0.3,
          height: 0.4,
        ),
      ],
    ];
    final repo = FakeImageRepository()..files['/a.png'] = _pngBytes();
    final service = InferenceService(engine: engine, imageRepository: repo);
    final defs = [
      LabelDefinition(classId: 0, name: 'dog', color: const Color(0xFF000000)),
    ];

    final results = await service.runBatchInference(
      ['/a.png', '/missing.png'],
      AiConfig(),
      defs,
    );

    expect(results.length, 2);
    expect(results[0].single.name, 'dog');
    expect(results[1], isEmpty);
  });

  test('InferenceService exposes GPU info and providers', () {
    final engine = FakeInferenceEngine()
      ..gpuAvailable = true
      ..providers = 'CUDA';
    final service = InferenceService(engine: engine);

    expect(service.isGpuAvailable(), isTrue);
    expect(service.getAvailableProviders(), 'CUDA');
    expect(service.getGpuInfo().deviceName, 'Fake');
  });

  test('InferenceService dispose unloads and disposes engine', () async {
    final engine = FakeInferenceEngine();
    final service = InferenceService(engine: engine);

    await service.loadModel('/model.onnx');
    service.dispose();

    expect(engine.unloadCalls, 2);
    expect(engine.disposeCalls, 1);
  });
}
