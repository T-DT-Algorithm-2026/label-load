import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/models/ai_config.dart';
import 'package:label_load/services/gpu/gpu_info.dart';
import 'package:label_load/services/inference/inference_engine.dart';
import 'package:onnx_inference/onnx_inference.dart' as onnx;

class FakeOnnxBackend implements OnnxBackend {
  bool hasModelValue = false;
  bool initializeValue = true;
  bool loadModelValue = true;
  bool gpuAvailable = false;
  String providers = 'CPU';
  String error = '';
  int errorCode = 0;
  onnx.GpuInfo gpuInfo = onnx.GpuInfo(
    cudaAvailable: false,
    tensorrtAvailable: false,
    coremlAvailable: false,
    directmlAvailable: false,
    deviceName: 'Fake',
    cudaDeviceCount: 0,
  );

  String? lastLoadPath;
  bool? lastLoadUseGpu;
  onnx.ModelType? lastModelType;
  onnx.ModelType? lastBatchModelType;
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
    lastLoadPath = path;
    lastLoadUseGpu = useGpu;
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
    required onnx.ModelType modelType,
    required int numKeypoints,
  }) {
    lastModelType = modelType;
    return detectResult;
  }

  @override
  List<List<dynamic>> detectBatch(
    List<Uint8List> rgbaBytesList,
    List<(int, int)> sizes, {
    required double confThreshold,
    required double nmsThreshold,
    required onnx.ModelType modelType,
    required int numKeypoints,
  }) {
    lastBatchModelType = modelType;
    return detectBatchResult;
  }

  @override
  bool isGpuAvailable() => gpuAvailable;

  @override
  onnx.GpuInfo getGpuInfo() => gpuInfo;

  @override
  String getAvailableProviders() => providers;

  @override
  String get lastError => error;

  @override
  int get lastErrorCode => errorCode;

  @override
  void dispose() => disposeCalls++;
}

class FakeOnnxInference implements onnx.OnnxInference {
  bool hasModelValue = false;
  bool initialized = true;
  bool loadResult = true;
  bool gpuAvailable = false;
  String versionValue = '1.0';
  String error = '';
  int errorCode = 0;
  String providers = 'CPU';
  onnx.GpuInfo gpuInfo = onnx.GpuInfo(
    cudaAvailable: false,
    tensorrtAvailable: false,
    coremlAvailable: false,
    directmlAvailable: false,
    deviceName: 'Fake',
    cudaDeviceCount: 0,
  );

  int unloadCalls = 0;
  int disposeCalls = 0;
  String? lastPath;
  bool? lastUseGpu;

  List<onnx.Detection> detectResult = const [];
  List<List<onnx.Detection>> detectBatchResult = const [];

  @override
  bool initialize() => initialized;

  @override
  void dispose() => disposeCalls++;

  @override
  bool loadModel(String modelPath, {bool useGpu = false}) {
    lastPath = modelPath;
    lastUseGpu = useGpu;
    return loadResult;
  }

  @override
  void unloadModel() => unloadCalls++;

  @override
  (int width, int height)? getInputSize() => (1, 1);

  @override
  List<onnx.Detection> detect(
    Uint8List imageData,
    int width,
    int height, {
    double confThreshold = 0.25,
    double nmsThreshold = 0.45,
    onnx.ModelType modelType = onnx.ModelType.yolo,
    int numKeypoints = 17,
  }) {
    return detectResult;
  }

  @override
  List<List<onnx.Detection>> detectBatch(
    List<Uint8List> imageDataList,
    List<(int, int)> sizes, {
    double confThreshold = 0.25,
    double nmsThreshold = 0.45,
    onnx.ModelType modelType = onnx.ModelType.yolo,
    int numKeypoints = 17,
  }) {
    return detectBatchResult;
  }

  @override
  String get version => versionValue;

  @override
  String get lastError => error;

  @override
  int get lastErrorCode => errorCode;

  @override
  bool get hasModel => hasModelValue;

  @override
  bool get isInitialized => initialized;

  @override
  bool isGpuAvailable() => gpuAvailable;

  @override
  onnx.GpuInfo getGpuInfo() => gpuInfo;

  @override
  String getAvailableProviders() => providers;
}

void main() {
  test('OnnxInferenceBackend delegates to OnnxInference', () {
    final engine = FakeOnnxInference();
    engine
      ..hasModelValue = true
      ..gpuAvailable = true
      ..error = 'oops'
      ..errorCode = 5
      ..gpuInfo = onnx.GpuInfo(
        cudaAvailable: true,
        tensorrtAvailable: false,
        coremlAvailable: false,
        directmlAvailable: false,
        deviceName: 'GPU',
        cudaDeviceCount: 1,
      );
    final backend = OnnxInferenceBackend(engine);

    backend.initialize();
    backend.loadModel('/model.onnx', useGpu: true);
    backend.detect(
      Uint8List(0),
      1,
      1,
      confThreshold: 0.2,
      nmsThreshold: 0.3,
      modelType: onnx.ModelType.yolo,
      numKeypoints: 0,
    );
    backend.detectBatch(
      [Uint8List(0)],
      [(1, 1)],
      confThreshold: 0.2,
      nmsThreshold: 0.3,
      modelType: onnx.ModelType.yoloPose,
      numKeypoints: 17,
    );
    backend.unloadModel();
    backend.dispose();

    expect(engine.lastPath, '/model.onnx');
    expect(engine.lastUseGpu, isTrue);
    expect(engine.unloadCalls, 1);
    expect(engine.disposeCalls, 1);
    expect(backend.getAvailableProviders(), 'CPU');
    expect(backend.hasModel, isTrue);
    expect(backend.isGpuAvailable(), isTrue);
    expect(backend.getGpuInfo().deviceName, 'GPU');
    expect(backend.lastError, 'oops');
    expect(backend.lastErrorCode, 5);
  });

  test('OnnxInferenceEngine supports engine injection', () {
    final fake = FakeOnnxInference()..gpuAvailable = true;
    final engine = OnnxInferenceEngine(engine: fake);

    expect(engine.hasModel, isFalse);
    expect(engine.isGpuAvailable(), isTrue);
  });

  test('OnnxInferenceEngine delegates to backend and converts model type', () {
    final backend = FakeOnnxBackend();
    final engine = OnnxInferenceEngine(backend: backend);

    engine.initialize();
    engine.loadModel('/model.onnx', useGpu: true);
    engine.detect(
      Uint8List(0),
      1,
      1,
      confThreshold: 0.5,
      nmsThreshold: 0.6,
      modelType: ModelType.yoloPose,
      numKeypoints: 17,
    );
    engine.detectBatch(
      [Uint8List(0)],
      [(1, 1)],
      confThreshold: 0.5,
      nmsThreshold: 0.6,
      modelType: ModelType.yolo,
      numKeypoints: 0,
    );
    engine.unloadModel();
    engine.dispose();

    expect(backend.lastLoadPath, '/model.onnx');
    expect(backend.lastLoadUseGpu, isTrue);
    expect(backend.lastModelType, onnx.ModelType.yoloPose);
    expect(backend.lastBatchModelType, onnx.ModelType.yolo);
    expect(backend.unloadCalls, 1);
    expect(backend.disposeCalls, 1);
  });

  test('OnnxInferenceEngine exposes error and provider info', () {
    final backend = FakeOnnxBackend()
      ..error = 'boom'
      ..errorCode = 12
      ..providers = 'CUDA';
    final engine = OnnxInferenceEngine(backend: backend);

    expect(engine.lastError, 'boom');
    expect(engine.lastErrorCode, 12);
    expect(engine.getAvailableProviders(), 'CUDA');
  });

  test('OnnxInferenceEngine converts GPU info', () {
    final backend = FakeOnnxBackend()
      ..gpuInfo = onnx.GpuInfo(
        cudaAvailable: true,
        tensorrtAvailable: false,
        coremlAvailable: true,
        directmlAvailable: false,
        deviceName: 'GPU',
        cudaDeviceCount: 2,
      );
    final engine = OnnxInferenceEngine(backend: backend);

    final info = engine.getGpuInfo();

    expect(info, isA<GpuInfo>());
    expect(info.cudaAvailable, isTrue);
    expect(info.coremlAvailable, isTrue);
    expect(info.deviceName, 'GPU');
    expect(info.cudaDeviceCount, 2);
  });
}
