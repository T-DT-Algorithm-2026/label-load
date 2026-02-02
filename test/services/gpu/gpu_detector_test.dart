import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/models/ai_config.dart';
import 'package:label_load/services/gpu/gpu_detector.dart';
import 'package:label_load/services/gpu/gpu_info.dart';
import 'package:label_load/services/inference/inference_engine.dart';

class FakeInferenceEngine implements InferenceEngine {
  FakeInferenceEngine({
    required this.available,
    required this.info,
    required this.providers,
  });

  final bool available;
  final GpuInfo info;
  final String providers;
  bool initializeCalled = false;

  @override
  bool get hasModel => false;

  @override
  bool initialize() {
    initializeCalled = true;
    return true;
  }

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
  bool isGpuAvailable() => available;

  @override
  GpuInfo getGpuInfo() => info;

  @override
  String getAvailableProviders() => providers;

  @override
  String get lastError => '';

  @override
  int get lastErrorCode => 0;

  @override
  void dispose() {}
}

void main() {
  test('OnnxGpuDetector uses injected engine', () async {
    const info = GpuInfo(
      cudaAvailable: true,
      tensorrtAvailable: false,
      coremlAvailable: false,
      directmlAvailable: false,
      deviceName: 'FakeGPU',
      cudaDeviceCount: 1,
    );
    final engine = FakeInferenceEngine(
      available: true,
      info: info,
      providers: 'CUDAExecutionProvider',
    );
    final detector = OnnxGpuDetector(engine: engine);

    final result = await detector.detect();

    expect(result.available, isTrue);
    expect(result.info?.deviceName, 'FakeGPU');
    expect(result.providers, 'CUDAExecutionProvider');
    expect(engine.initializeCalled, isTrue);
  });

  test('OnnxGpuDetector uses engineFactory when provided', () async {
    final engine = FakeInferenceEngine(
      available: false,
      info: const GpuInfo(
        cudaAvailable: false,
        tensorrtAvailable: false,
        coremlAvailable: false,
        directmlAvailable: false,
        deviceName: 'CPU',
        cudaDeviceCount: 0,
      ),
      providers: 'CPUExecutionProvider',
    );

    final detector = OnnxGpuDetector(engineFactory: () => engine);
    final result = await detector.detect();

    expect(result.available, isFalse);
    expect(result.providers, 'CPUExecutionProvider');
  });
}
