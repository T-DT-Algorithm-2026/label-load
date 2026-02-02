import 'package:path/path.dart' as path;
import '../../models/ai_config.dart';
import '../../models/label.dart';
import '../../models/label_definition.dart';
import 'ai_post_processor.dart';
import '../app/app_error.dart';
import '../app/error_reporter.dart';
import '../image/image_repository.dart';
import 'inference_service.dart';
import '../labels/label_file_repository.dart';

/// 批量推理执行器接口。
abstract class BatchInferenceRunner {
  /// 初始化推理环境。
  void initialize();

  /// GPU 是否可用。
  bool isGpuAvailable();

  /// 加载模型并返回是否成功。
  Future<bool> loadModel(String path, {bool useGpu = false});

  /// 执行批量推理。
  Future<List<List<Label>>> runBatchInference(
    List<String> imagePaths,
    AiConfig config,
    List<LabelDefinition> labelDefinitions,
  );
}

/// InferenceService 适配器。
class InferenceServiceBatchRunner implements BatchInferenceRunner {
  final InferenceService _service;

  InferenceServiceBatchRunner(this._service);

  @override
  void initialize() {
    _service.initialize();
  }

  @override
  bool isGpuAvailable() {
    return _service.isGpuAvailable();
  }

  @override
  Future<bool> loadModel(String path, {bool useGpu = false}) {
    return _service.loadModel(path, useGpu: useGpu);
  }

  @override
  Future<List<List<Label>>> runBatchInference(
    List<String> imagePaths,
    AiConfig config,
    List<LabelDefinition> labelDefinitions,
  ) {
    return _service.runBatchInference(imagePaths, config, labelDefinitions);
  }
}

/// 批量推理汇总结果。
class BatchInferenceSummary {
  /// 模型是否成功加载。
  final bool modelLoaded;

  /// 最终使用的标签定义（可能自动补全）。
  final List<LabelDefinition> definitions;

  /// 已推理图片文件名集合。
  final Set<String> inferredImages;

  /// 总图片数量。
  final int totalImages;

  /// 已处理图片数量。
  final int processedImages;

  /// 失败的批次数量。
  final int failedBatches;

  /// 最近一次错误（若有）。
  final AppError? lastError;

  const BatchInferenceSummary({
    required this.modelLoaded,
    required this.definitions,
    required this.inferredImages,
    required this.totalImages,
    required this.processedImages,
    this.failedBatches = 0,
    this.lastError,
  });
}

/// 批量推理服务。
class BatchInferenceService {
  BatchInferenceService({
    BatchInferenceRunner? runner,
    AiPostProcessor? postProcessor,
    ImageRepository? imageRepository,
    LabelFileRepository? labelRepository,
  })  : _runner = runner ?? InferenceServiceBatchRunner(InferenceService()),
        _postProcessor = postProcessor ?? const AiPostProcessor(),
        _imageRepository = imageRepository ?? FileImageRepository(),
        _labelRepository = labelRepository ?? FileLabelRepository();

  final BatchInferenceRunner _runner;
  final AiPostProcessor _postProcessor;
  final ImageRepository _imageRepository;
  final LabelFileRepository _labelRepository;

  /// 执行批量推理并返回结果汇总。
  Future<BatchInferenceSummary> run({
    required String imageDir,
    required String labelDir,
    required AiConfig config,
    required List<LabelDefinition> definitions,
    required bool useGpu,
    bool Function()? shouldContinue,
    void Function(int current, int total)? onProgress,
    void Function(List<LabelDefinition> updatedDefinitions)?
        onDefinitionsUpdated,
    void Function(String fileName)? onInferredImage,
  }) async {
    final continueCheck = shouldContinue ?? () => true;
    final imageFiles = await _imageRepository.listImagePaths(imageDir);
    final totalImages = imageFiles.length;
    onProgress?.call(0, totalImages);

    if (totalImages == 0) {
      return BatchInferenceSummary(
        modelLoaded: true,
        definitions: definitions,
        inferredImages: {},
        totalImages: 0,
        processedImages: 0,
      );
    }

    await _labelRepository.ensureDirectory(labelDir);

    _runner.initialize();
    final modelLoaded =
        await _runner.loadModel(config.modelPath, useGpu: useGpu);

    if (!modelLoaded) {
      return BatchInferenceSummary(
        modelLoaded: false,
        definitions: definitions,
        inferredImages: {},
        totalImages: totalImages,
        processedImages: 0,
      );
    }

    final useBatchGpu = useGpu && _runner.isGpuAvailable();
    final batchSize = useBatchGpu ? 32 : 4;

    var currentDefinitions = definitions;
    final inferredImages = <String>{};
    var processedImages = 0;
    var failedBatches = 0;
    AppError? lastError;

    for (int i = 0; i < imageFiles.length; i += batchSize) {
      if (!continueCheck()) break;

      final end = (i + batchSize < imageFiles.length)
          ? i + batchSize
          : imageFiles.length;
      final batchPaths = imageFiles.sublist(i, end);
      onProgress?.call(i + 1, totalImages);

      try {
        final batchLabels = await _runner.runBatchInference(
          batchPaths,
          config,
          currentDefinitions,
        );

        for (int j = 0; j < batchPaths.length; j++) {
          final imagePath = batchPaths[j];
          final newLabels = batchLabels[j];

          if (config.labelSaveMode == LabelSaveMode.append &&
              config.classIdOffset != 0) {
            _postProcessor.applyClassIdOffset(newLabels, config.classIdOffset);
          }

          _postProcessor.sanitizeLabels(newLabels, currentDefinitions);

          final updatedDefinitions = _postProcessor.fillMissingDefinitions(
              newLabels, currentDefinitions);
          if (!identical(updatedDefinitions, currentDefinitions)) {
            currentDefinitions = updatedDefinitions;
            onDefinitionsUpdated?.call(updatedDefinitions);
          }

          final baseName = path.basenameWithoutExtension(imagePath);
          final labelFilePath = path.join(labelDir, '$baseName.txt');

          List<Label> finalLabels = newLabels;
          List<String> corruptedLines = [];

          String getName(int id) => currentDefinitions.nameForClassId(id);

          if (await _labelRepository.exists(labelFilePath)) {
            final result = await _labelRepository.readLabels(
              labelFilePath,
              getName,
              labelDefinitions: currentDefinitions,
            );
            final existingLabels = result.$1;
            corruptedLines = result.$2;

            if (config.labelSaveMode == LabelSaveMode.append &&
                existingLabels.isNotEmpty) {
              finalLabels = [...existingLabels, ...newLabels];
            }
          }

          await _labelRepository.writeLabels(
            labelFilePath,
            finalLabels,
            labelDefinitions: currentDefinitions,
            corruptedLines: corruptedLines,
          );

          final fileName = path.basename(imagePath);
          inferredImages.add(fileName);
          onInferredImage?.call(fileName);
          processedImages += 1;
        }

        onProgress?.call(end, totalImages);
      } catch (e, stack) {
        lastError = ErrorReporter.report(
          e,
          AppErrorCode.aiInferenceFailed,
          stackTrace: stack,
          details: 'batch inference: $e',
        );
        failedBatches += 1;
      }
    }

    return BatchInferenceSummary(
      modelLoaded: true,
      definitions: currentDefinitions,
      inferredImages: inferredImages,
      totalImages: totalImages,
      processedImages: processedImages,
      failedBatches: failedBatches,
      lastError: lastError,
    );
  }
}
