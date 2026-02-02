import '../files/file_picker_service.dart';
import '../gadgets/gadget_repository.dart';
import '../gadgets/gadget_service.dart';
import '../gpu/gpu_detector.dart';
import '../image/image_preview_provider.dart';
import '../image/image_repository.dart';
import '../inference/batch_inference_service.dart';
import '../inference/inference_engine.dart';
import '../inference/inference_service.dart';
import '../inference/project_inference_controller.dart';
import '../input/input_action_gate.dart';
import '../input/keyboard_state_reader.dart';
import '../input/keybindings_store.dart';
import '../input/side_button_service.dart';
import '../labels/label_definition_io.dart';
import '../labels/label_file_repository.dart';
import '../projects/project_cover_finder.dart';
import '../projects/project_list_repository.dart';
import '../projects/project_repository.dart';
import '../settings/settings_store.dart';
import '../settings/theme_store.dart';

/// 应用级服务聚合
///
/// 统一装配基础服务与推理依赖，避免在页面中直接访问单例。
class AppServices {
  AppServices._({
    required this.sideButtonService,
    required this.inputActionGate,
    required this.keyboardStateReader,
    required this.inferenceEngine,
    required this.inferenceService,
    required this.gpuDetector,
    required this.batchInferenceService,
    required this.projectInferenceController,
    required this.imagePreviewProvider,
    required this.projectCoverFinder,
    required this.imageRepository,
    required this.labelRepository,
    required this.labelDefinitionIo,
    required this.projectRepository,
    required this.gadgetService,
    required this.filePickerService,
    required this.settingsStore,
    required this.themeStore,
    required this.keyBindingsStore,
    required this.projectListRepository,
  });

  /// 构建服务聚合
  ///
  /// 允许通过参数注入实现以便于测试或替换默认实现。
  factory AppServices({
    SideButtonService? sideButtonService,
    InputActionGate? inputActionGate,
    KeyboardStateReader? keyboardStateReader,
    InferenceEngine? inferenceEngine,
    InferenceEngine Function()? inferenceEngineFactory,
    InferenceService? inferenceService,
    GpuDetector? gpuDetector,
    BatchInferenceService? batchInferenceService,
    ProjectInferenceController? projectInferenceController,
    ImagePreviewProvider? imagePreviewProvider,
    ProjectCoverFinder? projectCoverFinder,
    ImageRepository? imageRepository,
    LabelFileRepository? labelRepository,
    LabelDefinitionIo? labelDefinitionIo,
    ProjectRepository? projectRepository,
    GadgetRepository? gadgetRepository,
    GadgetService? gadgetService,
    FilePickerService? filePickerService,
    SettingsStore? settingsStore,
    ThemeStore? themeStore,
    KeyBindingsStore? keyBindingsStore,
    ProjectListRepository? projectListRepository,
  }) {
    final resolvedImageRepository = imageRepository ?? FileImageRepository();
    final resolvedLabelRepository = labelRepository ?? FileLabelRepository();
    final resolvedGadgetRepository = gadgetRepository ?? FileGadgetRepository();
    final engine = inferenceEngine ??
        (inferenceEngineFactory?.call() ?? OnnxInferenceEngine.instance);
    final service = inferenceService ??
        InferenceService(
          engine: engine,
          imageRepository: resolvedImageRepository,
        );
    final detector = gpuDetector ?? OnnxGpuDetector(engine: engine);
    final batchService = batchInferenceService ??
        BatchInferenceService(
          runner: InferenceServiceBatchRunner(service),
          imageRepository: resolvedImageRepository,
          labelRepository: resolvedLabelRepository,
        );
    final controller = projectInferenceController ??
        ProjectInferenceController(
          runner: InferenceServiceRunner(service),
        );
    final resolvedProjectRepository = projectRepository ??
        ProjectRepository(
          imageRepository: resolvedImageRepository,
          labelRepository: resolvedLabelRepository,
        );
    final resolvedGadgetService =
        gadgetService ?? GadgetService(repository: resolvedGadgetRepository);
    final resolvedFilePickerService =
        filePickerService ?? const PlatformFilePickerService();
    final resolvedSettingsStore = settingsStore ?? SharedPreferencesStore();
    final resolvedThemeStore = themeStore ?? SharedPreferencesThemeStore();
    final resolvedKeyBindingsStore =
        keyBindingsStore ?? SharedPreferencesKeyBindingsStore();
    final resolvedProjectListRepository =
        projectListRepository ?? ProjectListRepository();

    return AppServices._(
      sideButtonService: sideButtonService ?? SideButtonService.instance,
      inputActionGate: inputActionGate ?? InputActionGate.instance,
      keyboardStateReader:
          keyboardStateReader ?? const HardwareKeyboardStateReader(),
      inferenceEngine: engine,
      inferenceService: service,
      gpuDetector: detector,
      batchInferenceService: batchService,
      projectInferenceController: controller,
      imagePreviewProvider:
          imagePreviewProvider ?? const FileImagePreviewProvider(),
      projectCoverFinder: projectCoverFinder ?? const ProjectCoverFinder(),
      imageRepository: resolvedImageRepository,
      labelRepository: resolvedLabelRepository,
      labelDefinitionIo: labelDefinitionIo ?? LabelDefinitionIo(),
      projectRepository: resolvedProjectRepository,
      gadgetService: resolvedGadgetService,
      filePickerService: resolvedFilePickerService,
      settingsStore: resolvedSettingsStore,
      themeStore: resolvedThemeStore,
      keyBindingsStore: resolvedKeyBindingsStore,
      projectListRepository: resolvedProjectListRepository,
    );
  }

  /// 侧键事件流入口。
  final SideButtonService sideButtonService;

  /// 跨输入源的动作去重门闸。
  final InputActionGate inputActionGate;

  /// 当前键盘物理状态读取器。
  final KeyboardStateReader keyboardStateReader;

  /// 推理引擎实例（与推理服务共享）。
  final InferenceEngine inferenceEngine;

  /// 单张/批量推理服务。
  final InferenceService inferenceService;

  /// GPU 可用性检测器。
  final GpuDetector gpuDetector;

  /// 批量推理执行服务。
  final BatchInferenceService batchInferenceService;

  /// 项目级推理流程控制器。
  final ProjectInferenceController projectInferenceController;

  /// 轻量图片预览提供者。
  final ImagePreviewProvider imagePreviewProvider;

  /// 项目封面图查找器。
  final ProjectCoverFinder projectCoverFinder;

  /// 图片文件仓库。
  final ImageRepository imageRepository;

  /// 标签文件仓库。
  final LabelFileRepository labelRepository;

  /// 标签定义文件读写器。
  final LabelDefinitionIo labelDefinitionIo;

  /// 项目图片/标签读写仓库。
  final ProjectRepository projectRepository;

  /// 批处理工具服务。
  final GadgetService gadgetService;

  /// 文件选择器服务。
  final FilePickerService filePickerService;

  /// 应用设置存储。
  final SettingsStore settingsStore;

  /// 主题模式存储。
  final ThemeStore themeStore;

  /// 键位绑定存储。
  final KeyBindingsStore keyBindingsStore;

  /// 最近项目列表仓库。
  final ProjectListRepository projectListRepository;
}
