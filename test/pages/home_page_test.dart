import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import 'package:label_load/models/ai_config.dart';
import 'package:label_load/models/label.dart';
import 'package:label_load/models/project_config.dart';
import 'package:label_load/pages/home_page.dart';
import 'package:label_load/providers/canvas_provider.dart';
import 'package:label_load/providers/keybindings_provider.dart';
import 'package:label_load/providers/project_list_provider.dart';
import 'package:label_load/providers/project_provider.dart';
import 'package:label_load/providers/settings_provider.dart';
import 'package:label_load/services/app/app_error.dart';
import 'package:label_load/services/app/app_services.dart';
import 'package:label_load/services/input/input_action_gate.dart';
import 'package:label_load/services/inference/inference_engine.dart';
import 'package:label_load/services/input/side_button_service.dart';
import 'package:label_load/services/gpu/gpu_info.dart';

import 'test_helpers.dart';

/// Settings provider stub with fixed GPU/autosave values.
class StubSettingsProvider extends SettingsProvider {
  StubSettingsProvider({
    this.useGpuValue = false,
    this.autoSaveValue = true,
  }) : super(
          autoLoad: false,
          store: FakeSettingsStore(),
          gpuDetector: FakeGpuDetector(),
        );

  final bool useGpuValue;
  final bool autoSaveValue;

  @override
  bool get useGpu => useGpuValue;

  @override
  bool get autoSaveOnNavigate => autoSaveValue;
}

/// Project list provider stub capturing updates.
class StubProjectListProvider extends ProjectListProvider {
  ProjectConfig? lastUpdated;

  @override
  Future<void> updateProject(ProjectConfig project) async {
    lastUpdated = project;
  }
}

/// Project provider stub with controllable navigation and labeling behavior.
class TestProjectProvider extends ProjectProvider {
  TestProjectProvider({
    ProjectConfig? projectConfig,
    String? currentImagePath,
    List<Label>? labels,
  })  : _projectConfigValue = projectConfig,
        _currentImagePathValue = currentImagePath,
        _labelsValue = labels ?? <Label>[],
        super();

  ProjectConfig? _projectConfigValue;
  String? _currentImagePathValue;
  final List<Label> _labelsValue;

  ProjectConfig? pendingUpdate;
  bool saveResult = true;
  int saveCalls = 0;

  bool previousResult = true;
  bool nextResult = true;
  int previousCalls = 0;
  int nextCalls = 0;

  int removeLabelCalls = 0;
  int? removedLabelIndex;

  int updateLabelCalls = 0;
  int? updatedLabelIndex;

  bool autoLabelCalled = false;
  bool? lastAutoLabelForce;
  bool? lastAutoLabelUseGpu;
  bool autoLabelAddsLabel = false;
  AppError? autoLabelError;

  bool isImageInferredValue = false;

  @override
  ProjectConfig? get projectConfig => _projectConfigValue;

  @override
  String? get currentImagePath => _currentImagePathValue;

  @override
  List<Label> get labels => _labelsValue;

  @override
  ProjectConfig? get pendingConfigUpdate {
    final update = pendingUpdate;
    pendingUpdate = null;
    return update;
  }

  void setProjectConfig(ProjectConfig? value) {
    _projectConfigValue = value;
    notifyListeners();
  }

  void setCurrentImagePath(String? value) {
    _currentImagePathValue = value;
  }

  void setErrorValue(AppError? error) {
    setError(error, notify: false);
  }

  @override
  Future<bool> saveLabels() async {
    saveCalls += 1;
    return saveResult;
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

  @override
  Future<void> autoLabelCurrent(
      {bool useGpu = false, bool force = false}) async {
    autoLabelCalled = true;
    lastAutoLabelForce = force;
    lastAutoLabelUseGpu = useGpu;
    if (autoLabelError != null) {
      setError(autoLabelError, notify: false);
      return;
    }
    clearError();
    if (autoLabelAddsLabel) {
      _labelsValue.add(Label(id: 0, name: 'auto'));
    }
  }

  @override
  bool isImageInferred(String imagePath) => isImageInferredValue;

  @override
  void removeLabel(int index) {
    removeLabelCalls += 1;
    removedLabelIndex = index;
    if (index >= 0 && index < _labelsValue.length) {
      _labelsValue.removeAt(index);
    }
    notifyListeners();
  }

  @override
  void updateLabel(int index, Label label,
      {bool addToHistory = true, bool notify = true}) {
    updateLabelCalls += 1;
    updatedLabelIndex = index;
    if (index >= 0 && index < _labelsValue.length) {
      _labelsValue[index] = label;
    }
    if (notify) {
      notifyListeners();
    }
  }
}

/// Dispatches a method channel event to the HomePage side button handler.
Future<void> _dispatchSideButton(MethodCall call) async {
  const channel = MethodChannel('side_buttons');
  const codec = StandardMethodCodec();
  final binding = TestDefaultBinaryMessengerBinding.instance;
  final data = codec.encodeMethodCall(call);
  final completer = Completer<void>();

  binding.defaultBinaryMessenger.handlePlatformMessage(
    channel.name,
    data,
    (_) => completer.complete(),
  );

  await completer.future;
}

/// HomePage harness to expose providers after pumping.
class _HomeHarness {
  _HomeHarness({
    required this.projectProvider,
    required this.projectListProvider,
    required this.canvasProvider,
    required this.keyBindingsProvider,
    required this.settingsProvider,
  });

  final TestProjectProvider projectProvider;
  final StubProjectListProvider projectListProvider;
  final CanvasProvider canvasProvider;
  final KeyBindingsProvider keyBindingsProvider;
  final StubSettingsProvider settingsProvider;
}

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

/// Creates a keybindings provider with common HomePage shortcuts.
Future<KeyBindingsProvider> _createKeyBindingsProvider() async {
  final provider = KeyBindingsProvider(
    store: FakeKeyBindingsStore(),
    keyboardStateReader: FakeKeyboardStateReader(),
  );
  final bindings = <BindableAction, KeyBinding>{
    BindableAction.prevImage:
        const KeyBinding.keyboard(LogicalKeyboardKey.keyA),
    BindableAction.nextImage:
        const KeyBinding.keyboard(LogicalKeyboardKey.keyD),
    BindableAction.prevLabel:
        const KeyBinding.keyboard(LogicalKeyboardKey.keyQ),
    BindableAction.nextLabel:
        const KeyBinding.keyboard(LogicalKeyboardKey.keyE),
    BindableAction.deleteSelected:
        const KeyBinding.keyboard(LogicalKeyboardKey.keyX),
    BindableAction.toggleMode:
        const KeyBinding.keyboard(LogicalKeyboardKey.keyM),
    BindableAction.save: const KeyBinding.keyboard(LogicalKeyboardKey.keyS),
    BindableAction.toggleDarkEnhance:
        const KeyBinding.keyboard(LogicalKeyboardKey.keyT),
    BindableAction.aiInference:
        const KeyBinding.keyboard(LogicalKeyboardKey.keyI),
    BindableAction.toggleVisibility:
        const KeyBinding.keyboard(LogicalKeyboardKey.keyV),
    BindableAction.zoomIn: const KeyBinding.mouse(MouseButton.left),
    BindableAction.mouseMove: const KeyBinding.mouse(MouseButton.back),
  };
  for (final entry in bindings.entries) {
    await provider.setBinding(entry.key, entry.value);
  }
  return provider;
}

Future<_HomeHarness> _pumpHomePage(
  WidgetTester tester, {
  TestProjectProvider? projectProvider,
  StubProjectListProvider? projectListProvider,
  StubSettingsProvider? settingsProvider,
}) async {
  await setLargeSurface(tester);
  final keyBindingsProvider = await _createKeyBindingsProvider();

  final resolvedProjectProvider = projectProvider ?? TestProjectProvider();
  final resolvedProjectListProvider =
      projectListProvider ?? StubProjectListProvider();
  final resolvedSettingsProvider = settingsProvider ?? StubSettingsProvider();
  final canvasProvider = CanvasProvider();

  final services = AppServices(
    inferenceEngine: FakeInferenceEngine(),
    sideButtonService: SideButtonService.instance,
    inputActionGate: InputActionGate.instance,
    keyboardStateReader: FakeKeyboardStateReader(),
  );

  await tester.pumpWidget(
    buildPageTestApp(
      wrapInScaffold: false,
      child: const HomePage(),
      providers: [
        Provider<AppServices>.value(value: services),
        ChangeNotifierProvider<ProjectProvider>.value(
          value: resolvedProjectProvider,
        ),
        ChangeNotifierProvider<ProjectListProvider>.value(
          value: resolvedProjectListProvider,
        ),
        ChangeNotifierProvider<CanvasProvider>.value(value: canvasProvider),
        ChangeNotifierProvider<KeyBindingsProvider>.value(
          value: keyBindingsProvider,
        ),
        ChangeNotifierProvider<SettingsProvider>.value(
          value: resolvedSettingsProvider,
        ),
      ],
    ),
  );

  await tester.pump();

  return _HomeHarness(
    projectProvider: resolvedProjectProvider,
    projectListProvider: resolvedProjectListProvider,
    canvasProvider: canvasProvider,
    keyBindingsProvider: keyBindingsProvider,
    settingsProvider: resolvedSettingsProvider,
  );
}

PhysicalKeyboardKey _physicalKey(LogicalKeyboardKey logicalKey) {
  if (logicalKey == LogicalKeyboardKey.keyA) return PhysicalKeyboardKey.keyA;
  if (logicalKey == LogicalKeyboardKey.keyD) return PhysicalKeyboardKey.keyD;
  if (logicalKey == LogicalKeyboardKey.keyQ) return PhysicalKeyboardKey.keyQ;
  if (logicalKey == LogicalKeyboardKey.keyE) return PhysicalKeyboardKey.keyE;
  if (logicalKey == LogicalKeyboardKey.keyX) return PhysicalKeyboardKey.keyX;
  if (logicalKey == LogicalKeyboardKey.keyM) return PhysicalKeyboardKey.keyM;
  if (logicalKey == LogicalKeyboardKey.keyS) return PhysicalKeyboardKey.keyS;
  if (logicalKey == LogicalKeyboardKey.keyT) return PhysicalKeyboardKey.keyT;
  if (logicalKey == LogicalKeyboardKey.keyI) return PhysicalKeyboardKey.keyI;
  if (logicalKey == LogicalKeyboardKey.keyV) return PhysicalKeyboardKey.keyV;
  if (logicalKey == LogicalKeyboardKey.backspace) {
    return PhysicalKeyboardKey.backspace;
  }
  if (logicalKey == LogicalKeyboardKey.browserBack) {
    return PhysicalKeyboardKey.browserBack;
  }
  return PhysicalKeyboardKey.keyA;
}

/// Sends a logical key down event to HomePage's focus handler.
Future<void> _dispatchKeyDown(
  WidgetTester tester,
  LogicalKeyboardKey logicalKey,
) async {
  final focusFinder = find.descendant(
    of: find.byType(HomePage),
    matching: find.byWidgetPredicate(
      (widget) => widget is Focus && widget.onKeyEvent != null,
    ),
  );
  final focus = tester.widget<Focus>(focusFinder.first);
  final node = focus.focusNode ?? FocusNode();
  focus.onKeyEvent?.call(
    node,
    KeyDownEvent(
      logicalKey: logicalKey,
      physicalKey: _physicalKey(logicalKey),
      timeStamp: Duration.zero,
    ),
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('HomePage handles keyboard actions and toasts', (tester) async {
    InputActionGate.instance.reset();
    final labels = [
      Label(
        id: 1,
        name: 'person',
        points: [LabelPoint(x: 0.1, y: 0.1, visibility: 2)],
      ),
      Label(id: 2, name: 'car'),
    ];
    final projectProvider = TestProjectProvider(labels: labels);
    final harness = await _pumpHomePage(
      tester,
      projectProvider: projectProvider,
    );

    harness.canvasProvider.selectLabel(0);
    harness.canvasProvider.setActiveKeypoint(0);

    // Visibility toggle and label selection navigation.
    await _dispatchKeyDown(tester, LogicalKeyboardKey.keyV);
    expect(projectProvider.labels.first.points.first.visibility, 1);

    await _dispatchKeyDown(tester, LogicalKeyboardKey.keyQ);
    expect(harness.canvasProvider.selectedLabelIndex, 1);

    await _dispatchKeyDown(tester, LogicalKeyboardKey.keyE);
    expect(harness.canvasProvider.selectedLabelIndex, 0);

    await _dispatchKeyDown(tester, LogicalKeyboardKey.keyM);
    expect(harness.canvasProvider.isLabelingMode, isTrue);

    // Toasts for dark enhance and save outcomes.
    await _dispatchKeyDown(tester, LogicalKeyboardKey.keyT);
    final l10n = AppLocalizations.of(tester.element(find.byType(HomePage)))!;
    expect(find.text(l10n.darkEnhanceOnToast), findsOneWidget);

    projectProvider.saveResult = true;
    await _dispatchKeyDown(tester, LogicalKeyboardKey.keyS);
    expect(find.text(l10n.labelsSaved), findsOneWidget);

    projectProvider.saveResult = false;
    projectProvider
        .setErrorValue(const AppError(AppErrorCode.ioOperationFailed));
    await _dispatchKeyDown(tester, LogicalKeyboardKey.keyS);
    expect(
      find.text(const AppError(AppErrorCode.ioOperationFailed).message(l10n)),
      findsOneWidget,
    );

    projectProvider.setErrorValue(null);
    await _dispatchKeyDown(tester, LogicalKeyboardKey.keyS);
    expect(
      find.text(const AppError(AppErrorCode.ioOperationFailed).message(l10n)),
      findsOneWidget,
    );

    // AI inference preflight checks and success path.
    projectProvider.setProjectConfig(null);
    await _dispatchKeyDown(tester, LogicalKeyboardKey.keyI);
    expect(find.text(l10n.aiInferenceNoProject), findsOneWidget);

    projectProvider.setProjectConfig(ProjectConfig(
      id: 'p1',
      name: 'proj',
      aiConfig: AiConfig(modelPath: ''),
    ));
    await _dispatchKeyDown(tester, LogicalKeyboardKey.keyI);
    expect(find.text(l10n.aiInferenceNoModel), findsOneWidget);

    projectProvider.autoLabelAddsLabel = true;
    projectProvider.setProjectConfig(ProjectConfig(
      id: 'p1',
      name: 'proj',
      aiConfig: AiConfig(modelPath: '/tmp/model.onnx'),
    ));
    await _dispatchKeyDown(tester, LogicalKeyboardKey.keyI);
    expect(find.text(l10n.aiInferenceComplete(projectProvider.labels.length)),
        findsOneWidget);

    // Delete label via keybindings.
    harness.canvasProvider.selectLabel(0);
    await _dispatchKeyDown(tester, LogicalKeyboardKey.keyX);
    expect(projectProvider.removeLabelCalls, 1);
    expect(harness.canvasProvider.selectedLabelIndex, isNull);

    harness.canvasProvider.selectLabel(0);
    await _dispatchKeyDown(tester, LogicalKeyboardKey.backspace);
    expect(projectProvider.removeLabelCalls, 2);
  });

  testWidgets('HomePage handles navigation and side inputs', (tester) async {
    InputActionGate.instance.reset();
    final projectProvider = TestProjectProvider(
      projectConfig: ProjectConfig(
        id: 'p1',
        name: 'proj',
        aiConfig: AiConfig(modelPath: '/tmp/model.onnx', autoInferOnNext: true),
      ),
      currentImagePath: '/tmp/img1.jpg',
      labels: [Label(id: 1, name: 'person')],
    );
    await _pumpHomePage(tester, projectProvider: projectProvider);

    // Previous navigation reports error toast.
    projectProvider.previousResult = false;
    projectProvider
        .setErrorValue(const AppError(AppErrorCode.imageNotSelected));
    await _dispatchKeyDown(tester, LogicalKeyboardKey.keyA);
    final l10n = AppLocalizations.of(tester.element(find.byType(HomePage)))!;
    expect(
      find.text(const AppError(AppErrorCode.imageNotSelected).message(l10n)),
      findsOneWidget,
    );

    projectProvider.setErrorValue(null);
    projectProvider.nextResult = true;
    projectProvider.autoLabelAddsLabel = true;
    await _dispatchKeyDown(tester, LogicalKeyboardKey.keyD);
    expect(projectProvider.autoLabelCalled, isTrue);
    expect(projectProvider.lastAutoLabelForce, isFalse);
    expect(find.text(l10n.aiInferenceComplete(projectProvider.labels.length)),
        findsOneWidget);

    await _dispatchKeyDown(tester, LogicalKeyboardKey.browserBack);

    // Pointer and side-button events should not crash.
    final gesture = await tester.startGesture(
      const Offset(10, 10),
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryMouseButton,
    );
    await tester.pump();
    await gesture.up();
    await tester.pump();

    await _dispatchSideButton(
      const MethodCall('sideButton', {'button': 'back', 'state': 'down'}),
    );
    await tester.pump();
  });
}
