import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:label_load/models/label.dart';
import 'package:label_load/models/label_definition.dart';
import 'package:label_load/models/project.dart';
import 'package:label_load/providers/canvas_provider.dart';
import 'package:label_load/providers/project_provider.dart';
import 'package:label_load/providers/settings_provider.dart';
import 'package:label_load/services/app/app_error.dart';
import 'package:label_load/services/app/app_services.dart';
import 'package:label_load/services/image/image_preview_provider.dart';
import 'package:label_load/widgets/sidebar/sidebar.dart';
import '../dialogs/test_helpers.dart' as dialog_helpers;

/// Preview provider that returns a stable asset image.
class FakeImagePreviewProvider implements ImagePreviewProvider {
  @override
  ImageProvider<Object> create(String path) {
    return const AssetImage('assets/icon.png');
  }
}

/// Project provider stub for sidebar interactions.
class TestProjectProvider extends ProjectProvider {
  TestProjectProvider({
    Project? project,
    List<LabelDefinition>? definitions,
    List<Label>? labels,
  })  : _projectValue = project,
        _definitionsValue = definitions ?? <LabelDefinition>[],
        _labelsValue = labels ?? <Label>[],
        super();

  final Project? _projectValue;
  final List<LabelDefinition> _definitionsValue;
  final List<Label> _labelsValue;
  bool goToResult = true;
  bool goToCalled = false;
  int? lastGoToIndex;
  bool lastAutoSave = false;

  @override
  Project? get project => _projectValue;

  @override
  List<LabelDefinition> get labelDefinitions => _definitionsValue;

  @override
  List<Label> get labels => _labelsValue;

  @override
  Color getLabelColor(int classId) {
    return _definitionsValue.colorForClassId(classId);
  }

  @override
  LabelDefinition? getLabelDefinition(int classId) {
    return _definitionsValue.findByClassId(classId);
  }

  void setErrorValue(AppError? error) {
    setError(error, notify: false);
  }

  @override
  Future<bool> goToImage(int index, {bool autoSave = true}) async {
    goToCalled = true;
    lastGoToIndex = index;
    lastAutoSave = autoSave;
    return goToResult;
  }

  @override
  void updateLabel(int index, Label label,
      {bool addToHistory = true, bool notify = true}) {
    _labelsValue[index] = label;
    if (notify) {
      notifyListeners();
    }
  }

  @override
  void removeLabel(int index) {
    _labelsValue.removeAt(index);
    notifyListeners();
  }
}

/// Builds a settings provider with fake store and GPU detector.
SettingsProvider _buildSettingsProvider() {
  return SettingsProvider(
    store: dialog_helpers.FakeSettingsStore(),
    gpuDetector: dialog_helpers.FakeGpuDetector(),
    autoLoad: false,
  );
}

/// Wraps the sidebar with required providers and localization.
Widget _wrapSidebarApp({
  required ProjectProvider projectProvider,
  required CanvasProvider canvasProvider,
  required SettingsProvider settingsProvider,
  ImagePreviewProvider? imagePreviewProvider,
}) {
  final services = AppServices(
    inferenceEngine: dialog_helpers.FakeInferenceEngine(),
    imagePreviewProvider:
        imagePreviewProvider ?? const FileImagePreviewProvider(),
  );
  return MultiProvider(
    providers: [
      Provider<AppServices>.value(value: services),
      ChangeNotifierProvider<ProjectProvider>.value(value: projectProvider),
      ChangeNotifierProvider<CanvasProvider>.value(value: canvasProvider),
      ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Sidebar(imagePreviewProvider: imagePreviewProvider),
      ),
    ),
  );
}

/// Sets a large surface size for sidebar layout tests.
Future<void> _setLargeSurface(
  WidgetTester tester, {
  Size size = const Size(1200, 900),
}) async {
  await dialog_helpers.setLargeSurface(tester, size: size);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Sidebar shows empty label state', (tester) async {
    await _setLargeSurface(tester);
    final projectProvider = TestProjectProvider(
      project: Project(
        imagePath: '/tmp/images',
        labelPath: '/tmp/labels',
        imageFiles: const [],
      ),
      definitions: const [],
      labels: const [],
    );
    final canvasProvider = CanvasProvider();
    final settingsProvider = _buildSettingsProvider();

    await tester.pumpWidget(
      _wrapSidebarApp(
        projectProvider: projectProvider,
        canvasProvider: canvasProvider,
        settingsProvider: settingsProvider,
      ),
    );

    final l10n = AppLocalizations.of(tester.element(find.byType(Sidebar)))!;
    expect(find.text(l10n.noLabels), findsOneWidget);
  });

  testWidgets('Sidebar selects and deletes labels', (tester) async {
    await _setLargeSurface(tester);
    final projectProvider = TestProjectProvider(
      project: Project(
        imagePath: '/tmp/images',
        labelPath: '/tmp/labels',
        imageFiles: const ['/tmp/images/img1.jpg'],
      ),
      definitions: [
        LabelDefinition(
          classId: 0,
          name: 'box',
          color: const Color(0xFF111111),
        ),
      ],
      labels: [
        Label(id: 0, x: 0.5, y: 0.5, width: 0.2, height: 0.2),
      ],
    );
    final canvasProvider = CanvasProvider();
    final settingsProvider = _buildSettingsProvider();

    await tester.pumpWidget(
      _wrapSidebarApp(
        projectProvider: projectProvider,
        canvasProvider: canvasProvider,
        settingsProvider: settingsProvider,
      ),
    );

    await tester.tap(find.byType(ListTile).first);
    await tester.pump();
    expect(canvasProvider.selectedLabelIndex, 0);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();
    expect(projectProvider.labels.length, 0);
  });

  testWidgets('Sidebar changes label class with conversion', (tester) async {
    await _setLargeSurface(tester);
    final projectProvider = TestProjectProvider(
      project: Project(
        imagePath: '/tmp/images',
        labelPath: '/tmp/labels',
        imageFiles: const ['/tmp/images/img1.jpg'],
      ),
      definitions: [
        LabelDefinition(
          classId: 0,
          name: 'box',
          color: const Color(0xFF111111),
          type: LabelType.box,
        ),
        LabelDefinition(
          classId: 1,
          name: 'poly',
          color: const Color(0xFF222222),
          type: LabelType.polygon,
        ),
      ],
      labels: [
        Label(id: 0, x: 0.4, y: 0.4, width: 0.2, height: 0.2),
      ],
    );
    final canvasProvider = CanvasProvider();
    final settingsProvider = _buildSettingsProvider();

    await tester.pumpWidget(
      _wrapSidebarApp(
        projectProvider: projectProvider,
        canvasProvider: canvasProvider,
        settingsProvider: settingsProvider,
      ),
    );

    await tester.tap(find.text('box'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('poly'));
    await tester.pumpAndSettle();

    expect(projectProvider.labels.first.id, 1);
    expect(projectProvider.labels.first.points.length, 4);
  });

  testWidgets('Sidebar reorders points and updates active index',
      (tester) async {
    await _setLargeSurface(tester);
    final projectProvider = TestProjectProvider(
      project: Project(
        imagePath: '/tmp/images',
        labelPath: '/tmp/labels',
        imageFiles: const ['/tmp/images/img1.jpg'],
      ),
      definitions: [
        LabelDefinition(
          classId: 0,
          name: 'poly',
          color: const Color(0xFF111111),
          type: LabelType.polygon,
        ),
      ],
      labels: [
        Label(
          id: 0,
          points: [
            LabelPoint(x: 0.1, y: 0.1),
            LabelPoint(x: 0.2, y: 0.2),
            LabelPoint(x: 0.3, y: 0.3),
          ],
        )..updateBboxFromPoints(),
      ],
    );
    final canvasProvider = CanvasProvider()
      ..selectLabel(0)
      ..setActiveKeypoint(0);
    final settingsProvider = _buildSettingsProvider();

    await tester.pumpWidget(
      _wrapSidebarApp(
        projectProvider: projectProvider,
        canvasProvider: canvasProvider,
        settingsProvider: settingsProvider,
      ),
    );

    final list =
        tester.widget<ReorderableListView>(find.byType(ReorderableListView));
    list.onReorder(0, 2);
    await tester.pump();

    expect(projectProvider.labels.first.points[1].x, 0.1);
    expect(canvasProvider.activeKeypointIndex, 1);
  });

  testWidgets('Sidebar selects keypoint from point tile', (tester) async {
    await _setLargeSurface(tester);
    final projectProvider = TestProjectProvider(
      project: Project(
        imagePath: '/tmp/images',
        labelPath: '/tmp/labels',
        imageFiles: const ['/tmp/images/img1.jpg'],
      ),
      definitions: [
        LabelDefinition(
          classId: 0,
          name: 'poly',
          color: const Color(0xFF111111),
          type: LabelType.polygon,
        ),
      ],
      labels: [
        Label(
          id: 0,
          points: [
            LabelPoint(x: 0.1, y: 0.1),
          ],
        )..updateBboxFromPoints(),
      ],
    );
    final canvasProvider = CanvasProvider();
    final settingsProvider = _buildSettingsProvider();

    await tester.pumpWidget(
      _wrapSidebarApp(
        projectProvider: projectProvider,
        canvasProvider: canvasProvider,
        settingsProvider: settingsProvider,
      ),
    );

    await tester.tap(find.text('(0.100, 0.100)'));
    await tester.pump();

    expect(canvasProvider.selectedLabelIndex, 0);
    expect(canvasProvider.activeKeypointIndex, 0);
  });

  testWidgets('Sidebar shows empty image state', (tester) async {
    await _setLargeSurface(tester);
    final projectProvider = TestProjectProvider(
      project: null,
      definitions: const [],
      labels: const [],
    );
    final canvasProvider = CanvasProvider();
    final settingsProvider = _buildSettingsProvider();

    await tester.pumpWidget(
      _wrapSidebarApp(
        projectProvider: projectProvider,
        canvasProvider: canvasProvider,
        settingsProvider: settingsProvider,
      ),
    );

    final l10n = AppLocalizations.of(tester.element(find.byType(Sidebar)))!;
    await tester.tap(find.text(l10n.tabImages));
    await tester.pumpAndSettle();

    expect(find.text(l10n.noImagesLoaded), findsOneWidget);
  });

  testWidgets('Sidebar image tap uses auto-save and handles error',
      (tester) async {
    await _setLargeSurface(tester);
    final projectProvider = TestProjectProvider(
      project: Project(
        imagePath: '/tmp/images',
        labelPath: '/tmp/labels',
        imageFiles: const [
          '/tmp/images/img1.jpg',
          '/tmp/images/img2.jpg',
        ],
      ),
      definitions: const [],
      labels: const [],
    )
      ..goToResult = false
      ..setErrorValue(const AppError(AppErrorCode.ioOperationFailed));
    final canvasProvider = CanvasProvider();
    final settingsProvider = _buildSettingsProvider();
    await settingsProvider.setAutoSaveOnNavigate(true);

    await tester.pumpWidget(
      _wrapSidebarApp(
        projectProvider: projectProvider,
        canvasProvider: canvasProvider,
        settingsProvider: settingsProvider,
        imagePreviewProvider: FakeImagePreviewProvider(),
      ),
    );

    final l10n = AppLocalizations.of(tester.element(find.byType(Sidebar)))!;
    await tester.tap(find.text(l10n.tabImages));
    await tester.pumpAndSettle();

    await tester.tap(find.text('img1.jpg'));
    await tester.pumpAndSettle();

    expect(projectProvider.goToCalled, isTrue);
    expect(projectProvider.lastAutoSave, isTrue);
    expect(projectProvider.lastGoToIndex, 0);
  });
}
