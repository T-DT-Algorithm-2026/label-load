import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import 'package:label_load/models/ai_config.dart';
import 'package:label_load/models/label.dart';
import 'package:label_load/models/label_definition.dart';
import 'package:label_load/models/project_config.dart';
import 'package:label_load/pages/project_settings_page.dart';
import 'package:label_load/providers/project_list_provider.dart';
import 'package:label_load/providers/project_provider.dart';
import 'package:label_load/providers/settings_provider.dart';
import 'package:label_load/services/app/app_error.dart';
import 'package:label_load/services/app/app_services.dart';
import 'package:label_load/services/inference/batch_inference_service.dart';
import 'package:label_load/services/files/file_picker_service.dart';
import 'package:label_load/services/gadgets/gadget_repository.dart';
import 'package:label_load/services/gadgets/gadget_service.dart';
import 'package:label_load/services/inference/inference_engine.dart';
import 'package:label_load/services/image/image_repository.dart';
import 'package:label_load/services/labels/label_definition_io.dart';
import 'package:label_load/services/gpu/gpu_info.dart';

import 'test_helpers.dart';

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
  GpuInfo getGpuInfo() => const GpuInfo(
        cudaAvailable: false,
        tensorrtAvailable: false,
        coremlAvailable: false,
        directmlAvailable: false,
        deviceName: 'Fake',
        cudaDeviceCount: 0,
      );

  @override
  String getAvailableProviders() => 'CPU';

  @override
  String get lastError => '';

  @override
  int get lastErrorCode => 0;

  @override
  void dispose() {}
}

class StubSettingsProvider extends SettingsProvider {
  StubSettingsProvider({this.useGpuValue = false})
      : super(
          autoLoad: false,
          store: FakeSettingsStore(),
          gpuDetector: FakeGpuDetector(),
        );

  final bool useGpuValue;

  @override
  bool get useGpu => useGpuValue;
}

class StubProjectListProvider extends ProjectListProvider {
  ProjectConfig? addedProject;
  ProjectConfig? updatedProject;

  @override
  Future<void> addProject(ProjectConfig project) async {
    addedProject = project;
  }

  @override
  Future<void> updateProject(ProjectConfig project) async {
    updatedProject = project;
  }
}

class StubProjectProvider extends ProjectProvider {
  ProjectConfig? projectConfigValue;
  ProjectConfig? reloadConfigValue;

  @override
  ProjectConfig? get projectConfig => projectConfigValue;

  @override
  Future<void> reloadConfig(ProjectConfig config) async {
    reloadConfigValue = config;
  }
}

class FakeFilePickerService implements FilePickerService {
  String? nextDirectoryPath;
  String? nextSavePath;
  String? nextPickPath;

  @override
  Future<String?> getDirectoryPath() async => nextDirectoryPath;

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    List<String>? allowedExtensions,
  }) async {
    return nextSavePath;
  }

  @override
  Future<String?> pickFile({
    String? dialogTitle,
    List<String>? allowedExtensions,
  }) async {
    return nextPickPath;
  }
}

class FakeLabelDefinitionIo extends LabelDefinitionIo {
  FakeLabelDefinitionIo();

  List<LabelDefinition> imported = [];
  String? lastExportPath;
  List<LabelDefinition>? lastExported;
  bool throwOnExport = false;
  bool throwOnImport = false;

  @override
  Future<void> exportToFile(String path, List<LabelDefinition> labels) async {
    if (throwOnExport) {
      throw Exception('export failed');
    }
    lastExportPath = path;
    lastExported = List.from(labels);
  }

  @override
  Future<List<LabelDefinition>> importFromFile(String path) async {
    if (throwOnImport) {
      throw Exception('import failed');
    }
    return List.from(imported);
  }
}

class FakeImageRepository implements ImageRepository {
  FakeImageRepository({List<String>? imagePaths})
      : _imagePaths = imagePaths ?? <String>[];

  final List<String> _imagePaths;

  @override
  Future<List<String>> listImagePaths(String dirPath) async {
    return List.from(_imagePaths);
  }

  @override
  Future<bool> exists(String path) async => true;

  @override
  Future<Uint8List> readBytes(String path) async => Uint8List(0);

  @override
  Future<void> deleteIfExists(String path) async {}
}

class FakeGadgetRepository implements GadgetRepository {
  @override
  Future<List<String>> listImageFiles(String directoryPath) async => [];

  @override
  Future<List<String>> listLabelFiles(String directoryPath) async => [];

  @override
  Future<List<String>> listVideoFiles(String directoryPath) async => [];

  @override
  Future<void> renameFile(String fromPath, String toPath) async {}

  @override
  Future<List<String>> readLines(String path) async => [];

  @override
  Future<void> writeLines(String path, List<String> lines) async {}

  @override
  Future<List<String>> readClassNames(String directoryPath) async => [];

  @override
  Future<void> writeClassNames(
      String directoryPath, List<String> classNames) async {}
}

class FakeGadgetService extends GadgetService {
  FakeGadgetService() : super(repository: FakeGadgetRepository());

  (int, int) deleteResult = (0, 0);
  int deleteCalls = 0;

  @override
  Future<(int, int)> deleteClassFromLabels(
    String directoryPath,
    int classIdToDelete, {
    void Function(int current, int total)? onProgress,
    GadgetRepository? repository,
  }) async {
    deleteCalls += 1;
    return deleteResult;
  }
}

class FakeBatchInferenceService extends BatchInferenceService {
  FakeBatchInferenceService(this.summary) : super(runner: _FakeBatchRunner());

  BatchInferenceSummary summary;
  int runCalls = 0;
  Completer<void>? gate;
  bool throwOnRun = false;

  @override
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
    runCalls += 1;
    if (throwOnRun) {
      throw Exception('batch failed');
    }
    if (gate != null) {
      await gate!.future;
    }
    onProgress?.call(1, 1);
    onDefinitionsUpdated?.call(definitions);
    onInferredImage?.call('image1.jpg');
    return summary;
  }
}

class _FakeBatchRunner implements BatchInferenceRunner {
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

Finder _textFieldWithLabel(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );
}

Future<void> _pumpSettingsPage(
  WidgetTester tester, {
  ProjectConfig? project,
  required StubProjectListProvider listProvider,
  required StubProjectProvider projectProvider,
  required FakeFilePickerService filePicker,
  required FakeLabelDefinitionIo labelIo,
  required FakeImageRepository imageRepository,
  required FakeBatchInferenceService batchService,
  required FakeGadgetService gadgetService,
}) async {
  await setLargeSurface(tester);
  final services = AppServices(
    inferenceEngine: FakeInferenceEngine(),
    batchInferenceService: batchService,
    labelDefinitionIo: labelIo,
    imageRepository: imageRepository,
    filePickerService: filePicker,
    gadgetService: gadgetService,
  );

  await tester.pumpWidget(buildPageTestApp(
    child: ProjectSettingsPage(
      project: project,
      batchInferenceService: batchService,
      labelDefinitionIo: labelIo,
      imageRepository: imageRepository,
      filePickerService: filePicker,
    ),
    providers: [
      Provider<AppServices>.value(value: services),
      ChangeNotifierProvider<ProjectListProvider>.value(value: listProvider),
      ChangeNotifierProvider<ProjectProvider>.value(value: projectProvider),
      ChangeNotifierProvider<SettingsProvider>(
        create: (_) => StubSettingsProvider(),
      ),
    ],
  ));
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ProjectSettingsPage validates name and saves new project',
      (tester) async {
    final listProvider = StubProjectListProvider();
    final projectProvider = StubProjectProvider();
    final filePicker = FakeFilePickerService();
    final labelIo = FakeLabelDefinitionIo();
    final imageRepository = FakeImageRepository();
    final batchService = FakeBatchInferenceService(const BatchInferenceSummary(
      modelLoaded: true,
      definitions: [],
      inferredImages: {},
      totalImages: 0,
      processedImages: 0,
    ));
    final gadgetService = FakeGadgetService();

    await _pumpSettingsPage(
      tester,
      listProvider: listProvider,
      projectProvider: projectProvider,
      filePicker: filePicker,
      labelIo: labelIo,
      imageRepository: imageRepository,
      batchService: batchService,
      gadgetService: gadgetService,
    );

    final l10n = AppLocalizations.of(
      tester.element(find.byType(ProjectSettingsPage)),
    )!;

    await tester.tap(find.byIcon(Icons.save));
    await tester.pump();
    expect(find.text(l10n.projectNameRequired), findsOneWidget);

    await tester.enterText(
      _textFieldWithLabel(l10n.projectName),
      'New Project',
    );
    await tester.tap(find.byIcon(Icons.save));
    await tester.pumpAndSettle();
    expect(listProvider.addedProject?.name, 'New Project');
  });

  testWidgets('ProjectSettingsPage edits and reloads active project',
      (tester) async {
    final project = ProjectConfig(id: 'p1', name: 'Old');
    final listProvider = StubProjectListProvider();
    final projectProvider = StubProjectProvider()..projectConfigValue = project;
    final filePicker = FakeFilePickerService();
    final labelIo = FakeLabelDefinitionIo();
    final imageRepository = FakeImageRepository();
    final batchService = FakeBatchInferenceService(const BatchInferenceSummary(
      modelLoaded: true,
      definitions: [],
      inferredImages: {},
      totalImages: 0,
      processedImages: 0,
    ));
    final gadgetService = FakeGadgetService();

    await _pumpSettingsPage(
      tester,
      project: project,
      listProvider: listProvider,
      projectProvider: projectProvider,
      filePicker: filePicker,
      labelIo: labelIo,
      imageRepository: imageRepository,
      batchService: batchService,
      gadgetService: gadgetService,
    );

    final l10n = AppLocalizations.of(
      tester.element(find.byType(ProjectSettingsPage)),
    )!;
    await tester.enterText(
      _textFieldWithLabel(l10n.projectName),
      'Updated',
    );
    await tester.tap(find.byIcon(Icons.save));
    await tester.pumpAndSettle();

    expect(listProvider.updatedProject?.name, 'Updated');
    expect(projectProvider.reloadConfigValue?.id, project.id);
  });

  testWidgets('ProjectSettingsPage imports, edits, and exports labels',
      (tester) async {
    final listProvider = StubProjectListProvider();
    final projectProvider = StubProjectProvider();
    final filePicker = FakeFilePickerService()
      ..nextPickPath = '/tmp/labels.json'
      ..nextSavePath = '/tmp/export.json';
    final labelIo = FakeLabelDefinitionIo()
      ..imported = [
        LabelDefinition(
          classId: 0,
          name: 'Imported',
          color: Colors.red,
        )
      ];
    final imageRepository = FakeImageRepository();
    final batchService = FakeBatchInferenceService(const BatchInferenceSummary(
      modelLoaded: true,
      definitions: [],
      inferredImages: {},
      totalImages: 0,
      processedImages: 0,
    ));
    final gadgetService = FakeGadgetService();

    await _pumpSettingsPage(
      tester,
      listProvider: listProvider,
      projectProvider: projectProvider,
      filePicker: filePicker,
      labelIo: labelIo,
      imageRepository: imageRepository,
      batchService: batchService,
      gadgetService: gadgetService,
    );

    final l10n = AppLocalizations.of(
      tester.element(find.byType(ProjectSettingsPage)),
    )!;

    await tester.tap(find.byIcon(Icons.file_upload));
    await tester.pumpAndSettle();
    expect(find.text('Imported'), findsOneWidget);
    expect(find.text(l10n.importSuccess), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    final dialogContext = tester.element(find.byType(AlertDialog));
    Navigator.of(dialogContext).pop(LabelDefinition(
      classId: 1,
      name: 'Added',
      color: Colors.green,
    ));
    await tester.pumpAndSettle();
    expect(find.text('Added'), findsOneWidget);

    final importedTile = find.widgetWithText(ListTile, 'Imported');
    final editButton = find.descendant(
      of: importedTile,
      matching: find.byIcon(Icons.edit),
    );
    await tester.tap(editButton);
    await tester.pumpAndSettle();
    final editDialogContext = tester.element(find.byType(AlertDialog));
    Navigator.of(editDialogContext).pop(LabelDefinition(
      classId: 0,
      name: 'Edited',
      color: Colors.blue,
    ));
    await tester.pumpAndSettle();
    expect(find.text('Edited'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.file_download));
    await tester.pumpAndSettle();
    expect(labelIo.lastExportPath, '/tmp/export.json');
    expect(find.text(l10n.exportSuccess), findsOneWidget);
  });

  testWidgets('ProjectSettingsPage updates paths and shows label types',
      (tester) async {
    final project = ProjectConfig(
      id: 'p1',
      name: 'Project',
      labelDefinitions: [
        LabelDefinition(
          classId: 0,
          name: 'Keypoint',
          color: Colors.red,
          type: LabelType.boxWithPoint,
        ),
        LabelDefinition(
          classId: 1,
          name: 'Polygon',
          color: Colors.green,
          type: LabelType.polygon,
        ),
      ],
    );
    final listProvider = StubProjectListProvider();
    final projectProvider = StubProjectProvider();
    final filePicker = FakeFilePickerService()
      ..nextDirectoryPath = '/tmp/images';
    final labelIo = FakeLabelDefinitionIo();
    final imageRepository = FakeImageRepository();
    final batchService = FakeBatchInferenceService(const BatchInferenceSummary(
      modelLoaded: true,
      definitions: [],
      inferredImages: {},
      totalImages: 0,
      processedImages: 0,
    ));
    final gadgetService = FakeGadgetService();

    await _pumpSettingsPage(
      tester,
      project: project,
      listProvider: listProvider,
      projectProvider: projectProvider,
      filePicker: filePicker,
      labelIo: labelIo,
      imageRepository: imageRepository,
      batchService: batchService,
      gadgetService: gadgetService,
    );

    final l10n = AppLocalizations.of(
      tester.element(find.byType(ProjectSettingsPage)),
    )!;

    await tester.tap(find.byIcon(Icons.folder_open).at(0));
    await tester.pumpAndSettle();
    expect(find.text('/tmp/images'), findsOneWidget);

    filePicker.nextDirectoryPath = '/tmp/labels';
    await tester.tap(find.byIcon(Icons.folder_open).at(1));
    await tester.pumpAndSettle();
    expect(find.text('/tmp/labels'), findsOneWidget);

    expect(find.textContaining(l10n.labelTypeBoxWithPoint), findsWidgets);
    expect(find.textContaining(l10n.labelTypePolygon), findsWidgets);
  });

  testWidgets('ProjectSettingsPage export handles empty and errors',
      (tester) async {
    await runWithFlutterErrorsSuppressed(() async {
      final listProvider = StubProjectListProvider();
      final projectProvider = StubProjectProvider();
      final filePicker = FakeFilePickerService()
        ..nextSavePath = '/tmp/export.json';
      final labelIo = FakeLabelDefinitionIo()..throwOnExport = true;
      final imageRepository = FakeImageRepository();
      final batchService =
          FakeBatchInferenceService(const BatchInferenceSummary(
        modelLoaded: true,
        definitions: [],
        inferredImages: {},
        totalImages: 0,
        processedImages: 0,
      ));
      final gadgetService = FakeGadgetService();

      await _pumpSettingsPage(
        tester,
        listProvider: listProvider,
        projectProvider: projectProvider,
        filePicker: filePicker,
        labelIo: labelIo,
        imageRepository: imageRepository,
        batchService: batchService,
        gadgetService: gadgetService,
      );

      final l10n = AppLocalizations.of(
        tester.element(find.byType(ProjectSettingsPage)),
      )!;

      await tester.tap(find.byIcon(Icons.file_download));
      await tester.pumpAndSettle();
      expect(find.text(l10n.noLabelsToExport), findsOneWidget);

      final addDialog = LabelDefinition(
        classId: 0,
        name: 'Class0',
        color: Colors.red,
      );
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(AlertDialog))).pop(addDialog);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.file_download));
      await tester.pumpAndSettle();
      expect(find.textContaining(l10n.exportFailed), findsOneWidget);
    });
  });

  testWidgets('ProjectSettingsPage import error shows toast', (tester) async {
    await runWithFlutterErrorsSuppressed(() async {
      final listProvider = StubProjectListProvider();
      final projectProvider = StubProjectProvider();
      final filePicker = FakeFilePickerService()..nextPickPath = '/tmp/in.json';
      final labelIo = FakeLabelDefinitionIo()..throwOnImport = true;
      final imageRepository = FakeImageRepository();
      final batchService =
          FakeBatchInferenceService(const BatchInferenceSummary(
        modelLoaded: true,
        definitions: [],
        inferredImages: {},
        totalImages: 0,
        processedImages: 0,
      ));
      final gadgetService = FakeGadgetService();

      await _pumpSettingsPage(
        tester,
        listProvider: listProvider,
        projectProvider: projectProvider,
        filePicker: filePicker,
        labelIo: labelIo,
        imageRepository: imageRepository,
        batchService: batchService,
        gadgetService: gadgetService,
      );

      final l10n = AppLocalizations.of(
        tester.element(find.byType(ProjectSettingsPage)),
      )!;

      await tester.tap(find.byIcon(Icons.file_upload));
      await tester.pumpAndSettle();
      expect(find.textContaining(l10n.importFailed), findsOneWidget);
    });
  });

  testWidgets('ProjectSettingsPage cancels delete without label path',
      (tester) async {
    final project = ProjectConfig(
      id: 'p1',
      name: 'Project',
      labelDefinitions: [
        LabelDefinition(
          classId: 0,
          name: 'Label0',
          color: Colors.red,
        ),
      ],
    );
    final listProvider = StubProjectListProvider();
    final projectProvider = StubProjectProvider();
    final filePicker = FakeFilePickerService();
    final labelIo = FakeLabelDefinitionIo();
    final imageRepository = FakeImageRepository();
    final batchService = FakeBatchInferenceService(const BatchInferenceSummary(
      modelLoaded: true,
      definitions: [],
      inferredImages: {},
      totalImages: 0,
      processedImages: 0,
    ));
    final gadgetService = FakeGadgetService();

    await _pumpSettingsPage(
      tester,
      project: project,
      listProvider: listProvider,
      projectProvider: projectProvider,
      filePicker: filePicker,
      labelIo: labelIo,
      imageRepository: imageRepository,
      batchService: batchService,
      gadgetService: gadgetService,
    );

    final l10n = AppLocalizations.of(
      tester.element(find.byType(ProjectSettingsPage)),
    )!;

    final labelTile = find.widgetWithText(ListTile, 'Label0');
    await tester.tap(
      find.descendant(of: labelTile, matching: find.byIcon(Icons.delete)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.cancel));
    await tester.pumpAndSettle();
    expect(find.text('Label0'), findsOneWidget);
    expect(gadgetService.deleteCalls, 0);
  });

  testWidgets('ProjectSettingsPage batch inference requires paths',
      (tester) async {
    final project = ProjectConfig(
      id: 'p1',
      name: 'Project',
      aiConfig: AiConfig(modelPath: '/tmp/model.onnx'),
    );
    final listProvider = StubProjectListProvider();
    final projectProvider = StubProjectProvider();
    final filePicker = FakeFilePickerService()
      ..nextDirectoryPath = '/tmp/images';
    final labelIo = FakeLabelDefinitionIo();
    final imageRepository = FakeImageRepository(imagePaths: []);
    final batchService = FakeBatchInferenceService(const BatchInferenceSummary(
      modelLoaded: true,
      definitions: [],
      inferredImages: {},
      totalImages: 0,
      processedImages: 0,
    ));
    final gadgetService = FakeGadgetService();

    await _pumpSettingsPage(
      tester,
      project: project,
      listProvider: listProvider,
      projectProvider: projectProvider,
      filePicker: filePicker,
      labelIo: labelIo,
      imageRepository: imageRepository,
      batchService: batchService,
      gadgetService: gadgetService,
    );

    final l10n = AppLocalizations.of(
      tester.element(find.byType(ProjectSettingsPage)),
    )!;

    final runButton =
        find.byWidgetPredicate((widget) => widget is ElevatedButton);
    await Scrollable.ensureVisible(
      tester.element(runButton),
      alignment: 0.1,
    );
    await tester.tap(runButton);
    await tester.pumpAndSettle();
    expect(find.text(l10n.imageDir), findsWidgets);

    await tester.ensureVisible(find.byIcon(Icons.folder_open).at(0));
    await tester.tap(find.byIcon(Icons.folder_open).at(0));
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(
      tester.element(runButton),
      alignment: 0.1,
    );
    await tester.tap(runButton);
    await tester.pumpAndSettle();
    expect(find.text(l10n.labelDir), findsWidgets);
  });

  testWidgets('ProjectSettingsPage handles batch inference exception',
      (tester) async {
    await runWithFlutterErrorsSuppressed(() async {
      final project = ProjectConfig(
        id: 'p1',
        name: 'Project',
        imagePath: '/tmp/images',
        labelPath: '/tmp/labels',
        aiConfig: AiConfig(modelPath: '/tmp/model.onnx'),
      );
      final listProvider = StubProjectListProvider();
      final projectProvider = StubProjectProvider();
      final filePicker = FakeFilePickerService();
      final labelIo = FakeLabelDefinitionIo();
      final imageRepository =
          FakeImageRepository(imagePaths: ['/tmp/img1.jpg']);
      final batchService =
          FakeBatchInferenceService(const BatchInferenceSummary(
        modelLoaded: true,
        definitions: [],
        inferredImages: {},
        totalImages: 1,
        processedImages: 0,
      ))
            ..throwOnRun = true;
      final gadgetService = FakeGadgetService();

      await _pumpSettingsPage(
        tester,
        project: project,
        listProvider: listProvider,
        projectProvider: projectProvider,
        filePicker: filePicker,
        labelIo: labelIo,
        imageRepository: imageRepository,
        batchService: batchService,
        gadgetService: gadgetService,
      );

      final l10n = AppLocalizations.of(
        tester.element(find.byType(ProjectSettingsPage)),
      )!;

      final runButton =
          find.byWidgetPredicate((widget) => widget is ElevatedButton);
      await Scrollable.ensureVisible(
        tester.element(runButton),
        alignment: 0.1,
      );
      await tester.tap(runButton);
      await tester.pumpAndSettle();
      final message =
          const AppError(AppErrorCode.aiInferenceFailed).message(l10n);
      expect(find.textContaining(message.trim()), findsWidgets);
    });
  });

  testWidgets('ProjectSettingsPage deletes label and calls gadget service',
      (tester) async {
    final project = ProjectConfig(
      id: 'p1',
      name: 'Project',
      labelPath: '/tmp/labels',
      labelDefinitions: [
        LabelDefinition(
          classId: 0,
          name: 'Label0',
          color: Colors.red,
        ),
      ],
    );
    final listProvider = StubProjectListProvider();
    final projectProvider = StubProjectProvider();
    final filePicker = FakeFilePickerService();
    final labelIo = FakeLabelDefinitionIo();
    final imageRepository = FakeImageRepository();
    final batchService = FakeBatchInferenceService(const BatchInferenceSummary(
      modelLoaded: true,
      definitions: [],
      inferredImages: {},
      totalImages: 0,
      processedImages: 0,
    ));
    final gadgetService = FakeGadgetService()..deleteResult = (1, 2);

    await _pumpSettingsPage(
      tester,
      project: project,
      listProvider: listProvider,
      projectProvider: projectProvider,
      filePicker: filePicker,
      labelIo: labelIo,
      imageRepository: imageRepository,
      batchService: batchService,
      gadgetService: gadgetService,
    );

    await tester.tap(find.byIcon(Icons.delete));
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(ProjectSettingsPage)),
    )!;
    await tester.tap(find.text(l10n.delete));
    await tester.pumpAndSettle();
    expect(gadgetService.deleteCalls, 1);
    expect(find.text(l10n.labelsDeletedFromFiles(2, 1)), findsOneWidget);
  });

  testWidgets('ProjectSettingsPage shows model load failed on batch inference',
      (tester) async {
    final project = ProjectConfig(
      id: 'p1',
      name: 'Project',
      imagePath: '/tmp/images',
      labelPath: '/tmp/labels',
      aiConfig: AiConfig(modelPath: '/tmp/model.onnx'),
    );
    final listProvider = StubProjectListProvider();
    final projectProvider = StubProjectProvider();
    final filePicker = FakeFilePickerService()
      ..nextDirectoryPath = '/tmp/images';
    final labelIo = FakeLabelDefinitionIo();
    final imageRepository = FakeImageRepository(imagePaths: ['/tmp/img1.jpg']);
    final batchService = FakeBatchInferenceService(const BatchInferenceSummary(
      modelLoaded: false,
      definitions: [],
      inferredImages: {},
      totalImages: 1,
      processedImages: 0,
    ));
    final gadgetService = FakeGadgetService();

    await _pumpSettingsPage(
      tester,
      project: project,
      listProvider: listProvider,
      projectProvider: projectProvider,
      filePicker: filePicker,
      labelIo: labelIo,
      imageRepository: imageRepository,
      batchService: batchService,
      gadgetService: gadgetService,
    );

    final l10n = AppLocalizations.of(
      tester.element(find.byType(ProjectSettingsPage)),
    )!;

    final runButton =
        find.byWidgetPredicate((widget) => widget is ElevatedButton);
    await Scrollable.ensureVisible(
      tester.element(runButton),
      alignment: 0.1,
    );
    await tester.tap(runButton);
    await tester.pumpAndSettle();
    expect(find.text(l10n.modelLoadFailed), findsOneWidget);
  });

  testWidgets('ProjectSettingsPage shows batch inference error',
      (tester) async {
    final project = ProjectConfig(
      id: 'p1',
      name: 'Project',
      imagePath: '/tmp/images',
      labelPath: '/tmp/labels',
      aiConfig: AiConfig(modelPath: '/tmp/model.onnx'),
    );
    final listProvider = StubProjectListProvider();
    final projectProvider = StubProjectProvider();
    final filePicker = FakeFilePickerService()
      ..nextDirectoryPath = '/tmp/images';
    final labelIo = FakeLabelDefinitionIo();
    final imageRepository = FakeImageRepository(imagePaths: ['/tmp/img1.jpg']);
    final batchService = FakeBatchInferenceService(const BatchInferenceSummary(
      modelLoaded: true,
      definitions: [],
      inferredImages: {},
      totalImages: 1,
      processedImages: 1,
      lastError: AppError(AppErrorCode.aiInferenceFailed),
    ));
    final gadgetService = FakeGadgetService();

    await _pumpSettingsPage(
      tester,
      project: project,
      listProvider: listProvider,
      projectProvider: projectProvider,
      filePicker: filePicker,
      labelIo: labelIo,
      imageRepository: imageRepository,
      batchService: batchService,
      gadgetService: gadgetService,
    );

    final l10n = AppLocalizations.of(
      tester.element(find.byType(ProjectSettingsPage)),
    )!;

    final runButton =
        find.byWidgetPredicate((widget) => widget is ElevatedButton);
    await Scrollable.ensureVisible(
      tester.element(runButton),
      alignment: 0.1,
    );
    await tester.tap(runButton);
    await tester.pumpAndSettle();
    expect(
      find.text(const AppError(AppErrorCode.aiInferenceFailed).message(l10n)),
      findsOneWidget,
    );
  });

  testWidgets('ProjectSettingsPage completes batch inference', (tester) async {
    final project = ProjectConfig(
      id: 'p1',
      name: 'Project',
      imagePath: '/tmp/images',
      labelPath: '/tmp/labels',
      aiConfig: AiConfig(modelPath: '/tmp/model.onnx'),
    );
    final listProvider = StubProjectListProvider();
    final projectProvider = StubProjectProvider();
    final filePicker = FakeFilePickerService()
      ..nextDirectoryPath = '/tmp/images';
    final labelIo = FakeLabelDefinitionIo();
    final imageRepository = FakeImageRepository(imagePaths: ['/tmp/img1.jpg']);
    final batchService = FakeBatchInferenceService(
      const BatchInferenceSummary(
        modelLoaded: true,
        definitions: [],
        inferredImages: {},
        totalImages: 1,
        processedImages: 1,
      ),
    );
    final gadgetService = FakeGadgetService();

    await _pumpSettingsPage(
      tester,
      project: project,
      listProvider: listProvider,
      projectProvider: projectProvider,
      filePicker: filePicker,
      labelIo: labelIo,
      imageRepository: imageRepository,
      batchService: batchService,
      gadgetService: gadgetService,
    );

    final l10n = AppLocalizations.of(
      tester.element(find.byType(ProjectSettingsPage)),
    )!;

    final runButton =
        find.byWidgetPredicate((widget) => widget is ElevatedButton);
    await Scrollable.ensureVisible(
      tester.element(runButton),
      alignment: 0.1,
    );
    await tester.tap(runButton);
    await tester.pumpAndSettle();
    expect(find.text(l10n.batchInferenceComplete), findsOneWidget);
  });
}
