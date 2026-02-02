import 'package:flutter/foundation.dart';
import 'package:onnx_inference/onnx_inference.dart' as onnx;
import '../../models/ai_config.dart';
import '../gpu/gpu_info.dart';

/// 推理引擎接口
///
/// 统一模型加载、推理与 GPU 能力查询，便于替换实现。
abstract class InferenceEngine {
  /// 是否已加载模型。
  bool get hasModel;

  /// 初始化引擎，返回是否成功。
  bool initialize();

  /// 加载模型，返回是否成功。
  bool loadModel(String path, {bool useGpu = false});

  /// 卸载当前模型。
  void unloadModel();

  /// 单张图像推理。
  Iterable<dynamic> detect(
    Uint8List rgbaBytes,
    int width,
    int height, {
    required double confThreshold,
    required double nmsThreshold,
    required ModelType modelType,
    required int numKeypoints,
  });

  /// 批量推理。
  List<List<dynamic>> detectBatch(
    List<Uint8List> rgbaBytesList,
    List<(int, int)> sizes, {
    required double confThreshold,
    required double nmsThreshold,
    required ModelType modelType,
    required int numKeypoints,
  });

  /// GPU 是否可用。
  bool isGpuAvailable();

  /// 获取 GPU 信息。
  GpuInfo getGpuInfo();

  /// 获取可用推理提供者。
  String getAvailableProviders();

  /// 最近一次错误信息。
  String get lastError;

  /// 最近一次错误码。
  int get lastErrorCode;

  /// 释放引擎资源。
  void dispose();
}

/// ONNX 推理后端适配器
///
/// 通过抽象层隔离原生库，便于单元测试。
@visibleForTesting
abstract class OnnxBackend {
  bool get hasModel;
  bool initialize();
  bool loadModel(String path, {bool useGpu = false});
  void unloadModel();
  Iterable<dynamic> detect(
    Uint8List rgbaBytes,
    int width,
    int height, {
    required double confThreshold,
    required double nmsThreshold,
    required onnx.ModelType modelType,
    required int numKeypoints,
  });
  List<List<dynamic>> detectBatch(
    List<Uint8List> rgbaBytesList,
    List<(int, int)> sizes, {
    required double confThreshold,
    required double nmsThreshold,
    required onnx.ModelType modelType,
    required int numKeypoints,
  });
  bool isGpuAvailable();
  onnx.GpuInfo getGpuInfo();
  String getAvailableProviders();
  String get lastError;
  int get lastErrorCode;
  void dispose();
}

/// ONNX 推理后端的默认适配器实现。
///
/// 将 Dart 侧接口转发给 onnx_inference 包的单例引擎。
class OnnxInferenceBackend implements OnnxBackend {
  OnnxInferenceBackend(this._engine);

  final onnx.OnnxInference _engine;

  @override
  bool get hasModel => _engine.hasModel;

  @override
  bool initialize() => _engine.initialize();

  @override
  bool loadModel(String path, {bool useGpu = false}) {
    return _engine.loadModel(path, useGpu: useGpu);
  }

  @override
  void unloadModel() => _engine.unloadModel();

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
    return _engine.detect(
      rgbaBytes,
      width,
      height,
      confThreshold: confThreshold,
      nmsThreshold: nmsThreshold,
      modelType: modelType,
      numKeypoints: numKeypoints,
    );
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
    return _engine.detectBatch(
      rgbaBytesList,
      sizes,
      confThreshold: confThreshold,
      nmsThreshold: nmsThreshold,
      modelType: modelType,
      numKeypoints: numKeypoints,
    );
  }

  @override
  bool isGpuAvailable() => _engine.isGpuAvailable();

  @override
  onnx.GpuInfo getGpuInfo() => _engine.getGpuInfo();

  @override
  String getAvailableProviders() => _engine.getAvailableProviders();

  @override
  String get lastError => _engine.lastError;

  @override
  int get lastErrorCode => _engine.lastErrorCode;

  @override
  void dispose() => _engine.dispose();
}

/// ONNX 推理引擎实现。
///
/// 默认使用单例 [instance] 复用底层原生资源。
class OnnxInferenceEngine implements InferenceEngine {
  OnnxInferenceEngine({onnx.OnnxInference? engine, OnnxBackend? backend})
      : _backend = backend ??
            OnnxInferenceBackend(engine ?? onnx.OnnxInference.instance);

  /// 共享的推理引擎实例。
  static final OnnxInferenceEngine instance = OnnxInferenceEngine();

  final OnnxBackend _backend;

  @override
  bool get hasModel => _backend.hasModel;

  @override
  bool initialize() => _backend.initialize();

  @override
  bool loadModel(String path, {bool useGpu = false}) {
    return _backend.loadModel(path, useGpu: useGpu);
  }

  @override
  void unloadModel() => _backend.unloadModel();

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
    return _backend.detect(
      rgbaBytes,
      width,
      height,
      confThreshold: confThreshold,
      nmsThreshold: nmsThreshold,
      modelType: _convertModelType(modelType),
      numKeypoints: numKeypoints,
    );
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
    return _backend.detectBatch(
      rgbaBytesList,
      sizes,
      confThreshold: confThreshold,
      nmsThreshold: nmsThreshold,
      modelType: _convertModelType(modelType),
      numKeypoints: numKeypoints,
    );
  }

  @override
  bool isGpuAvailable() => _backend.isGpuAvailable();

  @override
  GpuInfo getGpuInfo() {
    final info = _backend.getGpuInfo();
    return GpuInfo(
      cudaAvailable: info.cudaAvailable,
      tensorrtAvailable: info.tensorrtAvailable,
      coremlAvailable: info.coremlAvailable,
      directmlAvailable: info.directmlAvailable,
      deviceName: info.deviceName,
      cudaDeviceCount: info.cudaDeviceCount,
    );
  }

  @override
  String getAvailableProviders() => _backend.getAvailableProviders();

  @override
  String get lastError => _backend.lastError;

  @override
  int get lastErrorCode => _backend.lastErrorCode;

  @override
  void dispose() => _backend.dispose();

  onnx.ModelType _convertModelType(ModelType type) {
    switch (type) {
      case ModelType.yolo:
        return onnx.ModelType.yolo;
      case ModelType.yoloPose:
        return onnx.ModelType.yoloPose;
    }
  }
}
