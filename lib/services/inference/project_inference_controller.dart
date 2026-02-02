import '../../models/ai_config.dart';
import '../../models/label.dart';
import '../../models/label_definition.dart';
import 'ai_post_processor.dart';
import '../app/app_error.dart';
import '../app/error_reporter.dart';
import 'inference_service.dart';

/// 推理执行接口
abstract class InferenceRunner {
  /// 是否已加载模型。
  bool get hasModel;

  /// 当前已加载模型路径。
  String? get loadedModelPath;

  /// 加载模型，返回是否成功。
  Future<bool> loadModel(String path, {bool useGpu = false});

  /// 执行推理并返回标签。
  Future<List<Label>> runInference(
    String imagePath,
    AiConfig config,
    List<LabelDefinition> labelDefinitions,
  );
}

/// InferenceService 适配器
class InferenceServiceRunner implements InferenceRunner {
  final InferenceService _service;

  InferenceServiceRunner(this._service);

  @override
  bool get hasModel => _service.hasModel;

  @override
  String? get loadedModelPath => _service.loadedModelPath;

  @override
  Future<bool> loadModel(String path, {bool useGpu = false}) {
    return _service.loadModel(path, useGpu: useGpu);
  }

  @override
  Future<List<Label>> runInference(
    String imagePath,
    AiConfig config,
    List<LabelDefinition> labelDefinitions,
  ) {
    return _service.runInference(imagePath, config, labelDefinitions);
  }
}

/// 项目推理控制器
class ProjectInferenceController {
  final InferenceRunner _runner;
  final AiPostProcessor _postProcessor;

  ProjectInferenceController({
    InferenceRunner? runner,
    AiPostProcessor? postProcessor,
  })  : _runner = runner ?? InferenceServiceRunner(InferenceService()),
        _postProcessor = postProcessor ?? const AiPostProcessor();

  /// 是否已加载模型。
  bool get hasModel => _runner.hasModel;

  /// 当前加载的模型路径（可能为空）。
  String? get loadedModelPath => _runner.loadedModelPath;

  /// 加载ONNX模型（GPU失败时自动回退到CPU）
  Future<bool> loadModel(String path, {bool useGpu = false}) async {
    if (path.isEmpty) return false;

    try {
      final success = await _runner.loadModel(path, useGpu: useGpu);
      if (!success && useGpu) {
        return _runner.loadModel(path, useGpu: false);
      }
      return success;
    } catch (e, stack) {
      ErrorReporter.report(
        e,
        AppErrorCode.aiModelLoadFailed,
        stackTrace: stack,
        details: 'load model: $path ($e)',
      );
      if (useGpu) {
        try {
          return await _runner.loadModel(path, useGpu: false);
        } catch (err, stack) {
          ErrorReporter.report(
            err,
            AppErrorCode.aiModelLoadFailed,
            stackTrace: stack,
            details: 'load model: $path ($err)',
          );
          return false;
        }
      }
      return false;
    }
  }

  /// 执行推理并应用后处理
  Future<List<Label>> inferLabels({
    required String imagePath,
    required AiConfig config,
    required List<LabelDefinition> labelDefinitions,
  }) async {
    final labels = await _runner.runInference(
      imagePath,
      config,
      labelDefinitions,
    );

    if (labels.isNotEmpty) {
      if (config.labelSaveMode == LabelSaveMode.append &&
          config.classIdOffset != 0) {
        _postProcessor.applyClassIdOffset(labels, config.classIdOffset);
      }

      _postProcessor.sanitizeLabels(labels, labelDefinitions);
    }

    return labels;
  }
}
