import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:label_load/models/label_definition.dart';
import 'package:label_load/models/project.dart';
import 'package:label_load/models/project_config.dart';
import 'package:label_load/providers/canvas_provider.dart';
import 'package:label_load/providers/project_provider.dart';
import 'package:label_load/providers/settings_provider.dart';
import 'package:label_load/services/app/app_error.dart';
import 'package:label_load/services/app/app_services.dart';
import 'package:label_load/services/inference/batch_inference_service.dart';
import 'package:label_load/services/image/image_repository.dart';
import 'package:label_load/services/labels/label_file_repository.dart';
import 'package:label_load/widgets/toolbar/main_toolbar.dart';
import 'package:label_load/pages/project_settings_page.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:label_load/models/ai_config.dart';
import 'package:label_load/models/label.dart';
import '../dialogs/test_helpers.dart' as dialog_helpers;

/// Batch runner stub that returns empty label results.
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

/// Project provider stub with controllable behavior for toolbar actions.
class StubProjectProvider extends ProjectProvider {
  StubProjectProvider({
    Project? project,
    ProjectConfig? projectConfig,
    List<LabelDefinition>? definitions,
    List<Label>? labels,
    bool isDirty = false,
  })  : _projectValue = project,
        _projectConfigValue = projectConfig,
        _definitionsValue = definitions ?? <LabelDefinition>[],
        _labelsValue = labels ?? <Label>[],
        _isDirtyValue = isDirty,
        super();

  Project? _projectValue;
  final ProjectConfig? _projectConfigValue;
  final List<LabelDefinition> _definitionsValue;
  final List<Label> _labelsValue;
  bool _isDirtyValue;
  bool saveResult = true;
  bool saveCalled = false;
  bool loadProjectCalled = false;
  ProjectConfig? loadedConfig;
  Project? projectAfterLoad;
  bool goToResult = true;
  int? lastGoToIndex;
  bool previousResult = true;
  bool nextResult = true;
  int previousCalls = 0;
  int nextCalls = 0;

  @override
  Project? get project => _projectValue;

  @override
  ProjectConfig? get projectConfig => _projectConfigValue;

  @override
  List<LabelDefinition> get labelDefinitions => _definitionsValue;

  @override
  List<Label> get labels => _labelsValue;

  @override
  bool get isDirty => _isDirtyValue;

  void setDirty(bool value) {
    _isDirtyValue = value;
    notifyListeners();
  }

  void setErrorValue(AppError? error) {
    setError(error, notify: false);
  }

  @override
  Future<bool> saveLabels() async {
    saveCalled = true;
    return saveResult;
  }

  @override
  Future<void> loadProject(ProjectConfig config) async {
    loadProjectCalled = true;
    loadedConfig = config;
    if (projectAfterLoad != null) {
      _projectValue = projectAfterLoad;
    }
  }

  @override
  Future<bool> goToImage(int index, {bool autoSave = true}) async {
    lastGoToIndex = index;
    return goToResult;
  }

  @override
  Future<bool> previousImage({bool autoSave = true}) async {
    previousCalls += 1;
    return previousResult;
  }

  @override
  Future<bool> nextImage({bool autoSave = true}) async {
    nextCalls += 1;
    return nextResult;
  }
}

/// In-memory image repository with optional failure mode.
class FakeImageRepository implements ImageRepository {
  FakeImageRepository({this.throwOnDelete = false});

  final bool throwOnDelete;
  final List<String> deletedPaths = [];

  @override
  Future<List<String>> listImagePaths(String directoryPath) async => [];

  @override
  Future<bool> exists(String path) async => false;

  @override
  Future<Uint8List> readBytes(String path) async => Uint8List(0);

  @override
  Future<void> deleteIfExists(String path) async {
    if (throwOnDelete) {
      throw StateError('delete image failed');
    }
    deletedPaths.add(path);
  }
}

/// In-memory label repository with optional failure mode.
class FakeLabelRepository implements LabelFileRepository {
  FakeLabelRepository({this.throwOnDelete = false});

  final bool throwOnDelete;
  final List<String> deletedPaths = [];

  @override
  Future<void> ensureDirectory(String directoryPath) async {}

  @override
  Future<bool> exists(String path) async => false;

  @override
  Future<void> deleteIfExists(String path) async {
    if (throwOnDelete) {
      throw StateError('delete label failed');
    }
    deletedPaths.add(path);
  }

  @override
  Future<(List<Label>, List<String>)> readLabels(
    String labelPath,
    String Function(int p1) getName, {
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

/// Navigator observer to assert pop events.
class TestNavigatorObserver extends NavigatorObserver {
  int popCount = 0;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    popCount += 1;
    super.didPop(route, previousRoute);
  }
}

/// Settings provider stub with in-memory settings store.
SettingsProvider _buildSettingsProvider() {
  final provider = SettingsProvider(
    store: dialog_helpers.FakeSettingsStore(),
    gpuDetector: dialog_helpers.FakeGpuDetector(),
    autoLoad: false,
  );
  return provider;
}

/// Wraps content with MaterialApp + localization.
Widget _wrapApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

/// Builds the toolbar test host with providers and dependencies.
Widget _buildToolbarPage({
  required AppServices services,
  required ProjectProvider projectProvider,
  required CanvasProvider canvasProvider,
  required SettingsProvider settingsProvider,
  ImageRepository? imageRepository,
  LabelFileRepository? labelRepository,
}) {
  return MultiProvider(
    providers: [
      Provider<AppServices>.value(value: services),
      ChangeNotifierProvider<ProjectProvider>.value(value: projectProvider),
      ChangeNotifierProvider<CanvasProvider>.value(value: canvasProvider),
      ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
    ],
    child: Scaffold(
      body: MainToolbar(
        imageRepository: imageRepository,
        labelRepository: labelRepository,
      ),
    ),
  );
}

/// Constructs AppServices with fake inference and batch services.
AppServices _buildServices({BatchInferenceService? batchService}) {
  return AppServices(
    inferenceEngine: dialog_helpers.FakeInferenceEngine(),
    batchInferenceService:
        batchService ?? BatchInferenceService(runner: FakeBatchRunner()),
  );
}

/// Sets a large surface for toolbar layout tests.
Future<void> _setLargeSurface(
  WidgetTester tester, {
  Size size = const Size(1400, 900),
}) async {
  await dialog_helpers.setLargeSurface(tester, size: size);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('MainToolbar passes AppServices batchInferenceService',
      (tester) async {
    await _setLargeSurface(tester);

    final batchService = BatchInferenceService(runner: FakeBatchRunner());
    final services = AppServices(
      inferenceEngine: dialog_helpers.FakeInferenceEngine(),
      batchInferenceService: batchService,
    );

    final project = Project(
      imagePath: '/tmp/images',
      labelPath: '/tmp/labels',
      imageFiles: const ['img1.jpg'],
      currentIndex: 0,
    );
    final config = ProjectConfig(
      id: 'demo',
      name: 'Demo',
      imagePath: project.imagePath,
      labelPath: project.labelPath,
      labelDefinitions: const [],
    );

    final definitions = [
      LabelDefinition(
        classId: 0,
        name: 'cat',
        color: const Color(0xFF000000),
      ),
    ];

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AppServices>.value(value: services),
          ChangeNotifierProvider<ProjectProvider>(
            create: (_) => StubProjectProvider(
              project: project,
              projectConfig: config,
              definitions: definitions,
            ),
          ),
          ChangeNotifierProvider(create: (_) => CanvasProvider()),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: MainToolbar()),
        ),
      ),
    );

    expect(find.byType(ProjectSettingsPage), findsNothing);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    final settings =
        tester.widget<ProjectSettingsPage>(find.byType(ProjectSettingsPage));
    expect(identical(settings.batchInferenceService, batchService), isTrue);
  });

  testWidgets('MainToolbar exit pops when project is clean', (tester) async {
    await _setLargeSurface(tester);
    final observer = TestNavigatorObserver();
    final project = Project(
      imagePath: '/tmp/images',
      labelPath: '/tmp/labels',
      imageFiles: const ['/tmp/images/img1.jpg'],
      currentIndex: 0,
    );
    final config = ProjectConfig(
      id: 'demo',
      name: 'Demo',
      imagePath: project.imagePath,
      labelPath: project.labelPath,
      labelDefinitions: const [],
    );
    final projectProvider = StubProjectProvider(
      project: project,
      projectConfig: config,
      definitions: const [],
      labels: const [],
      isDirty: false,
    );
    final settingsProvider = _buildSettingsProvider();
    final canvasProvider = CanvasProvider();
    final services = _buildServices();

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        navigatorObservers: [observer],
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => _buildToolbarPage(
                    services: services,
                    projectProvider: projectProvider,
                    canvasProvider: canvasProvider,
                    settingsProvider: settingsProvider,
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(MainToolbar), findsOneWidget);

    await tester.tap(find.byIcon(Icons.exit_to_app));
    await tester.pumpAndSettle();

    expect(find.byType(MainToolbar), findsNothing);
    expect(observer.popCount, greaterThan(0));
  });

  testWidgets('MainToolbar exit dialog cancels when dirty', (tester) async {
    await _setLargeSurface(tester);
    final project = Project(
      imagePath: '/tmp/images',
      labelPath: '/tmp/labels',
      imageFiles: const ['/tmp/images/img1.jpg'],
      currentIndex: 0,
    );
    final config = ProjectConfig(
      id: 'demo',
      name: 'Demo',
      imagePath: project.imagePath,
      labelPath: project.labelPath,
      labelDefinitions: const [],
    );
    final projectProvider = StubProjectProvider(
      project: project,
      projectConfig: config,
      definitions: const [],
      labels: const [],
      isDirty: true,
    );
    final settingsProvider = _buildSettingsProvider();
    final canvasProvider = CanvasProvider();
    final services = _buildServices();

    await tester.pumpWidget(
      _wrapApp(
        _buildToolbarPage(
          services: services,
          projectProvider: projectProvider,
          canvasProvider: canvasProvider,
          settingsProvider: settingsProvider,
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.exit_to_app));
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(tester.element(find.byType(MainToolbar)))!;
    expect(find.text(l10n.unsavedChangesTitle), findsOneWidget);

    await tester.tap(find.text(l10n.cancel));
    await tester.pumpAndSettle();

    expect(find.byType(MainToolbar), findsOneWidget);
  });

  testWidgets('MainToolbar exit saves and pops on confirm', (tester) async {
    await _setLargeSurface(tester);
    final observer = TestNavigatorObserver();
    final project = Project(
      imagePath: '/tmp/images',
      labelPath: '/tmp/labels',
      imageFiles: const ['/tmp/images/img1.jpg'],
      currentIndex: 0,
    );
    final config = ProjectConfig(
      id: 'demo',
      name: 'Demo',
      imagePath: project.imagePath,
      labelPath: project.labelPath,
      labelDefinitions: const [],
    );
    final projectProvider = StubProjectProvider(
      project: project,
      projectConfig: config,
      definitions: const [],
      labels: const [],
      isDirty: true,
    );
    final settingsProvider = _buildSettingsProvider();
    final canvasProvider = CanvasProvider();
    final services = _buildServices();

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        navigatorObservers: [observer],
        home: _buildToolbarPage(
          services: services,
          projectProvider: projectProvider,
          canvasProvider: canvasProvider,
          settingsProvider: settingsProvider,
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.exit_to_app));
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(tester.element(find.byType(MainToolbar)))!;
    await tester.tap(find.text(l10n.saveAndExit));
    await tester.pumpAndSettle();

    expect(projectProvider.saveCalled, isTrue);
    expect(find.byType(MainToolbar), findsNothing);
    expect(observer.popCount, greaterThan(0));
  });

  testWidgets('MainToolbar exit stays when save fails', (tester) async {
    await _setLargeSurface(tester);
    final project = Project(
      imagePath: '/tmp/images',
      labelPath: '/tmp/labels',
      imageFiles: const ['/tmp/images/img1.jpg'],
      currentIndex: 0,
    );
    final config = ProjectConfig(
      id: 'demo',
      name: 'Demo',
      imagePath: project.imagePath,
      labelPath: project.labelPath,
      labelDefinitions: const [],
    );
    final projectProvider = StubProjectProvider(
      project: project,
      projectConfig: config,
      definitions: const [],
      labels: const [],
      isDirty: true,
    )..saveResult = false;
    final settingsProvider = _buildSettingsProvider();
    final canvasProvider = CanvasProvider();
    final services = _buildServices();

    await tester.pumpWidget(
      _wrapApp(
        _buildToolbarPage(
          services: services,
          projectProvider: projectProvider,
          canvasProvider: canvasProvider,
          settingsProvider: settingsProvider,
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.exit_to_app));
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(tester.element(find.byType(MainToolbar)))!;
    await tester.tap(find.text(l10n.saveAndExit));
    await tester.pumpAndSettle();

    expect(projectProvider.saveCalled, isTrue);
    expect(find.byType(MainToolbar), findsOneWidget);
  });

  testWidgets('MainToolbar delete removes image and label files',
      (tester) async {
    await _setLargeSurface(tester);
    final project = Project(
      imagePath: '/tmp/images',
      labelPath: '/tmp/labels',
      imageFiles: const [
        '/tmp/images/img1.jpg',
        '/tmp/images/img2.jpg',
      ],
      currentIndex: 1,
    );
    final config = ProjectConfig(
      id: 'demo',
      name: 'Demo',
      imagePath: project.imagePath,
      labelPath: project.labelPath,
      labelDefinitions: const [],
    );
    final projectProvider = StubProjectProvider(
      project: project,
      projectConfig: config,
      definitions: const [],
      labels: const [],
    )..projectAfterLoad = Project(
        imagePath: project.imagePath,
        labelPath: project.labelPath,
        imageFiles: const ['/tmp/images/img1.jpg'],
        currentIndex: 0,
      );
    final settingsProvider = _buildSettingsProvider();
    final canvasProvider = CanvasProvider();
    final services = _buildServices();
    final imageRepo = FakeImageRepository();
    final labelRepo = FakeLabelRepository();

    await tester.pumpWidget(
      _wrapApp(
        _buildToolbarPage(
          services: services,
          projectProvider: projectProvider,
          canvasProvider: canvasProvider,
          settingsProvider: settingsProvider,
          imageRepository: imageRepo,
          labelRepository: labelRepo,
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(tester.element(find.byType(MainToolbar)))!;
    await tester.tap(find.text(l10n.delete));
    await tester.pumpAndSettle();

    expect(imageRepo.deletedPaths, contains('/tmp/images/img2.jpg'));
    expect(labelRepo.deletedPaths, contains('/tmp/labels/img2.txt'));
    expect(projectProvider.loadProjectCalled, isTrue);
    expect(projectProvider.lastGoToIndex, 0);
  });

  testWidgets('MainToolbar delete handles repository failure', (tester) async {
    await _setLargeSurface(tester);
    await dialog_helpers.runWithSuppressedErrors(() async {
      final project = Project(
        imagePath: '/tmp/images',
        labelPath: '/tmp/labels',
        imageFiles: const ['/tmp/images/img1.jpg'],
        currentIndex: 0,
      );
      final config = ProjectConfig(
        id: 'demo',
        name: 'Demo',
        imagePath: project.imagePath,
        labelPath: project.labelPath,
        labelDefinitions: const [],
      );
      final projectProvider = StubProjectProvider(
        project: project,
        projectConfig: config,
        definitions: const [],
        labels: const [],
      );
      final settingsProvider = _buildSettingsProvider();
      final canvasProvider = CanvasProvider();
      final services = _buildServices();
      final imageRepo = FakeImageRepository(throwOnDelete: true);

      await tester.pumpWidget(
        _wrapApp(
          _buildToolbarPage(
            services: services,
            projectProvider: projectProvider,
            canvasProvider: canvasProvider,
            settingsProvider: settingsProvider,
            imageRepository: imageRepo,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      final l10n =
          AppLocalizations.of(tester.element(find.byType(MainToolbar)))!;
      await tester.tap(find.text(l10n.delete));
      await tester.pumpAndSettle();

      expect(projectProvider.loadProjectCalled, isFalse);
    });
  });

  testWidgets('MainToolbar navigation reports error on failure',
      (tester) async {
    await _setLargeSurface(tester);
    final project = Project(
      imagePath: '/tmp/images',
      labelPath: '/tmp/labels',
      imageFiles: const [
        '/tmp/images/img1.jpg',
        '/tmp/images/img2.jpg',
      ],
      currentIndex: 1,
    );
    final config = ProjectConfig(
      id: 'demo',
      name: 'Demo',
      imagePath: project.imagePath,
      labelPath: project.labelPath,
      labelDefinitions: const [],
    );
    final projectProvider = StubProjectProvider(
      project: project,
      projectConfig: config,
      definitions: const [],
      labels: const [],
    )
      ..previousResult = false
      ..setErrorValue(const AppError(AppErrorCode.ioOperationFailed));
    final settingsProvider = _buildSettingsProvider();
    final canvasProvider = CanvasProvider();
    final services = _buildServices();

    await tester.pumpWidget(
      _wrapApp(
        _buildToolbarPage(
          services: services,
          projectProvider: projectProvider,
          canvasProvider: canvasProvider,
          settingsProvider: settingsProvider,
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(projectProvider.previousCalls, 1);
  });

  testWidgets('MainToolbar save shows success and failure paths',
      (tester) async {
    await _setLargeSurface(tester);
    final project = Project(
      imagePath: '/tmp/images',
      labelPath: '/tmp/labels',
      imageFiles: const ['/tmp/images/img1.jpg'],
      currentIndex: 0,
    );
    final config = ProjectConfig(
      id: 'demo',
      name: 'Demo',
      imagePath: project.imagePath,
      labelPath: project.labelPath,
      labelDefinitions: const [],
    );
    final projectProvider = StubProjectProvider(
      project: project,
      projectConfig: config,
      definitions: const [],
      labels: const [],
    );
    final settingsProvider = _buildSettingsProvider();
    final canvasProvider = CanvasProvider();
    final services = _buildServices();

    await tester.pumpWidget(
      _wrapApp(
        _buildToolbarPage(
          services: services,
          projectProvider: projectProvider,
          canvasProvider: canvasProvider,
          settingsProvider: settingsProvider,
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.save_outlined));
    await tester.pumpAndSettle();
    expect(projectProvider.saveCalled, isTrue);

    projectProvider.saveCalled = false;
    projectProvider.saveResult = false;
    await tester.tap(find.byIcon(Icons.save_outlined));
    await tester.pumpAndSettle();
    expect(projectProvider.saveCalled, isTrue);
  });

  testWidgets('MainToolbar class selector defaults and updates',
      (tester) async {
    await _setLargeSurface(tester);
    final project = Project(
      imagePath: '/tmp/images',
      labelPath: '/tmp/labels',
      imageFiles: const ['/tmp/images/img1.jpg'],
      currentIndex: 0,
    );
    final config = ProjectConfig(
      id: 'demo',
      name: 'Demo',
      imagePath: project.imagePath,
      labelPath: project.labelPath,
      labelDefinitions: const [],
    );
    final definitions = [
      LabelDefinition(
        classId: 1,
        name: 'cat',
        color: const Color(0xFF000000),
      ),
      LabelDefinition(
        classId: 2,
        name: 'dog',
        color: const Color(0xFF111111),
      ),
    ];
    final projectProvider = StubProjectProvider(
      project: project,
      projectConfig: config,
      definitions: definitions,
      labels: const [],
    );
    final settingsProvider = _buildSettingsProvider();
    final canvasProvider = CanvasProvider()..setCurrentClassId(99);
    final services = _buildServices();

    await tester.pumpWidget(
      _wrapApp(
        _buildToolbarPage(
          services: services,
          projectProvider: projectProvider,
          canvasProvider: canvasProvider,
          settingsProvider: settingsProvider,
        ),
      ),
    );

    await tester.pump();
    expect(canvasProvider.currentClassId, 1);

    await tester.tap(find.byType(PopupMenuButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2. dog'));
    await tester.pumpAndSettle();

    expect(canvasProvider.currentClassId, 2);
  });

  testWidgets('MainToolbar shows empty class selector and no project state',
      (tester) async {
    await _setLargeSurface(tester);
    final settingsProvider = _buildSettingsProvider();
    final canvasProvider = CanvasProvider();
    final services = _buildServices();
    final projectProvider = StubProjectProvider(
      project: null,
      projectConfig: null,
      definitions: const [],
      labels: const [],
    );

    await tester.pumpWidget(
      _wrapApp(
        _buildToolbarPage(
          services: services,
          projectProvider: projectProvider,
          canvasProvider: canvasProvider,
          settingsProvider: settingsProvider,
        ),
      ),
    );

    final l10n = AppLocalizations.of(tester.element(find.byType(MainToolbar)))!;
    expect(find.text(l10n.noProjectOpen), findsOneWidget);
    expect(find.text(l10n.noClasses), findsOneWidget);
  });
}
