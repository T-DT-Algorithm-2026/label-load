import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:label_load/main.dart';
import 'package:label_load/models/ai_config.dart';
import 'package:label_load/models/project_config.dart';
import 'package:label_load/pages/project_list_page.dart';
import 'package:label_load/services/app/app_services.dart';
import 'package:label_load/services/gpu/gpu_detector.dart';
import 'package:label_load/services/gpu/gpu_info.dart';
import 'package:label_load/services/inference/inference_engine.dart';
import 'package:label_load/services/input/keybindings_store.dart';
import 'package:label_load/services/input/keyboard_state_reader.dart';
import 'package:label_load/services/projects/project_list_repository.dart';
import 'package:label_load/services/settings/settings_store.dart';
import 'package:label_load/services/settings/theme_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Inference engine stub that toggles model state.
class FakeInferenceEngine implements InferenceEngine {
  bool _hasModel = false;

  @override
  bool get hasModel => _hasModel;

  @override
  bool initialize() => true;

  @override
  bool loadModel(String path, {bool useGpu = false}) {
    _hasModel = true;
    return true;
  }

  @override
  void unloadModel() {
    _hasModel = false;
  }

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
    return const [];
  }

  @override
  bool isGpuAvailable() => false;

  @override
  GpuInfo getGpuInfo() => const GpuInfo(
        cudaAvailable: false,
        tensorrtAvailable: false,
        coremlAvailable: false,
        directmlAvailable: false,
        deviceName: 'Fake GPU',
        cudaDeviceCount: 0,
      );

  @override
  String getAvailableProviders() => 'CPUExecutionProvider';

  @override
  String get lastError => '';

  @override
  int get lastErrorCode => 0;

  @override
  void dispose() {}
}

/// GPU detector stub that reports a CPU-only system.
class FakeGpuDetector implements GpuDetector {
  const FakeGpuDetector();

  @override
  Future<GpuDetectionResult> detect() async {
    return const GpuDetectionResult(
      available: false,
      info: GpuInfo(
        cudaAvailable: false,
        tensorrtAvailable: false,
        coremlAvailable: false,
        directmlAvailable: false,
        deviceName: 'Fake GPU',
        cudaDeviceCount: 0,
      ),
      providers: 'CPUExecutionProvider',
    );
  }
}

/// Theme store stub capturing the last written value.
class FakeThemeStore implements ThemeStore {
  FakeThemeStore({this.readValue});

  bool? readValue;
  bool? lastWritten;

  @override
  Future<bool?> readIsDark() async => readValue;

  @override
  Future<void> writeIsDark(bool value) async {
    lastWritten = value;
  }
}

/// In-memory settings store for app boot tests.
class FakeSettingsStore implements SettingsStore {
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

/// Keybindings store stub used by the app container.
class FakeKeyBindingsStore implements KeyBindingsStore {
  String? stored;

  @override
  Future<String?> read() async => stored;

  @override
  Future<void> write(String value) async {
    stored = value;
  }
}

/// Keyboard state reader with all modifiers released.
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
  Set<LogicalKeyboardKey> get logicalKeysPressed => {};
}

/// In-memory project list repository for boot sequence tests.
class FakeProjectListRepository extends ProjectListRepository {
  List<ProjectConfig> stored = [];

  @override
  Future<List<ProjectConfig>> loadProjects() async => List.of(stored);

  @override
  Future<void> saveProjects(List<ProjectConfig> projects) async {
    stored = List.of(projects);
  }
}

/// Builds a fully fake AppServices container for widget tests.
AppServices buildFakeServices({bool? isDark}) {
  return AppServices(
    inferenceEngine: FakeInferenceEngine(),
    gpuDetector: const FakeGpuDetector(),
    settingsStore: FakeSettingsStore(),
    themeStore: FakeThemeStore(readValue: isDark),
    keyBindingsStore: FakeKeyBindingsStore(),
    keyboardStateReader: FakeKeyboardStateReader(),
    projectListRepository: FakeProjectListRepository(),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('LabelLoadApp builds MaterialApp with provider configuration',
      (tester) async {
    final services = buildFakeServices(isDark: false);

    await tester.pumpWidget(
      LabelLoadApp(servicesBuilder: () => services),
    );
    await tester.pump();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, 'LabelLoad');
    expect(app.debugShowCheckedModeBanner, isFalse);
    expect(app.themeMode, ThemeMode.light);
    expect(app.locale?.languageCode, 'zh');

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
  });

  testWidgets('Splash screen shows loading UI then navigates to project list',
      (tester) async {
    final services = buildFakeServices(isDark: true);

    await tester.pumpWidget(
      LabelLoadApp(servicesBuilder: () => services),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('LabelLoad'), findsOneWidget);

    final context = tester.element(find.byType(Scaffold));
    final l10n = AppLocalizations.of(context)!;
    expect(find.text(l10n.splashSubtitle), findsOneWidget);
    expect(find.text(l10n.splashLoading), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(find.byType(ProjectListPage), findsOneWidget);
  });
}
