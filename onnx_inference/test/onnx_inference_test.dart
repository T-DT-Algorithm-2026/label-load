import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onnx_inference/onnx_inference.dart';

/// Fake native API that simulates ONNX Runtime bindings for tests.
class _FakeNativeApi {
  _FakeNativeApi() {
    _gpuInfoPtr = calloc<NativeGpuInfo>();
    _gpuInfoPtr.ref
      ..cudaAvailable = true
      ..tensorrtAvailable = false
      ..coremlAvailable = false
      ..directmlAvailable = false
      ..cudaDeviceCount = 1;
    const name = 'Fake CUDA GPU';
    final bytes = name.codeUnits;
    for (var i = 0; i < bytes.length; i++) {
      _gpuInfoPtr.ref.deviceName[i] = bytes[i];
    }
    _gpuInfoPtr.ref.deviceName[bytes.length] = 0;
  }

  int initCalls = 0;
  int cleanupCalls = 0;
  int unloadCalls = 0;
  int freeResultCalls = 0;
  int freeBatchResultCalls = 0;
  int detectCalls = 0;
  int detectBatchCalls = 0;
  int gpuAvailableCalls = 0;

  String? lastModelPath;
  bool? lastUseGpu;
  Pointer<Void>? lastHandle;

  late final Pointer<NativeGpuInfo> _gpuInfoPtr;
  final Pointer<Utf8> _versionPtr = '2.0.0-test'.toNativeUtf8();
  final Pointer<Utf8> _providersPtr =
      'CPUExecutionProvider,CUDAExecutionProvider'.toNativeUtf8();
  final Pointer<Utf8> _lastErrorPtr = 'no error'.toNativeUtf8();

  /// Releases native allocations used by the fake API.
  void dispose() {
    calloc.free(_gpuInfoPtr);
    calloc.free(_versionPtr);
    calloc.free(_providersPtr);
    calloc.free(_lastErrorPtr);
  }

  bool init() {
    initCalls += 1;
    return true;
  }

  void cleanup() {
    cleanupCalls += 1;
  }

  Pointer<Void> loadModel(Pointer<Utf8> modelPath, bool useGpu) {
    lastModelPath = modelPath.toDartString();
    lastUseGpu = useGpu;
    return Pointer<Void>.fromAddress(0x1);
  }

  void unloadModel(Pointer<Void> handle) {
    unloadCalls += 1;
    lastHandle = handle;
  }

  bool getInputSize(
    Pointer<Void> handle,
    Pointer<Int32> width,
    Pointer<Int32> height,
  ) {
    width.value = 640;
    height.value = 640;
    return true;
  }

  Pointer<NativeDetectionResult> detect(
    Pointer<Void> handle,
    Pointer<Uint8> imageData,
    int imageWidth,
    int imageHeight,
    double confThreshold,
    double nmsThreshold,
    int modelType,
    int numKeypoints,
  ) {
    detectCalls += 1;
    return _buildSingleResult();
  }

  Pointer<NativeBatchDetectionResult> detectBatch(
    Pointer<Void> handle,
    Pointer<Pointer<Uint8>> imageDataList,
    int numImages,
    Pointer<Int32> imageWidths,
    Pointer<Int32> imageHeights,
    double confThreshold,
    double nmsThreshold,
    int modelType,
    int numKeypoints,
  ) {
    detectBatchCalls += 1;
    return _buildBatchResult(numImages);
  }

  void freeResult(Pointer<NativeDetectionResult> result) {
    freeResultCalls += 1;
    _releaseDetectionResult(result);
  }

  void freeBatchResult(Pointer<NativeBatchDetectionResult> result) {
    freeBatchResultCalls += 1;
    _releaseBatchResult(result);
  }

  Pointer<Utf8> getVersion() => _versionPtr;

  bool isGpuAvailable() {
    gpuAvailableCalls += 1;
    return true;
  }

  NativeGpuInfo getGpuInfo() {
    return _gpuInfoPtr.ref;
  }

  Pointer<Utf8> getAvailableProviders() => _providersPtr;

  Pointer<Utf8> getLastError() => _lastErrorPtr;

  int getLastErrorCode() => 42;

  /// Builds a detection result with keypoints for test coverage.
  Pointer<NativeDetectionResult> _buildSingleResult() {
    final resultPtr = calloc<NativeDetectionResult>();
    final detPtr = calloc<NativeDetection>(2);

    detPtr[0]
      ..classId = 1
      ..confidence = 0.9
      ..x = 0.25
      ..y = 0.3
      ..width = 0.5
      ..height = 0.4
      ..numKeypoints = 2;
    final kptPtr = calloc<Float>(6);
    kptPtr[0] = 0.1;
    kptPtr[1] = 0.2;
    kptPtr[2] = 0.9;
    kptPtr[3] = 0.3;
    kptPtr[4] = 0.4;
    kptPtr[5] = 0.8;
    detPtr[0].keypoints = kptPtr;

    detPtr[1]
      ..classId = 2
      ..confidence = 0.7
      ..x = 0.6
      ..y = 0.7
      ..width = 0.2
      ..height = 0.1
      ..numKeypoints = 0
      ..keypoints = Pointer<Float>.fromAddress(0);

    resultPtr.ref
      ..detections = detPtr
      ..count = 2
      ..capacity = 2;
    return resultPtr;
  }

  /// Builds a batch result with per-image detections.
  Pointer<NativeBatchDetectionResult> _buildBatchResult(int numImages) {
    final batchPtr = calloc<NativeBatchDetectionResult>();
    final resultsPtr = calloc<NativeDetectionResult>(numImages);

    for (var i = 0; i < numImages; i++) {
      final detPtr = calloc<NativeDetection>(1);
      detPtr[0]
        ..classId = i
        ..confidence = 0.5 + i * 0.1
        ..x = 0.1 * (i + 1)
        ..y = 0.2 * (i + 1)
        ..width = 0.3
        ..height = 0.4;

      if (i == 0) {
        detPtr[0].numKeypoints = 1;
        final kptPtr = calloc<Float>(3);
        kptPtr[0] = 0.2;
        kptPtr[1] = 0.3;
        kptPtr[2] = 0.9;
        detPtr[0].keypoints = kptPtr;
      } else {
        detPtr[0]
          ..numKeypoints = 0
          ..keypoints = Pointer<Float>.fromAddress(0);
      }

      resultsPtr[i]
        ..detections = detPtr
        ..count = 1
        ..capacity = 1;
    }

    batchPtr.ref
      ..results = resultsPtr
      ..numImages = numImages;
    return batchPtr;
  }

  /// Frees a single detection result tree.
  void _releaseDetectionResult(Pointer<NativeDetectionResult> result) {
    final count = result.ref.count;
    final detections = result.ref.detections;
    for (var i = 0; i < count; i++) {
      final det = detections[i];
      if (det.keypoints.address != 0) {
        calloc.free(det.keypoints);
      }
    }
    if (detections.address != 0) {
      calloc.free(detections);
    }
    calloc.free(result);
  }

  /// Frees a batch detection result tree.
  void _releaseBatchResult(Pointer<NativeBatchDetectionResult> result) {
    final results = result.ref.results;
    for (var i = 0; i < result.ref.numImages; i++) {
      final detResult = results[i];
      if (detResult.detections.address != 0) {
        for (var k = 0; k < detResult.count; k++) {
          final det = detResult.detections[k];
          if (det.keypoints.address != 0) {
            calloc.free(det.keypoints);
          }
        }
        calloc.free(detResult.detections);
      }
    }
    if (results.address != 0) {
      calloc.free(results);
    }
    calloc.free(result);
  }
}

/// Builds bindings backed by the fake native API.
OnnxBindings _buildBindings(_FakeNativeApi fake) {
  return OnnxBindings(
    init: fake.init,
    cleanup: fake.cleanup,
    loadModel: fake.loadModel,
    unloadModel: fake.unloadModel,
    getInputSize: fake.getInputSize,
    detect: fake.detect,
    detectBatch: fake.detectBatch,
    freeResult: fake.freeResult,
    freeBatchResult: fake.freeBatchResult,
    getVersion: fake.getVersion,
    isGpuAvailable: fake.isGpuAvailable,
    getGpuInfo: fake.getGpuInfo,
    getAvailableProviders: fake.getAvailableProviders,
    getLastError: fake.getLastError,
    getLastErrorCode: fake.getLastErrorCode,
  );
}

/// Constructs a test engine using injected bindings.
OnnxInference _buildTestEngine(_FakeNativeApi fake) {
  return OnnxInference.forTesting(_buildBindings(fake));
}

void main() {
  test('data classes format string output and GPU availability', () {
    final keypoint = Keypoint(x: 0.1, y: 0.2, visibility: 0.9);
    expect(keypoint.toString(), contains('Keypoint'));

    final detection = Detection(
      classId: 1,
      confidence: 0.8,
      x: 0.3,
      y: 0.4,
      width: 0.5,
      height: 0.6,
      keypoints: [keypoint],
    );
    expect(detection.toString(), contains('kpts=1'));

    final gpuInfo = GpuInfo(
      cudaAvailable: false,
      tensorrtAvailable: true,
      coremlAvailable: false,
      directmlAvailable: false,
      deviceName: 'Test GPU',
      cudaDeviceCount: 0,
    );
    expect(gpuInfo.isGpuAvailable, isTrue);
    expect(gpuInfo.toString(), contains('Test GPU'));
  });

  test('OnnxBindings.fromLookup wires symbols consistently', () {
    final fake = _FakeNativeApi();
    addTearDown(fake.dispose);

    final lookupMap = <String, Function>{
      'onnx_init': fake.init,
      'onnx_cleanup': fake.cleanup,
      'onnx_load_model': fake.loadModel,
      'onnx_unload_model': fake.unloadModel,
      'onnx_get_input_size': fake.getInputSize,
      'onnx_detect': fake.detect,
      'onnx_detect_batch': fake.detectBatch,
      'onnx_free_result': fake.freeResult,
      'onnx_free_batch_result': fake.freeBatchResult,
      'onnx_get_version': fake.getVersion,
      'onnx_is_gpu_available': fake.isGpuAvailable,
      'onnx_get_gpu_info': fake.getGpuInfo,
      'onnx_get_available_providers': fake.getAvailableProviders,
      'onnx_get_last_error': fake.getLastError,
      'onnx_get_last_error_code': fake.getLastErrorCode,
    };

    // Simple lookup shim matching FFI symbol resolver signature.
    T lookup<S extends Function, T extends Function>(String symbolName) {
      final fn = lookupMap[symbolName];
      if (fn == null) {
        throw ArgumentError('Unknown symbol $symbolName');
      }
      return fn as T;
    }

    final bindings = OnnxBindings.fromLookup(lookup);
    final engine = OnnxInference.forTesting(bindings);

    expect(engine.loadModel('/tmp/model.onnx'), isTrue);
    expect(engine.version, '2.0.0-test');
  });

  test('OnnxInference loads model and reads metadata', () {
    final fake = _FakeNativeApi();
    addTearDown(fake.dispose);

    final engine = _buildTestEngine(fake);
    expect(engine.isInitialized, isFalse);

    final loaded = engine.loadModel('/tmp/model.onnx', useGpu: true);
    expect(loaded, isTrue);
    expect(engine.isInitialized, isTrue);
    expect(fake.lastModelPath, '/tmp/model.onnx');
    expect(fake.lastUseGpu, isTrue);
    expect(engine.hasModel, isTrue);

    final size = engine.getInputSize();
    expect(size, isNotNull);
    expect(size!.$1, 640);
    expect(size.$2, 640);

    expect(engine.version, '2.0.0-test');
    expect(engine.lastError, 'no error');
    expect(engine.lastErrorCode, 42);

    engine.unloadModel();
    expect(engine.hasModel, isFalse);
    expect(fake.unloadCalls, 1);

    engine.dispose();
    expect(engine.isInitialized, isFalse);
    expect(fake.cleanupCalls, 1);
  });

  test('getInputSize returns null before model is loaded', () {
    final fake = _FakeNativeApi();
    addTearDown(fake.dispose);

    final engine = _buildTestEngine(fake);
    expect(engine.getInputSize(), isNull);
  });

  test('loadModel fails when initialization fails', () {
    final fake = _FakeNativeApi();
    addTearDown(fake.dispose);

    var loadCalls = 0;
    final bindings = OnnxBindings(
      init: () => false,
      cleanup: fake.cleanup,
      loadModel: (path, useGpu) {
        loadCalls += 1;
        return Pointer<Void>.fromAddress(0x1);
      },
      unloadModel: fake.unloadModel,
      getInputSize: fake.getInputSize,
      detect: fake.detect,
      detectBatch: fake.detectBatch,
      freeResult: fake.freeResult,
      freeBatchResult: fake.freeBatchResult,
      getVersion: fake.getVersion,
      isGpuAvailable: fake.isGpuAvailable,
      getGpuInfo: fake.getGpuInfo,
      getAvailableProviders: fake.getAvailableProviders,
      getLastError: fake.getLastError,
      getLastErrorCode: fake.getLastErrorCode,
    );

    final engine = OnnxInference.forTesting(bindings);
    expect(engine.loadModel('/tmp/model.onnx'), isFalse);
    expect(loadCalls, 0);
  });

  test('detect returns parsed detections and frees native buffers', () {
    final fake = _FakeNativeApi();
    addTearDown(fake.dispose);

    final engine = _buildTestEngine(fake);
    engine.loadModel('/tmp/model.onnx');

    final image = Uint8List.fromList(List.filled(4 * 4 * 4, 255));
    final detections = engine.detect(image, 4, 4);

    expect(fake.detectCalls, 1);
    expect(fake.freeResultCalls, 1);
    expect(detections.length, 2);
    expect(detections.first.classId, 1);
    expect(detections.first.keypoints, isNotNull);
    expect(detections.first.keypoints!.length, 2);
  });

  test('detect skips work when no model is loaded', () {
    final fake = _FakeNativeApi();
    addTearDown(fake.dispose);

    final engine = _buildTestEngine(fake);
    final detections = engine.detect(Uint8List(4), 1, 1);
    expect(detections, isEmpty);
    expect(fake.detectCalls, 0);
  });

  test('detect returns empty when native returns null', () {
    final fake = _FakeNativeApi();
    addTearDown(fake.dispose);

    final base = _buildBindings(fake);
    final bindings = OnnxBindings(
      init: base.init,
      cleanup: base.cleanup,
      loadModel: base.loadModel,
      unloadModel: base.unloadModel,
      getInputSize: base.getInputSize,
      detect: (_, __, ___, ____, _____, ______, _______, ________) =>
          Pointer<NativeDetectionResult>.fromAddress(0),
      detectBatch: base.detectBatch,
      freeResult: base.freeResult,
      freeBatchResult: base.freeBatchResult,
      getVersion: base.getVersion,
      isGpuAvailable: base.isGpuAvailable,
      getGpuInfo: base.getGpuInfo,
      getAvailableProviders: base.getAvailableProviders,
      getLastError: base.getLastError,
      getLastErrorCode: base.getLastErrorCode,
    );

    final engine = OnnxInference.forTesting(bindings);
    engine.loadModel('/tmp/model.onnx');

    final detections = engine.detect(Uint8List(4), 1, 1);
    expect(detections, isEmpty);
    expect(fake.freeResultCalls, 0);
  });

  test('detectBatch validates sizes and returns batch results', () {
    final fake = _FakeNativeApi();
    addTearDown(fake.dispose);

    final engine = _buildTestEngine(fake);
    engine.loadModel('/tmp/model.onnx');

    final emptyBatch = engine.detectBatch(const [], const []);
    expect(emptyBatch, isEmpty);
    expect(fake.detectBatchCalls, 0);

    expect(
      () => engine.detectBatch([Uint8List(4)], [(1, 1), (2, 2)]),
      throwsArgumentError,
    );

    final batch = engine.detectBatch(
      [Uint8List(4), Uint8List(4)],
      [(1, 1), (2, 2)],
    );

    expect(fake.detectBatchCalls, 1);
    expect(fake.freeBatchResultCalls, 1);
    expect(batch.length, 2);
    expect(batch.first.single.classId, 0);
    expect(batch.first.single.keypoints, isNotNull);
    expect(batch.first.single.keypoints!.length, 1);
    expect(batch.last.single.classId, 1);
  });

  test('detectBatch returns empty when native returns null', () {
    final fake = _FakeNativeApi();
    addTearDown(fake.dispose);

    final base = _buildBindings(fake);
    final bindings = OnnxBindings(
      init: base.init,
      cleanup: base.cleanup,
      loadModel: base.loadModel,
      unloadModel: base.unloadModel,
      getInputSize: base.getInputSize,
      detect: base.detect,
      detectBatch: (_, __, ___, ____, _____, ______, _______, ________, _________) =>
          Pointer<NativeBatchDetectionResult>.fromAddress(0),
      freeResult: base.freeResult,
      freeBatchResult: base.freeBatchResult,
      getVersion: base.getVersion,
      isGpuAvailable: base.isGpuAvailable,
      getGpuInfo: base.getGpuInfo,
      getAvailableProviders: base.getAvailableProviders,
      getLastError: base.getLastError,
      getLastErrorCode: base.getLastErrorCode,
    );

    final engine = OnnxInference.forTesting(bindings);
    engine.loadModel('/tmp/model.onnx');

    final batch = engine.detectBatch([Uint8List(4)], [(1, 1)]);
    expect(batch.single, isEmpty);
    expect(fake.freeBatchResultCalls, 0);
  });

  test('GPU helpers return safe defaults on errors', () {
    final fake = _FakeNativeApi();
    addTearDown(fake.dispose);

    final base = _buildBindings(fake);
    final bindings = OnnxBindings(
      init: base.init,
      cleanup: base.cleanup,
      loadModel: base.loadModel,
      unloadModel: base.unloadModel,
      getInputSize: base.getInputSize,
      detect: base.detect,
      detectBatch: base.detectBatch,
      freeResult: base.freeResult,
      freeBatchResult: base.freeBatchResult,
      getVersion: base.getVersion,
      isGpuAvailable: () => throw StateError('boom'),
      getGpuInfo: () => throw StateError('boom'),
      getAvailableProviders: () => throw StateError('boom'),
      getLastError: base.getLastError,
      getLastErrorCode: base.getLastErrorCode,
    );

    final engine = OnnxInference.forTesting(bindings);
    expect(engine.isGpuAvailable(), isFalse);
    expect(engine.getGpuInfo().deviceName, '检测 GPU 时出错');
    expect(engine.getAvailableProviders(), 'CPUExecutionProvider');
  });

  test('GPU helpers return formatted information', () {
    final fake = _FakeNativeApi();
    addTearDown(fake.dispose);

    final bindings = _buildBindings(fake);
    final engine = OnnxInference.forTesting(bindings);

    expect(engine.isGpuAvailable(), isTrue);
    expect(fake.gpuAvailableCalls, 1);
    final info = engine.getGpuInfo();
    expect(info.cudaAvailable, isTrue);
    expect(info.deviceName, 'Fake CUDA GPU');
    expect(engine.getAvailableProviders(),
        'CPUExecutionProvider,CUDAExecutionProvider');
  });
}
