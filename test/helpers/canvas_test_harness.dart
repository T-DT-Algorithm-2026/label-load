import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import 'package:label_load/models/ai_config.dart';
import 'package:label_load/models/config.dart';
import 'package:label_load/models/label.dart';
import 'package:label_load/models/label_definition.dart';
import 'package:label_load/providers/canvas_provider.dart';
import 'package:label_load/providers/keybindings_provider.dart';
import 'package:label_load/providers/project_provider.dart';
import 'package:label_load/providers/settings_provider.dart';
import 'package:label_load/services/app/app_services.dart';
import 'package:label_load/services/gpu/gpu_detector.dart';
import 'package:label_load/services/gpu/gpu_info.dart';
import 'package:label_load/services/image/image_repository.dart';
import 'package:label_load/services/inference/inference_engine.dart';
import 'package:label_load/services/input/input_action_gate.dart';
import 'package:label_load/services/input/keyboard_state_reader.dart';
import 'package:label_load/services/input/keybindings_store.dart';
import 'package:label_load/services/inference/project_inference_controller.dart';
import 'package:label_load/services/settings/settings_store.dart';
import 'package:label_load/services/input/side_button_service.dart';
import 'package:label_load/services/settings/theme_store.dart';
import 'package:label_load/widgets/canvas/image_canvas.dart';

export 'package:flutter/gestures.dart';
export 'package:flutter/material.dart';
export 'package:flutter/services.dart';
export 'package:flutter_test/flutter_test.dart';
export 'package:flutter_gen/gen_l10n/app_localizations.dart';
export 'package:provider/provider.dart';

export 'package:label_load/models/ai_config.dart';
export 'package:label_load/models/config.dart';
export 'package:label_load/models/label.dart';
export 'package:label_load/models/label_definition.dart';
export 'package:label_load/providers/canvas_provider.dart';
export 'package:label_load/providers/keybindings_provider.dart';
export 'package:label_load/providers/project_provider.dart';
export 'package:label_load/providers/settings_provider.dart';
export 'package:label_load/services/app/app_services.dart';
export 'package:label_load/services/gpu/gpu_detector.dart';
export 'package:label_load/services/gpu/gpu_info.dart';
export 'package:label_load/services/image/image_repository.dart';
export 'package:label_load/services/inference/inference_engine.dart';
export 'package:label_load/services/input/input_action_gate.dart';
export 'package:label_load/services/input/keyboard_state_reader.dart';
export 'package:label_load/services/input/keybindings_store.dart';
export 'package:label_load/services/inference/project_inference_controller.dart';
export 'package:label_load/services/settings/settings_store.dart';
export 'package:label_load/services/input/side_button_service.dart';
export 'package:label_load/services/settings/theme_store.dart';
export 'package:label_load/widgets/canvas/image_canvas.dart';

/// Shared harness for ImageCanvas widget tests.
///
/// Provides fake services, providers, and helpers to keep test files focused on
/// behavior rather than setup boilerplate.
final Uint8List testPngBytes = File('assets/icon.png').readAsBytesSync();

class FakeImageRepository implements ImageRepository {
  FakeImageRepository(this.bytes);

  final Uint8List bytes;

  @override
  Future<List<String>> listImagePaths(String directoryPath) async => [];

  @override
  Future<bool> exists(String path) async => true;

  @override
  Future<Uint8List> readBytes(String path) async => bytes;

  @override
  Future<void> deleteIfExists(String path) async {}
}

class FakeSettingsStore implements SettingsStore {
  @override
  Future<bool?> getBool(String key) async => null;

  @override
  Future<double?> getDouble(String key) async => null;

  @override
  Future<int?> getInt(String key) async => null;

  @override
  Future<void> setBool(String key, bool value) async {}

  @override
  Future<void> setDouble(String key, double value) async {}

  @override
  Future<void> setInt(String key, int value) async {}
}

class FakeThemeStore implements ThemeStore {
  @override
  Future<bool?> readIsDark() async => null;

  @override
  Future<void> writeIsDark(bool value) async {}
}

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
        deviceName: 'None',
        cudaDeviceCount: 0,
      ),
      providers: 'CPUExecutionProvider',
    );
  }
}

class FakeKeyBindingsStore implements KeyBindingsStore {
  @override
  Future<String?> read() async => null;

  @override
  Future<void> write(String value) async {}
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

class ConfigurableKeyboardStateReader implements KeyboardStateReader {
  ConfigurableKeyboardStateReader({
    this.controlPressed = false,
    this.shiftPressed = false,
    this.altPressed = false,
    Set<LogicalKeyboardKey>? pressedKeys,
  }) : _pressedKeys = pressedKeys ?? <LogicalKeyboardKey>{};

  bool controlPressed;
  bool shiftPressed;
  bool altPressed;
  final Set<LogicalKeyboardKey> _pressedKeys;

  @override
  bool get isAltPressed => altPressed;

  @override
  bool get isControlPressed => controlPressed;

  @override
  bool get isMetaPressed => false;

  @override
  bool get isShiftPressed => shiftPressed;

  @override
  Set<LogicalKeyboardKey> get logicalKeysPressed => _pressedKeys;
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
      deviceName: 'None',
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

class FakeInputActionGate implements InputActionGate {
  @override
  bool shouldHandle(BindableAction action, InputSource source,
          {Duration window = const Duration(milliseconds: 30)}) =>
      true;

  @override
  void reset() {}
}

class BlockingInputActionGate implements InputActionGate {
  BlockingInputActionGate(this.blockedActions);

  final Set<BindableAction> blockedActions;

  @override
  bool shouldHandle(BindableAction action, InputSource source,
          {Duration window = const Duration(milliseconds: 30)}) =>
      !blockedActions.contains(action);

  @override
  void reset() {}
}

class FakeSideButtonService implements SideButtonService {
  final StreamController<SideButtonEvent> _controller =
      StreamController<SideButtonEvent>.broadcast();

  @override
  Stream<SideButtonEvent> get stream => _controller.stream;

  void emit(SideButtonEvent event) => _controller.add(event);

  void dispose() => _controller.close();
}

class TestProjectProvider extends ProjectProvider {
  TestProjectProvider({
    required String? imagePath,
    required List<LabelDefinition> definitions,
    List<Label>? labels,
    AppConfig? config,
  })  : _imagePath = imagePath,
        _labels = labels ?? <Label>[],
        _definitions = definitions,
        _config = config ??
            AppConfig(
              classNames: definitions.map((d) => d.name).toList(),
            ),
        super(
          inferenceController:
              ProjectInferenceController(runner: FakeInferenceRunner()),
        );

  String? _imagePath;
  final List<Label> _labels;
  final List<LabelDefinition> _definitions;
  AppConfig _config;

  int undoCalls = 0;
  int redoCalls = 0;
  int historyCalls = 0;
  bool _canUndo = false;
  bool _canRedo = false;

  @override
  String? get currentImagePath => _imagePath;

  void setImagePath(String? value) {
    _imagePath = value;
    notifyListeners();
  }

  @override
  List<LabelDefinition> get labelDefinitions => _definitions;

  @override
  List<Label> get labels => _labels;

  @override
  AppConfig get config => _config;

  void setConfig(AppConfig config) {
    _config = config;
  }

  @override
  LabelDefinition? getLabelDefinition(int classId) {
    return _definitions.findByClassId(classId);
  }

  @override
  String labelNameForClass(int classId) {
    return _definitions.nameForClassId(classId);
  }

  @override
  Label createLabelFromRect(int classId, Rect rect) {
    final label = Label(
      id: classId,
      name: labelNameForClass(classId),
    );
    label.setFromCorners(rect.left, rect.top, rect.right, rect.bottom);
    return label;
  }

  @override
  void addLabel(Label label) {
    _labels.add(label);
    notifyListeners();
  }

  @override
  void updateLabel(int index, Label label,
      {bool addToHistory = true, bool notify = true}) {
    _labels[index] = label;
    if (notify) {
      notifyListeners();
    }
  }

  @override
  void removeLabel(int index) {
    _labels.removeAt(index);
    notifyListeners();
  }

  @override
  void notifyLabelChange() {
    notifyListeners();
  }

  @override
  bool get canUndo => _canUndo;

  @override
  bool get canRedo => _canRedo;

  void setUndoRedo({required bool canUndo, required bool canRedo}) {
    _canUndo = canUndo;
    _canRedo = canRedo;
  }

  @override
  void undo() {
    undoCalls += 1;
  }

  @override
  void redo() {
    redoCalls += 1;
  }

  @override
  void addToHistory() {
    historyCalls += 1;
  }
}

Size _readPngSize(Uint8List bytes) {
  if (bytes.length < 24) return Size.zero;
  int readInt(int offset) {
    return (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
  }

  return Size(
    readInt(16).toDouble(),
    readInt(20).toDouble(),
  );
}

final Size testImageSize = _readPngSize(testPngBytes);

Offset globalFromNormalized(WidgetTester tester, Offset normalized) {
  final viewer =
      tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
  final viewerRect = tester.getRect(find.byType(InteractiveViewer));
  final matrix = viewer.transformationController!.value;
  final scale = matrix.entry(0, 0);
  final tx = matrix.entry(0, 3);
  final ty = matrix.entry(1, 3);
  final local = Offset(
    normalized.dx * testImageSize.width,
    normalized.dy * testImageSize.height,
  );
  final viewport = Offset(local.dx * scale + tx, local.dy * scale + ty);
  return Offset(viewerRect.left + viewport.dx, viewerRect.top + viewport.dy);
}

Future<void> waitForCanvasReady(WidgetTester tester) async {
  for (int i = 0; i < 50; i++) {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    await tester.pump(const Duration(milliseconds: 20));
    final paints = find.byType(CustomPaint);
    final viewers = find.byType(InteractiveViewer);
    if (paints.evaluate().isNotEmpty && viewers.evaluate().isNotEmpty) {
      final viewer = tester.widget<InteractiveViewer>(viewers.first);
      final matrix = viewer.transformationController?.value;
      if (matrix == null) {
        continue;
      }
      final scale = matrix.entry(0, 0);
      if ((scale - 1.0).abs() > 1e-3) {
        return;
      }
    }
  }
  if (find.byKey(const Key('imageCanvasError')).evaluate().isNotEmpty) {
    fail('Image canvas entered error state during load.');
  }
  if (find.byType(CircularProgressIndicator).evaluate().isNotEmpty) {
    fail('Image canvas remained in loading state.');
  }
  fail('Image canvas did not render within timeout.');
}

Future<void> mouseTapAt(
  WidgetTester tester,
  Offset position, {
  int buttons = kPrimaryMouseButton,
}) async {
  final gesture = await tester.startGesture(
    position,
    kind: PointerDeviceKind.mouse,
    buttons: buttons,
  );
  await tester.pump();
  await gesture.up();
  await tester.pump();
}

Future<void> mouseHoverAt(WidgetTester tester, Offset position) async {
  await tester.sendEventToBinding(
    PointerHoverEvent(
      position: position,
      kind: PointerDeviceKind.mouse,
    ),
  );
  await tester.pump();
}

Future<void> mouseDrag(
  WidgetTester tester,
  Offset start,
  Offset end, {
  int buttons = kPrimaryMouseButton,
}) async {
  await tester.dragFrom(
    start,
    end - start,
    kind: PointerDeviceKind.mouse,
    buttons: buttons,
  );
  await tester.pump();
}

/// Temporarily overrides FlutterError.onError for the duration of [body].
Future<T> runWithFlutterErrorOverride<T>(
  FlutterExceptionHandler? handler,
  Future<T> Function() body,
) async {
  final original = FlutterError.onError;
  FlutterError.onError = handler;
  try {
    return await body();
  } finally {
    FlutterError.onError = original;
  }
}

/// Runs [body] with Flutter error reporting suppressed.
Future<T> runWithFlutterErrorsSuppressed<T>(Future<T> Function() body) {
  return runWithFlutterErrorOverride((_) {}, body);
}

/// Captures Flutter errors raised during [body] and returns them.
Future<T> runWithFlutterErrorsCaptured<T>(
  Future<T> Function(List<FlutterErrorDetails> errors) body,
) async {
  final errors = <FlutterErrorDetails>[];
  return runWithFlutterErrorOverride(errors.add, () => body(errors));
}

AppServices buildServices({
  required SideButtonService sideButtonService,
  required InputActionGate inputActionGate,
  required KeyboardStateReader keyboardStateReader,
}) {
  return AppServices(
    inferenceEngine: FakeInferenceEngine(),
    sideButtonService: sideButtonService,
    inputActionGate: inputActionGate,
    keyboardStateReader: keyboardStateReader,
    settingsStore: FakeSettingsStore(),
    themeStore: FakeThemeStore(),
    keyBindingsStore: FakeKeyBindingsStore(),
  );
}

Widget buildTestApp({
  required AppServices services,
  required ProjectProvider projectProvider,
  required CanvasProvider canvasProvider,
  required SettingsProvider settingsProvider,
  required KeyBindingsProvider keyBindingsProvider,
  required ImageRepository imageRepository,
  InputActionGate? inputActionGate,
  KeyboardStateReader? keyboardStateReader,
  SideButtonService? sideButtonService,
}) {
  return MultiProvider(
    providers: [
      Provider<AppServices>.value(value: services),
      ChangeNotifierProvider<ProjectProvider>.value(value: projectProvider),
      ChangeNotifierProvider<CanvasProvider>.value(value: canvasProvider),
      ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
      ChangeNotifierProvider<KeyBindingsProvider>.value(
        value: keyBindingsProvider,
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 300,
          height: 300,
          child: ImageCanvas(
            imageRepository: imageRepository,
            inputActionGate: inputActionGate,
            keyboardStateReader: keyboardStateReader,
            sideButtonService: sideButtonService,
          ),
        ),
      ),
    ),
  );
}
