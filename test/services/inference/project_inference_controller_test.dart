import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/models/ai_config.dart';
import 'package:label_load/models/label.dart';
import 'package:label_load/models/label_definition.dart';
import 'package:label_load/services/inference/inference_engine.dart';
import 'package:label_load/services/inference/project_inference_controller.dart';
import 'package:label_load/services/inference/inference_service.dart';
import 'package:label_load/services/gpu/gpu_info.dart';

class FakeRunner implements InferenceRunner {
  FakeRunner({
    this.failGpu = false,
    this.throwOnLoad = false,
    List<Label>? labels,
  }) : labelsToReturn = labels ?? [];

  bool failGpu;
  bool throwOnLoad;
  List<Label> labelsToReturn;
  int loadCalls = 0;

  @override
  bool hasModel = false;

  @override
  String? loadedModelPath;

  @override
  Future<bool> loadModel(String path, {bool useGpu = false}) async {
    loadCalls += 1;
    if (throwOnLoad) {
      throw Exception('load failed');
    }
    if (useGpu && failGpu) return false;
    loadedModelPath = path;
    hasModel = true;
    return true;
  }

  @override
  Future<List<Label>> runInference(
    String imagePath,
    AiConfig config,
    List<LabelDefinition> labelDefinitions,
  ) async {
    return labelsToReturn.map((l) => l.copyWith()).toList();
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

  bool hasModelValue = false;
  String? loadedPath;
  bool loadCalled = false;
  bool runCalled = false;

  @override
  bool get hasModel => hasModelValue;

  @override
  String? get loadedModelPath => loadedPath;

  @override
  Future<bool> loadModel(String path, {bool useGpu = false}) async {
    loadCalled = true;
    loadedPath = path;
    return true;
  }

  @override
  Future<List<Label>> runInference(
    String imagePath,
    AiConfig config,
    List<LabelDefinition> labelDefinitions,
  ) async {
    runCalled = true;
    return [Label(id: 1)];
  }
}

void main() {
  group('ProjectInferenceController', () {
    test('loadModel falls back to CPU when GPU fails', () async {
      final runner = FakeRunner(failGpu: true);
      final controller = ProjectInferenceController(runner: runner);

      final success = await controller.loadModel('model.onnx', useGpu: true);

      expect(success, isTrue);
      expect(runner.loadCalls, 2);
      expect(runner.loadedModelPath, 'model.onnx');
      expect(runner.hasModel, isTrue);
    });

    test('loadModel returns false when path is empty', () async {
      final runner = FakeRunner();
      final controller = ProjectInferenceController(runner: runner);

      final success = await controller.loadModel('', useGpu: true);

      expect(success, isFalse);
      expect(runner.loadCalls, 0);
    });

    test('loadModel handles exceptions and retries CPU', () async {
      final runner = FakeRunner(throwOnLoad: true);
      final controller = ProjectInferenceController(runner: runner);

      final success = await controller.loadModel('model.onnx', useGpu: true);

      expect(success, isFalse);
      expect(runner.loadCalls, 2);
    });

    test('exposes runner state', () {
      final runner = FakeRunner();
      runner.hasModel = true;
      runner.loadedModelPath = 'model.onnx';

      final controller = ProjectInferenceController(runner: runner);

      expect(controller.hasModel, isTrue);
      expect(controller.loadedModelPath, 'model.onnx');
    });

    test('InferenceServiceRunner delegates to service', () async {
      final service = StubInferenceService();
      service.hasModelValue = true;
      final runner = InferenceServiceRunner(service);

      expect(runner.hasModel, isTrue);
      expect(runner.loadedModelPath, isNull);

      final loaded = await runner.loadModel('model.onnx', useGpu: true);
      expect(loaded, isTrue);
      expect(service.loadCalled, isTrue);
      expect(runner.loadedModelPath, 'model.onnx');

      final labels = await runner.runInference(
        'img.png',
        AiConfig(modelPath: 'model.onnx'),
        const [],
      );
      expect(service.runCalled, isTrue);
      expect(labels.length, 1);
    });

    test('inferLabels applies classIdOffset only in append mode', () async {
      final runner = FakeRunner(labels: [
        Label(
          id: 0,
          points: [LabelPoint(x: 0.1, y: 0.2, visibility: 2)],
          extraData: ['x'],
        ),
      ]);
      final controller = ProjectInferenceController(runner: runner);

      final defsAppend = [
        LabelDefinition(
          classId: 1,
          name: 'class_1',
          color: const Color(0xFF000000),
          type: LabelType.box,
        ),
      ];
      final appendConfig = AiConfig(
        labelSaveMode: LabelSaveMode.append,
        classIdOffset: 1,
      );

      final appendLabels = await controller.inferLabels(
        imagePath: 'image.png',
        config: appendConfig,
        labelDefinitions: defsAppend,
      );

      expect(appendLabels.first.id, 1);
      expect(appendLabels.first.points, isEmpty);
      expect(appendLabels.first.extraData, isEmpty);

      final defsOverwrite = [
        LabelDefinition(
          classId: 0,
          name: 'class_0',
          color: const Color(0xFF000000),
          type: LabelType.box,
        ),
      ];
      final overwriteConfig = AiConfig(
        labelSaveMode: LabelSaveMode.overwrite,
        classIdOffset: 1,
      );

      final overwriteLabels = await controller.inferLabels(
        imagePath: 'image.png',
        config: overwriteConfig,
        labelDefinitions: defsOverwrite,
      );

      expect(overwriteLabels.first.id, 0);
      expect(overwriteLabels.first.points, isEmpty);
    });
  });
}
