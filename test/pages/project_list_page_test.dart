import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import 'package:label_load/models/ai_config.dart';
import 'package:label_load/models/label.dart';
import 'package:label_load/models/label_definition.dart';
import 'package:label_load/models/project_config.dart';
import 'package:label_load/pages/home_page.dart';
import 'package:label_load/pages/project_list_page.dart';
import 'package:label_load/pages/project_settings_page.dart';
import 'package:label_load/providers/canvas_provider.dart';
import 'package:label_load/providers/keybindings_provider.dart';
import 'package:label_load/providers/project_list_provider.dart';
import 'package:label_load/providers/project_provider.dart';
import 'package:label_load/providers/settings_provider.dart';
import 'package:label_load/services/app/app_error.dart';
import 'package:label_load/services/app/app_services.dart';
import 'package:label_load/services/projects/project_cover_finder.dart';
import 'package:label_load/services/image/image_preview_provider.dart';
import 'package:label_load/services/inference/inference_engine.dart';
import 'package:label_load/services/inference/batch_inference_service.dart';
import 'package:label_load/services/gpu/gpu_info.dart';

import 'test_helpers.dart';

class StubSettingsProvider extends SettingsProvider {
  StubSettingsProvider()
      : super(
          autoLoad: false,
          store: FakeSettingsStore(),
          gpuDetector: FakeGpuDetector(),
        );
}

/// Project provider stub capturing the last loaded config.
class StubProjectProvider extends ProjectProvider {
  ProjectConfig? loadedConfig;
  ProjectConfig? pendingUpdate;

  @override
  Future<void> loadProject(ProjectConfig config) async {
    loadedConfig = config;
  }

  @override
  ProjectConfig? get pendingConfigUpdate {
    final update = pendingUpdate;
    pendingUpdate = null;
    return update;
  }
}

/// Project list provider stub with controllable state.
class StubProjectListProvider extends ProjectListProvider {
  StubProjectListProvider({
    List<ProjectConfig>? projects,
    bool isLoading = false,
  })  : _projectsValue = projects ?? <ProjectConfig>[],
        _isLoadingValue = isLoading;

  final List<ProjectConfig> _projectsValue;
  bool _isLoadingValue;
  int loadCalls = 0;
  ProjectConfig? lastUpdated;
  String? removedId;

  @override
  List<ProjectConfig> get projects => _projectsValue;

  @override
  bool get isLoading => _isLoadingValue;

  @override
  Future<void> loadProjects() async {
    loadCalls += 1;
  }

  @override
  Future<void> updateProject(ProjectConfig project) async {
    lastUpdated = project;
  }

  @override
  Future<void> removeProject(String id) async {
    removedId = id;
  }

  void setErrorValue(AppError? error, {bool notify = false}) {
    setError(error, notify: notify);
  }
}

/// Cover finder that always returns the configured path.
class FakeProjectCoverFinder extends ProjectCoverFinder {
  FakeProjectCoverFinder(this.result);

  final String? result;

  @override
  Future<String?> findFirstImagePath(String dirPath) async => result;
}

/// Preview provider that returns a stable in-memory image.
class FakeImagePreviewProvider implements ImagePreviewProvider {
  @override
  ImageProvider<Object> create(String path) {
    return MemoryImage(Uint8List.fromList([0, 1, 2]));
  }
}

/// Minimal inference engine stub for test wiring.
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
  Iterable<dynamic> detect(Uint8List rgbaBytes, int width, int height,
          {required double confThreshold,
          required double nmsThreshold,
          required ModelType modelType,
          required int numKeypoints}) =>
      const [];

  @override
  List<List<dynamic>> detectBatch(
          List<Uint8List> rgbaBytesList, List<(int, int)> sizes,
          {required double confThreshold,
          required double nmsThreshold,
          required ModelType modelType,
          required int numKeypoints}) =>
      const [];

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

/// Pumps the project list page with required providers.
Future<void> _pumpListPage(
  WidgetTester tester, {
  required StubProjectListProvider listProvider,
  required StubProjectProvider projectProvider,
  ProjectCoverFinder? coverFinder,
  ImagePreviewProvider? previewProvider,
}) async {
  await setLargeSurface(tester);
  final keyBindingsProvider = KeyBindingsProvider(
    store: FakeKeyBindingsStore(),
    keyboardStateReader: FakeKeyboardStateReader(),
  );

  final services = AppServices(
    inferenceEngine: FakeInferenceEngine(),
    batchInferenceService: BatchInferenceService(runner: FakeBatchRunner()),
    projectCoverFinder: coverFinder,
    imagePreviewProvider: previewProvider,
  );

  await tester.pumpWidget(
    buildPageTestApp(
      wrapInScaffold: false,
      child: const ProjectListPage(),
      providers: [
        Provider<AppServices>.value(value: services),
        ChangeNotifierProvider<ProjectListProvider>.value(value: listProvider),
        ChangeNotifierProvider<ProjectProvider>.value(value: projectProvider),
        ChangeNotifierProvider<CanvasProvider>(
          create: (_) => CanvasProvider(),
        ),
        ChangeNotifierProvider<KeyBindingsProvider>.value(
          value: keyBindingsProvider,
        ),
        ChangeNotifierProvider<SettingsProvider>(
          create: (_) => StubSettingsProvider(),
        ),
      ],
    ),
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ProjectListPage shows loading/error/empty states',
      (tester) async {
    final listProvider = StubProjectListProvider(isLoading: true);
    await _pumpListPage(
      tester,
      listProvider: listProvider,
      projectProvider: StubProjectProvider(),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    listProvider.setErrorValue(
      const AppError(AppErrorCode.projectListLoadFailed),
    );
    listProvider._isLoadingValue = false;
    listProvider.notifyListeners();
    await tester.pump();
    final l10n =
        AppLocalizations.of(tester.element(find.byType(ProjectListPage)))!;
    expect(
      find.text(
          const AppError(AppErrorCode.projectListLoadFailed).message(l10n)),
      findsOneWidget,
    );

    listProvider.setErrorValue(null);
    listProvider._projectsValue.clear();
    listProvider.notifyListeners();
    await tester.pump();
    expect(find.text(l10n.noProjects), findsOneWidget);
  });

  testWidgets('ProjectListPage opens project and updates pending config',
      (tester) async {
    final project = ProjectConfig(
      id: 'p1',
      name: 'Project One',
      description: 'desc',
      imagePath: '/tmp/images',
      labelPath: '/tmp/labels',
      labelDefinitions: [
        LabelDefinition(
          classId: 0,
          name: 'class0',
          color: Colors.red,
        ),
      ],
    );
    final updated = project.copyWith(name: 'Updated');
    final listProvider = StubProjectListProvider(projects: [project]);
    final projectProvider = StubProjectProvider()..pendingUpdate = updated;

    await _pumpListPage(
      tester,
      listProvider: listProvider,
      projectProvider: projectProvider,
      coverFinder: FakeProjectCoverFinder('/tmp/cover.png'),
      previewProvider: FakeImagePreviewProvider(),
    );

    await tester.pumpAndSettle();
    final card = find.byType(Card);
    await tester.ensureVisible(card);
    await tester.tapAt(tester.getCenter(card));
    await tester.pumpAndSettle();

    expect(projectProvider.loadedConfig, project);
    expect(listProvider.lastUpdated, updated);
    expect(find.byType(HomePage), findsOneWidget);
  });

  testWidgets('ProjectListPage edits and deletes project', (tester) async {
    final project = ProjectConfig(
      id: 'p2',
      name: 'Project Two',
      description: 'desc',
      imagePath: '/tmp/images',
      labelPath: '/tmp/labels',
      labelDefinitions: const [],
    );
    final listProvider = StubProjectListProvider(projects: [project]);
    await _pumpListPage(
      tester,
      listProvider: listProvider,
      projectProvider: StubProjectProvider(),
      coverFinder: FakeProjectCoverFinder(null),
    );

    await tester.pumpAndSettle();

    final card = find.byType(Card);
    final editButton = find.descendant(
      of: card,
      matching: find.byIcon(Icons.settings),
    );
    await tester.tap(editButton);
    await tester.pumpAndSettle();
    expect(find.byType(ProjectSettingsPage), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    final deleteButton = find.descendant(
      of: card,
      matching: find.byIcon(Icons.delete),
    );
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
    final l10n =
        AppLocalizations.of(tester.element(find.byType(ProjectListPage)))!;
    await tester.tap(find.text(l10n.delete));
    await tester.pumpAndSettle();
    expect(listProvider.removedId, project.id);
  });
}
