/// Integration test harness for LabelLoad.
///
/// Provides in-memory fakes and helpers so integration tests can exercise
/// user flows without touching the real file system or native inference libs.
library;

import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:label_load/main.dart';
import 'package:label_load/models/ai_config.dart';
import 'package:label_load/models/label.dart';
import 'package:label_load/models/label_definition.dart';
import 'package:label_load/models/project_config.dart';
import 'package:label_load/providers/keybindings_provider.dart';
import 'package:label_load/services/app/app_services.dart';
import 'package:label_load/services/files/text_file_repository.dart';
import 'package:label_load/services/files/file_picker_service.dart';
import 'package:label_load/services/gadgets/gadget_repository.dart';
import 'package:label_load/services/gadgets/gadget_service.dart';
import 'package:label_load/services/gpu/gpu_detector.dart';
import 'package:label_load/services/gpu/gpu_info.dart';
import 'package:label_load/services/image/image_preview_provider.dart';
import 'package:label_load/services/image/image_repository.dart';
import 'package:label_load/services/inference/batch_inference_service.dart';
import 'package:label_load/services/inference/inference_engine.dart';
import 'package:label_load/services/inference/inference_service.dart';
import 'package:label_load/services/inference/project_inference_controller.dart';
import 'package:label_load/services/input/input_action_gate.dart';
import 'package:label_load/services/input/keyboard_state_reader.dart';
import 'package:label_load/services/input/keybindings_store.dart';
import 'package:label_load/services/input/side_button_service.dart';
import 'package:label_load/services/labels/label_definition_io.dart';
import 'package:label_load/services/labels/label_file_repository.dart';
import 'package:label_load/services/projects/project_cover_finder.dart';
import 'package:label_load/services/projects/project_list_repository.dart';
import 'package:label_load/services/projects/project_repository.dart';
import 'package:label_load/services/settings/settings_store.dart';
import 'package:label_load/services/settings/theme_store.dart';

/// Shared PNG bytes for image previews.
final Uint8List testPngBytes = () {
  final image = img.Image(width: 8, height: 8);
  image.setPixel(0, 0, img.ColorUint8.rgb(255, 0, 0));
  return Uint8List.fromList(img.encodePng(image));
}();

/// Ensure plugin-backed stores have in-memory defaults.
void configureIntegrationTestEnvironment() {
  SharedPreferences.setMockInitialValues({});
}

/// Pump the app and wait until [finder] appears or timeout.
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 5),
  Duration step = const Duration(milliseconds: 50),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(step);
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  fail('Widget not found within timeout: $finder');
}

/// In-memory text repository for JSON imports/exports.
class MemoryTextFileRepository implements TextFileRepository {
  final Map<String, String> _storage = {};

  /// Returns raw content without throwing (test diagnostics only).
  String? peek(String path) => _storage[path];

  @override
  Future<bool> exists(String path) async => _storage.containsKey(path);

  @override
  Future<String> readString(String path) async {
    final value = _storage[path];
    if (value == null) {
      throw StateError('Missing file: $path');
    }
    return value;
  }

  @override
  Future<void> writeString(String path, String content) async {
    _storage[path] = content;
  }
}

/// In-memory image repository for predictable test data.
class FakeImageRepository implements ImageRepository {
  FakeImageRepository({
    Map<String, List<String>>? directoryListing,
    Map<String, Uint8List>? bytesByPath,
  })  : _directoryListing = directoryListing ?? <String, List<String>>{},
        _bytesByPath = bytesByPath ?? <String, Uint8List>{};

  final Map<String, List<String>> _directoryListing;
  final Map<String, Uint8List> _bytesByPath;

  void seedDirectory(String directoryPath, List<String> imagePaths) {
    _directoryListing[directoryPath] = List<String>.from(imagePaths);
  }

  void seedBytes(String path, Uint8List bytes) {
    _bytesByPath[path] = bytes;
  }

  @override
  Future<List<String>> listImagePaths(String directoryPath) async {
    return List<String>.from(_directoryListing[directoryPath] ?? const []);
  }

  @override
  Future<bool> exists(String path) async => _bytesByPath.containsKey(path);

  @override
  Future<Uint8List> readBytes(String path) async {
    final bytes = _bytesByPath[path];
    if (bytes == null) {
      throw StateError('Missing image bytes: $path');
    }
    return bytes;
  }

  @override
  Future<void> deleteIfExists(String path) async {
    _bytesByPath.remove(path);
    for (final entry in _directoryListing.entries) {
      entry.value.remove(path);
    }
  }
}

/// In-memory label file repository.
class FakeLabelFileRepository implements LabelFileRepository {
  FakeLabelFileRepository({
    Map<String, List<Label>>? labelsByPath,
    Map<String, List<String>>? corruptedByPath,
  })  : _labelsByPath = labelsByPath ?? <String, List<Label>>{},
        _corruptedByPath = corruptedByPath ?? <String, List<String>>{};

  final Map<String, List<Label>> _labelsByPath;
  final Map<String, List<String>> _corruptedByPath;

  void seedLabels(String path, List<Label> labels) {
    _labelsByPath[path] = labels.map((label) => label.copyWith()).toList();
  }

  @override
  Future<void> ensureDirectory(String directoryPath) async {}

  @override
  Future<bool> exists(String path) async => _labelsByPath.containsKey(path);

  @override
  Future<void> deleteIfExists(String path) async {
    _labelsByPath.remove(path);
    _corruptedByPath.remove(path);
  }

  @override
  Future<(List<Label>, List<String>)> readLabels(
    String labelPath,
    String Function(int) getName, {
    List<LabelDefinition>? labelDefinitions,
  }) async {
    final labels = _labelsByPath[labelPath] ?? const <Label>[];
    final mapped =
        labels.map((label) => label.copyWith(name: getName(label.id))).toList();
    final corrupted = _corruptedByPath[labelPath] ?? const <String>[];
    return (mapped, List<String>.from(corrupted));
  }

  @override
  Future<void> writeLabels(
    String labelPath,
    List<Label> labels, {
    List<LabelDefinition>? labelDefinitions,
    List<String>? corruptedLines,
  }) async {
    _labelsByPath[labelPath] = labels.map((label) => label.copyWith()).toList();
    _corruptedByPath[labelPath] = List<String>.from(corruptedLines ?? const []);
  }
}

/// In-memory project list repository.
class FakeProjectListRepository extends ProjectListRepository {
  FakeProjectListRepository({List<ProjectConfig>? initialProjects})
      : _projects = List<ProjectConfig>.from(initialProjects ?? const []);

  final List<ProjectConfig> _projects;

  List<ProjectConfig> get projects =>
      List<ProjectConfig>.unmodifiable(_projects);

  @override
  Future<List<ProjectConfig>> loadProjects() async {
    return _projects.map(_cloneProject).toList();
  }

  @override
  Future<void> saveProjects(List<ProjectConfig> projects) async {
    _projects
      ..clear()
      ..addAll(projects.map(_cloneProject));
  }

  ProjectConfig _cloneProject(ProjectConfig project) {
    return project.copyWith(
      name: project.name,
      description: project.description,
      imagePath: project.imagePath,
      labelPath: project.labelPath,
      labelDefinitions: List<LabelDefinition>.from(project.labelDefinitions),
      aiConfig: project.aiConfig.copyWith(),
      lastViewedIndex: project.lastViewedIndex,
      inferredImages: List<String>.from(project.inferredImages),
    );
  }
}

/// In-memory image preview provider.
class FakeImagePreviewProvider implements ImagePreviewProvider {
  FakeImagePreviewProvider(this._bytesByPath, {Uint8List? fallback})
      : _fallback = fallback ?? testPngBytes;

  final Map<String, Uint8List> _bytesByPath;
  final Uint8List _fallback;

  @override
  ImageProvider<Object> create(String path) {
    return MemoryImage(_bytesByPath[path] ?? _fallback);
  }
}

/// Predictable cover finder for project cards.
class FakeProjectCoverFinder extends ProjectCoverFinder {
  FakeProjectCoverFinder(this._covers);

  final Map<String, String?> _covers;

  @override
  Future<String?> findFirstImagePath(String dirPath) async {
    return _covers[dirPath];
  }
}

/// In-memory file picker with queued responses.
class FakeFilePickerService implements FilePickerService {
  final Queue<String?> _directoryQueue = Queue<String?>();
  final Queue<String?> _saveQueue = Queue<String?>();
  final Queue<String?> _fileQueue = Queue<String?>();

  void enqueueDirectoryPath(String? path) => _directoryQueue.add(path);
  void enqueueSavePath(String? path) => _saveQueue.add(path);
  void enqueueFilePath(String? path) => _fileQueue.add(path);

  @override
  Future<String?> getDirectoryPath() async {
    return _directoryQueue.isEmpty ? null : _directoryQueue.removeFirst();
  }

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    List<String>? allowedExtensions,
  }) async {
    return _saveQueue.isEmpty ? null : _saveQueue.removeFirst();
  }

  @override
  Future<String?> pickFile({
    String? dialogTitle,
    List<String>? allowedExtensions,
  }) async {
    return _fileQueue.isEmpty ? null : _fileQueue.removeFirst();
  }
}

/// In-memory settings store for tests.
class MemorySettingsStore implements SettingsStore {
  final Map<String, Object?> _values = {};

  @override
  Future<int?> getInt(String key) async => _values[key] as int?;

  @override
  Future<double?> getDouble(String key) async => _values[key] as double?;

  @override
  Future<bool?> getBool(String key) async => _values[key] as bool?;

  @override
  Future<void> setInt(String key, int value) async {
    _values[key] = value;
  }

  @override
  Future<void> setDouble(String key, double value) async {
    _values[key] = value;
  }

  @override
  Future<void> setBool(String key, bool value) async {
    _values[key] = value;
  }
}

/// In-memory theme store.
class MemoryThemeStore implements ThemeStore {
  bool? _isDark;

  @override
  Future<bool?> readIsDark() async => _isDark;

  @override
  Future<void> writeIsDark(bool value) async {
    _isDark = value;
  }
}

/// In-memory key bindings store.
class MemoryKeyBindingsStore implements KeyBindingsStore {
  String? _value;

  @override
  Future<String?> read() async => _value;

  @override
  Future<void> write(String value) async {
    _value = value;
  }
}

/// Fake GPU detector with CPU-only output.
class FakeGpuDetector implements GpuDetector {
  @override
  Future<GpuDetectionResult> detect() async {
    return const GpuDetectionResult(
      available: false,
      info: GpuInfo(
        cudaAvailable: false,
        tensorrtAvailable: false,
        coremlAvailable: false,
        directmlAvailable: false,
        deviceName: 'CPU',
        cudaDeviceCount: 0,
      ),
      providers: 'CPUExecutionProvider',
    );
  }
}

/// Keyboard reader that never reports pressed keys.
class FakeKeyboardStateReader implements KeyboardStateReader {
  @override
  bool get isControlPressed => false;

  @override
  bool get isMetaPressed => false;

  @override
  bool get isShiftPressed => false;

  @override
  bool get isAltPressed => false;

  @override
  Set<LogicalKeyboardKey> get logicalKeysPressed => <LogicalKeyboardKey>{};
}

/// Input gate that always allows actions.
class AllowAllInputActionGate implements InputActionGate {
  @override
  bool shouldHandle(
    BindableAction action,
    InputSource source, {
    Duration window = const Duration(milliseconds: 30),
  }) {
    return true;
  }

  @override
  void reset() {}
}

/// Side-button stream for tests.
class FakeSideButtonService implements SideButtonService {
  final StreamController<SideButtonEvent> _controller =
      StreamController<SideButtonEvent>.broadcast();

  @override
  Stream<SideButtonEvent> get stream => _controller.stream;

  void emit(SideButtonEvent event) => _controller.add(event);

  Future<void> dispose() async {
    await _controller.close();
  }
}

/// Minimal inference runner for project inference.
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

/// Minimal batch inference runner for tests.
class FakeBatchInferenceRunner implements BatchInferenceRunner {
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
    return List<List<Label>>.generate(
      imagePaths.length,
      (_) => <Label>[],
    );
  }
}

/// Fake inference engine that never calls native bindings.
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
    return List<List<dynamic>>.generate(
      rgbaBytesList.length,
      (_) => const [],
    );
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
      deviceName: 'CPU',
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

/// In-memory gadget repository to avoid file system access.
class FakeGadgetRepository implements GadgetRepository {
  final Map<String, List<String>> _imagesByDir = {};
  final Map<String, List<String>> _labelsByDir = {};
  final Map<String, List<String>> _videosByDir = {};
  final Map<String, List<String>> _fileLines = {};
  final Map<String, List<String>> _classNames = {};

  void seedImages(String directory, List<String> files) {
    _imagesByDir[directory] = List<String>.from(files);
  }

  void seedLabels(String directory, List<String> files) {
    _labelsByDir[directory] = List<String>.from(files);
  }

  void seedVideos(String directory, List<String> files) {
    _videosByDir[directory] = List<String>.from(files);
  }

  @override
  Future<List<String>> listImageFiles(String directoryPath) async {
    return List<String>.from(_imagesByDir[directoryPath] ?? const []);
  }

  @override
  Future<List<String>> listVideoFiles(String directoryPath) async {
    return List<String>.from(_videosByDir[directoryPath] ?? const []);
  }

  @override
  Future<List<String>> listLabelFiles(String directoryPath) async {
    return List<String>.from(_labelsByDir[directoryPath] ?? const []);
  }

  @override
  Future<void> renameFile(String from, String to) async {
    final lines = _fileLines.remove(from);
    if (lines != null) {
      _fileLines[to] = lines;
    }
  }

  @override
  Future<List<String>> readLines(String path) async {
    return List<String>.from(_fileLines[path] ?? const []);
  }

  @override
  Future<void> writeLines(String path, List<String> lines) async {
    _fileLines[path] = List<String>.from(lines);
  }

  @override
  Future<List<String>> readClassNames(String labelDir) async {
    return List<String>.from(_classNames[labelDir] ?? const []);
  }

  @override
  Future<void> writeClassNames(String labelDir, List<String> classNames) async {
    _classNames[labelDir] = List<String>.from(classNames);
  }
}

/// Test harness that wires the app with in-memory services.
class TestAppHarness {
  TestAppHarness({
    List<ProjectConfig>? initialProjects,
    Map<String, List<String>>? imageListing,
    Map<String, Uint8List>? imageBytesByPath,
    Map<String, List<Label>>? labelsByPath,
    Map<String, String?>? coversByDir,
    InferenceRunner? inferenceRunner,
    BatchInferenceRunner? batchInferenceRunner,
  }) {
    projectListRepository =
        FakeProjectListRepository(initialProjects: initialProjects);
    imageRepository = FakeImageRepository(
      directoryListing: imageListing,
      bytesByPath: imageBytesByPath,
    );
    labelRepository = FakeLabelFileRepository(labelsByPath: labelsByPath);
    imagePreviewProvider =
        FakeImagePreviewProvider(imageRepository._bytesByPath);
    projectCoverFinder = FakeProjectCoverFinder(coversByDir ?? const {});
    filePickerService = FakeFilePickerService();
    settingsStore = MemorySettingsStore();
    themeStore = MemoryThemeStore();
    keyBindingsStore = MemoryKeyBindingsStore();
    gpuDetector = FakeGpuDetector();
    keyboardStateReader = FakeKeyboardStateReader();
    inputActionGate = AllowAllInputActionGate();
    sideButtonService = FakeSideButtonService();
    inferenceEngine = FakeInferenceEngine();
    inferenceService = InferenceService(
      imageRepository: imageRepository,
      engine: inferenceEngine,
    );
    batchInferenceService = BatchInferenceService(
      runner: batchInferenceRunner ?? FakeBatchInferenceRunner(),
      imageRepository: imageRepository,
      labelRepository: labelRepository,
    );
    projectInferenceController = ProjectInferenceController(
        runner: inferenceRunner ?? FakeInferenceRunner());
    textFileRepository = MemoryTextFileRepository();
    labelDefinitionIo = LabelDefinitionIo(repository: textFileRepository);
    projectRepository = ProjectRepository(
      imageRepository: imageRepository,
      labelRepository: labelRepository,
    );
    gadgetRepository = FakeGadgetRepository();
    gadgetService = GadgetService(repository: gadgetRepository);

    services = AppServices(
      sideButtonService: sideButtonService,
      inputActionGate: inputActionGate,
      keyboardStateReader: keyboardStateReader,
      inferenceEngine: inferenceEngine,
      inferenceService: inferenceService,
      gpuDetector: gpuDetector,
      batchInferenceService: batchInferenceService,
      projectInferenceController: projectInferenceController,
      imagePreviewProvider: imagePreviewProvider,
      projectCoverFinder: projectCoverFinder,
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
  }

  late final FakeProjectListRepository projectListRepository;
  late final FakeImageRepository imageRepository;
  late final FakeLabelFileRepository labelRepository;
  late final FakeImagePreviewProvider imagePreviewProvider;
  late final FakeProjectCoverFinder projectCoverFinder;
  late final FakeFilePickerService filePickerService;
  late final MemorySettingsStore settingsStore;
  late final MemoryThemeStore themeStore;
  late final MemoryKeyBindingsStore keyBindingsStore;
  late final FakeGpuDetector gpuDetector;
  late final FakeKeyboardStateReader keyboardStateReader;
  late final AllowAllInputActionGate inputActionGate;
  late final FakeSideButtonService sideButtonService;
  late final FakeInferenceEngine inferenceEngine;
  late final InferenceService inferenceService;
  late final BatchInferenceService batchInferenceService;
  late final ProjectInferenceController projectInferenceController;
  late final LabelDefinitionIo labelDefinitionIo;
  late final MemoryTextFileRepository textFileRepository;
  late final ProjectRepository projectRepository;
  late final FakeGadgetRepository gadgetRepository;
  late final GadgetService gadgetService;
  late final AppServices services;

  /// Build the app with the fake services wired in.
  LabelLoadApp buildApp() {
    return LabelLoadApp(servicesBuilder: () => services);
  }
}
