import 'gpu_info.dart';
import '../inference/inference_engine.dart';

/// GPU 检测结果。
class GpuDetectionResult {
  /// 是否检测到可用的 GPU 加速能力。
  final bool available;

  /// 推理引擎提供的详细能力描述（可能为空）。
  final GpuInfo? info;

  /// 当前运行时可用的执行提供者列表（字符串格式）。
  final String providers;

  const GpuDetectionResult({
    required this.available,
    required this.info,
    required this.providers,
  });
}

/// GPU 检测器接口。
abstract class GpuDetector {
  /// 执行检测并返回结果。
  Future<GpuDetectionResult> detect();
}

/// 基于 ONNX 推理引擎的 GPU 检测器。
class OnnxGpuDetector implements GpuDetector {
  OnnxGpuDetector({
    InferenceEngine? engine,
    InferenceEngine Function()? engineFactory,
  }) : _engine =
            engine ?? (engineFactory?.call() ?? OnnxInferenceEngine.instance);

  final InferenceEngine _engine;

  @override
  Future<GpuDetectionResult> detect() async {
    _engine.initialize();
    final available = _engine.isGpuAvailable();
    final info = _engine.getGpuInfo();
    final providers = _engine.getAvailableProviders();
    return GpuDetectionResult(
      available: available,
      info: info,
      providers: providers,
    );
  }
}
