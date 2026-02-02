import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/models/ai_config.dart';
import 'package:label_load/models/label.dart';
import 'package:label_load/models/label_definition.dart';
import 'package:label_load/services/app/app_services.dart';
import 'package:label_load/services/inference/batch_inference_service.dart';
import 'package:label_load/services/gadgets/gadget_repository.dart';
import 'package:label_load/services/gadgets/gadget_service.dart';
import 'package:label_load/services/gpu/gpu_detector.dart';
import 'package:label_load/services/gpu/gpu_info.dart';
import 'package:label_load/services/image/image_preview_provider.dart';
import 'package:label_load/services/image/image_repository.dart';
import 'package:label_load/services/inference/inference_engine.dart';
import 'package:label_load/services/inference/inference_service.dart';
import 'package:label_load/services/input/input_action_gate.dart';
import 'package:label_load/services/files/file_picker_service.dart';
import 'package:label_load/services/input/keyboard_state_reader.dart';
import 'package:label_load/services/input/keybindings_store.dart';
import 'package:label_load/services/labels/label_definition_io.dart';
import 'package:label_load/services/labels/label_file_repository.dart';
import 'package:label_load/services/projects/project_cover_finder.dart';
import 'package:label_load/services/inference/project_inference_controller.dart';
import 'package:label_load/services/projects/project_list_repository.dart';
import 'package:label_load/services/projects/project_repository.dart';
import 'package:label_load/services/settings/settings_store.dart';
import 'package:label_load/services/input/side_button_service.dart';
import 'package:label_load/services/files/text_file_repository.dart';
import 'package:label_load/services/settings/theme_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeInferenceEngine implements InferenceEngine {
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
  }) {
    return const [];
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
    return List.generate(rgbaBytesList.length, (_) => const []);
  }

  @override
  bool isGpuAvailable() => false;

  @override
  GpuInfo getGpuInfo() {
    return const GpuInfo(
      cudaAvailable: false,
      tensorrtAvailable: false,
      coremlAvailable: false,
      directmlAvailable: false,
      deviceName: 'Fake',
      cudaDeviceCount: 0,
    );
  }

  @override
  String getAvailableProviders() => 'CPUExecutionProvider';

  @override
  String get lastError => '';

  @override
  int get lastErrorCode => 0;

  @override
  void dispose() {}
}

class FakeGpuDetector implements GpuDetector {
  @override
  Future<GpuDetectionResult> detect() async {
    return const GpuDetectionResult(
      available: false,
      info: null,
      providers: 'CPUExecutionProvider',
    );
  }
}

class FakeBatchRunner implements BatchInferenceRunner {
  @override
  void initialize() {}

  @override
  bool isGpuAvailable() => false;

  @override
  Future<bool> loadModel(String path, {bool useGpu = false}) async => true;

  @override
  Future<List<List<Label>>> runBatchInference(
    List<String> imagePaths,
    AiConfig config,
    List<LabelDefinition> labelDefinitions,
  ) async {
    return List.generate(imagePaths.length, (_) => <Label>[]);
  }
}

class FakeInferenceRunner implements InferenceRunner {
  @override
  bool get hasModel => false;

  @override
  String? get loadedModelPath => null;

  @override
  Future<bool> loadModel(String path, {bool useGpu = false}) async => true;

  @override
  Future<List<Label>> runInference(
    String imagePath,
    AiConfig config,
    List<LabelDefinition> labelDefinitions,
  ) async {
    return <Label>[];
  }
}

class FakeKeyboardStateReader implements KeyboardStateReader {
  @override
  bool get isAltPressed => false;

  @override
  bool get isControlPressed => false;

  @override
  bool get isMetaPressed => false;

  @override
  bool get isShiftPressed => false;

  @override
  Set<LogicalKeyboardKey> get logicalKeysPressed => {};
}

class FakeImagePreviewProvider implements ImagePreviewProvider {
  @override
  ImageProvider<Object> create(String path) {
    return const AssetImage('assets/test.png');
  }
}

class FakeProjectCoverFinder extends ProjectCoverFinder {
  const FakeProjectCoverFinder();
}

class FakeImageRepository implements ImageRepository {
  @override
  Future<List<String>> listImagePaths(String directoryPath) async {
    return <String>[];
  }

  @override
  Future<bool> exists(String path) async => false;

  @override
  Future<Uint8List> readBytes(String path) async {
    return Uint8List(0);
  }

  @override
  Future<void> deleteIfExists(String path) async {}
}

class FakeLabelRepository implements LabelFileRepository {
  @override
  Future<void> ensureDirectory(String directoryPath) async {}

  @override
  Future<bool> exists(String path) async => false;

  @override
  Future<void> deleteIfExists(String path) async {}

  @override
  Future<(List<Label>, List<String>)> readLabels(
    String labelPath,
    String Function(int) getName, {
    List<LabelDefinition>? labelDefinitions,
  }) async {
    return (<Label>[], <String>[]);
  }

  @override
  Future<void> writeLabels(
    String labelPath,
    List<Label> labels, {
    List<LabelDefinition>? labelDefinitions,
    List<String>? corruptedLines,
  }) async {}
}

class FakeTextRepository implements TextFileRepository {
  @override
  Future<bool> exists(String path) async => false;

  @override
  Future<String> readString(String path) async => '[]';

  @override
  Future<void> writeString(String path, String content) async {}
}

class FakeSettingsStore implements SettingsStore {
  @override
  Future<int?> getInt(String key) async => null;

  @override
  Future<double?> getDouble(String key) async => null;

  @override
  Future<bool?> getBool(String key) async => null;

  @override
  Future<void> setInt(String key, int value) async {}

  @override
  Future<void> setDouble(String key, double value) async {}

  @override
  Future<void> setBool(String key, bool value) async {}
}

class FakeThemeStore implements ThemeStore {
  @override
  Future<bool?> readIsDark() async => null;

  @override
  Future<void> writeIsDark(bool value) async {}
}

class FakeKeyBindingsStore implements KeyBindingsStore {
  @override
  Future<String?> read() async => null;

  @override
  Future<void> write(String value) async {}
}

class FakeFilePickerService implements FilePickerService {
  @override
  Future<String?> getDirectoryPath() async => null;

  @override
  Future<String?> pickFile({
    String? dialogTitle,
    List<String>? allowedExtensions,
  }) async {
    return null;
  }

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    List<String>? allowedExtensions,
  }) async {
    return null;
  }
}

class FakeProjectsPathProvider implements ProjectsPathProvider {
  @override
  Future<String> getProjectsFilePath() async => '/tmp/projects.json';
}

class FakeGadgetRepository implements GadgetRepository {
  @override
  Future<List<String>> listImageFiles(String directoryPath) async => [];

  @override
  Future<List<String>> listVideoFiles(String directoryPath) async => [];

  @override
  Future<List<String>> listLabelFiles(String directoryPath) async => [];

  @override
  Future<void> renameFile(String from, String to) async {}

  @override
  Future<List<String>> readLines(String path) async => [];

  @override
  Future<void> writeLines(String path, List<String> lines) async {}

  @override
  Future<List<String>> readClassNames(String labelDir) async => [];

  @override
  Future<void> writeClassNames(
    String labelDir,
    List<String> classNames,
  ) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AppServices uses provided dependencies', () {
    final engine = FakeInferenceEngine();
    final inferenceService = InferenceService(engine: engine);
    final gpuDetector = FakeGpuDetector();
    final batchService = BatchInferenceService(runner: FakeBatchRunner());
    final inferenceController =
        ProjectInferenceController(runner: FakeInferenceRunner());
    final keyboardStateReader = FakeKeyboardStateReader();

    final previewProvider = FakeImagePreviewProvider();
    const coverFinder = FakeProjectCoverFinder();
    final imageRepository = FakeImageRepository();
    final labelRepository = FakeLabelRepository();
    final labelDefinitionIo =
        LabelDefinitionIo(repository: FakeTextRepository());
    final projectRepository = ProjectRepository(
      imageRepository: imageRepository,
      labelRepository: labelRepository,
    );
    final gadgetService = GadgetService(repository: FakeGadgetRepository());
    final settingsStore = FakeSettingsStore();
    final themeStore = FakeThemeStore();
    final keyBindingsStore = FakeKeyBindingsStore();
    final filePickerService = FakeFilePickerService();
    final projectListRepository = ProjectListRepository(
      pathProvider: FakeProjectsPathProvider(),
      fileRepository: FakeTextRepository(),
    );

    final services = AppServices(
      inferenceEngine: engine,
      inferenceService: inferenceService,
      gpuDetector: gpuDetector,
      batchInferenceService: batchService,
      projectInferenceController: inferenceController,
      keyboardStateReader: keyboardStateReader,
      inputActionGate: InputActionGate.instance,
      sideButtonService: SideButtonService.instance,
      imagePreviewProvider: previewProvider,
      projectCoverFinder: coverFinder,
      imageRepository: imageRepository,
      labelRepository: labelRepository,
      labelDefinitionIo: labelDefinitionIo,
      projectRepository: projectRepository,
      gadgetService: gadgetService,
      filePickerService: filePickerService,
      settingsStore: settingsStore,
      themeStore: themeStore,
      keyBindingsStore: keyBindingsStore,
      projectListRepository: projectListRepository,
    );

    expect(identical(services.inferenceEngine, engine), isTrue);
    expect(identical(services.inferenceService, inferenceService), isTrue);
    expect(identical(services.gpuDetector, gpuDetector), isTrue);
    expect(identical(services.batchInferenceService, batchService), isTrue);
    expect(
      identical(services.projectInferenceController, inferenceController),
      isTrue,
    );
    expect(
        identical(services.keyboardStateReader, keyboardStateReader), isTrue);
    expect(identical(services.imagePreviewProvider, previewProvider), isTrue);
    expect(identical(services.filePickerService, filePickerService), isTrue);
    expect(identical(services.projectCoverFinder, coverFinder), isTrue);
    expect(identical(services.imageRepository, imageRepository), isTrue);
    expect(identical(services.labelRepository, labelRepository), isTrue);
    expect(identical(services.labelDefinitionIo, labelDefinitionIo), isTrue);
    expect(identical(services.projectRepository, projectRepository), isTrue);
    expect(identical(services.gadgetService, gadgetService), isTrue);
    expect(identical(services.settingsStore, settingsStore), isTrue);
    expect(identical(services.themeStore, themeStore), isTrue);
    expect(identical(services.keyBindingsStore, keyBindingsStore), isTrue);
    expect(
      identical(services.projectListRepository, projectListRepository),
      isTrue,
    );
  });

  test('AppServices builds defaults when dependencies are omitted', () {
    SharedPreferences.setMockInitialValues({});

    final engine = FakeInferenceEngine();
    final services = AppServices(
      inferenceEngineFactory: () => engine,
    );

    expect(identical(services.inferenceEngine, engine), isTrue);
    expect(services.imageRepository, isA<FileImageRepository>());
    expect(services.labelRepository, isA<FileLabelRepository>());
    expect(services.gadgetService, isA<GadgetService>());
    expect(services.filePickerService, isA<PlatformFilePickerService>());
    expect(services.settingsStore, isA<SharedPreferencesStore>());
    expect(services.themeStore, isA<SharedPreferencesThemeStore>());
    expect(services.keyBindingsStore, isA<SharedPreferencesKeyBindingsStore>());
  });
}
