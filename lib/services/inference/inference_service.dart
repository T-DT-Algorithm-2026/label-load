import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import '../../models/ai_config.dart';
import '../../models/label.dart';
import '../../models/label_definition.dart';
import '../app/app_error.dart';
import '../app/error_reporter.dart';
import '../image/image_repository.dart';
import 'inference_label_mapper.dart';
import 'inference_engine.dart';
import '../gpu/gpu_info.dart';

/// AI推理服务
///
/// 单例服务，封装ONNX推理引擎，支持YOLOv8检测、姿态估计和实例分割模型。
class InferenceService {
  static InferenceService? _instance;

  final InferenceEngine _engine;
  ImageRepository _imageRepository;
  String? _loadedModelPath;
  bool _isLoading = false;

  InferenceService({
    ImageRepository? imageRepository,
    InferenceEngine? engine,
    InferenceEngine Function()? engineFactory,
  })  : _engine =
            engine ?? (engineFactory?.call() ?? OnnxInferenceEngine.instance),
        _imageRepository = imageRepository ?? FileImageRepository();

  static InferenceService get instance {
    _instance ??= InferenceService();
    return _instance!;
  }

  /// 覆盖全局单例（测试用）。
  @visibleForTesting
  static void setInstance(InferenceService instance) {
    _instance = instance;
  }

  /// 清空全局单例（测试用）。
  @visibleForTesting
  static void resetInstance() {
    _instance = null;
  }

  /// 是否已加载模型
  bool get hasModel => _engine.hasModel;

  /// 当前加载的模型路径
  String? get loadedModelPath => _loadedModelPath;

  /// 是否正在加载模型
  bool get isLoading => _isLoading;

  @visibleForTesting
  void setImageRepository(ImageRepository repository) {
    _imageRepository = repository;
  }

  /// 初始化推理引擎
  bool initialize() {
    return _engine.initialize();
  }

  /// 加载ONNX模型
  ///
  /// [modelPath] 模型文件路径
  /// [useGpu] 是否使用GPU加速
  Future<bool> loadModel(String modelPath, {bool useGpu = false}) async {
    if (_isLoading) return false;

    _isLoading = true;

    try {
      // 已加载相同模型则跳过
      if (_loadedModelPath == modelPath && hasModel) {
        _isLoading = false;
        return true;
      }

      // 卸载旧模型
      unloadModel();

      // 加载新模型
      final success = _engine.loadModel(modelPath, useGpu: useGpu);
      if (!success) {
        final details = _engine.lastError;
        final code = _engine.lastErrorCode;
        final message =
            details.isEmpty && code != 0 ? 'onnx error code: $code' : details;
        if (message.isNotEmpty) {
          ErrorReporter.report(
            AppError(
              AppErrorCode.aiModelLoadFailed,
              details: message,
            ),
            AppErrorCode.aiModelLoadFailed,
            details: message,
          );
        }
      }
      if (success) {
        _loadedModelPath = modelPath;
      }

      _isLoading = false;
      return success;
    } catch (e, stack) {
      ErrorReporter.report(
        e,
        AppErrorCode.aiModelLoadFailed,
        stackTrace: stack,
        details: 'load model: $modelPath ($e)',
      );
      _isLoading = false;
      return false;
    }
  }

  /// 卸载当前模型
  void unloadModel() {
    _engine.unloadModel();
    _loadedModelPath = null;
  }

  /// 对图像执行推理
  ///
  /// [imagePath] 图像文件路径
  /// [config] AI配置
  /// [labelDefinitions] 标签定义列表（用于类名映射）
  ///
  /// 返回检测到的标签列表。
  Future<List<Label>> runInference(
    String imagePath,
    AiConfig config,
    List<LabelDefinition> labelDefinitions,
  ) async {
    if (!hasModel) {
      throw const AppError(AppErrorCode.aiModelNotLoaded);
    }

    // 读取图像文件
    if (!await _imageRepository.exists(imagePath)) {
      throw AppError(AppErrorCode.imageFileNotFound, details: imagePath);
    }

    final bytes = await _imageRepository.readBytes(imagePath);
    img.Image? image;
    try {
      image = await compute(_decodeImage, bytes);
    } catch (_) {
      image = null;
    }
    if (image == null) {
      throw const AppError(AppErrorCode.imageDecodeFailed);
    }

    // 获取RGBA格式字节数据
    final rgbaBytes = image.getBytes(order: img.ChannelOrder.rgba);

    // 转换模型类型枚举
    // 执行检测
    final detections = _engine.detect(
      rgbaBytes,
      image.width,
      image.height,
      confThreshold: config.confidenceThreshold,
      nmsThreshold: config.nmsThreshold,
      modelType: config.modelType,
      numKeypoints: config.numKeypoints,
    );
    _throwIfEngineError();

    return InferenceLabelMapper.fromDetections(
      detections,
      labelDefinitions,
    );
  }

  /// 批量执行推理
  ///
  /// [imagePaths] 图像文件路径列表
  /// [config] AI配置
  /// [labelDefinitions] 标签定义列表
  ///
  /// 返回每张图片的标签列表。
  Future<List<List<Label>>> runBatchInference(
    List<String> imagePaths,
    AiConfig config,
    List<LabelDefinition> labelDefinitions,
  ) async {
    if (!hasModel) {
      throw const AppError(AppErrorCode.aiModelNotLoaded);
    }

    final images = await Future.wait(imagePaths.map((path) async {
      if (!await _imageRepository.exists(path)) return null;
      final bytes = await _imageRepository.readBytes(path);
      try {
        return await compute(_decodeImage, bytes);
      } catch (_) {
        return null;
      }
    }));

    // 过滤掉解码失败的图片
    final validImages = <img.Image>[];
    final validIndices = <int>[]; // 记录有效图片的原始索引

    for (int i = 0; i < images.length; i++) {
      if (images[i] != null) {
        validImages.add(images[i]!);
        validIndices.add(i);
      }
    }

    if (validImages.isEmpty) {
      return List.filled(imagePaths.length, []);
    }

    // 准备批量数据
    final rgbaDataList = validImages
        .map((image) => image.getBytes(order: img.ChannelOrder.rgba))
        .toList();
    final sizes =
        validImages.map((image) => (image.width, image.height)).toList();
    // 执行批量检测
    final batchDetections = _engine.detectBatch(
      rgbaDataList,
      sizes,
      confThreshold: config.confidenceThreshold,
      nmsThreshold: config.nmsThreshold,
      modelType: config.modelType,
      numKeypoints: config.numKeypoints,
    );
    _throwIfEngineError();

    // 构建结果列表 (保持与输入 paths 长度一致)
    final results = List<List<Label>>.filled(imagePaths.length, []);

    for (int i = 0; i < batchDetections.length; i++) {
      final originalIndex = validIndices[i];
      results[originalIndex] = InferenceLabelMapper.fromDetections(
        batchDetections[i],
        labelDefinitions,
      );
    }

    return results;
  }

  void _throwIfEngineError() {
    final code = _engine.lastErrorCode;
    if (code == 0) return;
    final message = _engine.lastError;
    throw AppError(
      AppErrorCode.aiInferenceFailed,
      details: message.isEmpty ? 'inference error code: $code' : message,
    );
  }

  /// 在隔离线程中解码图像
  static img.Image? _decodeImage(Uint8List bytes) {
    return img.decodeImage(bytes);
  }

  /// 检查GPU是否可用
  bool isGpuAvailable() {
    return _engine.isGpuAvailable();
  }

  /// 获取GPU信息
  GpuInfo getGpuInfo() {
    return _engine.getGpuInfo();
  }

  /// 获取可用的推理提供者
  String getAvailableProviders() {
    return _engine.getAvailableProviders();
  }

  /// 释放资源
  void dispose() {
    unloadModel();
    _engine.dispose();
  }
}
