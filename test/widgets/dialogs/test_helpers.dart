import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:label_load/models/ai_config.dart';
import 'package:label_load/providers/keybindings_provider.dart';
import 'package:label_load/services/app/app_services.dart';
import 'package:label_load/services/files/file_picker_service.dart';
import 'package:label_load/services/gadgets/gadget_repository.dart';
import 'package:label_load/services/gadgets/gadget_service.dart';
import 'package:label_load/services/gpu/gpu_detector.dart';
import 'package:label_load/services/gpu/gpu_info.dart';
import 'package:label_load/services/inference/inference_engine.dart';
import 'package:label_load/services/input/keybindings_store.dart';
import 'package:label_load/services/input/keyboard_state_reader.dart';
import 'package:label_load/services/settings/settings_store.dart';
import 'package:label_load/services/settings/theme_store.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

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
        deviceName: 'fake',
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

class FakeFilePickerService implements FilePickerService {
  FakeFilePickerService({
    this.directoryPath,
    this.filePath,
    this.throwOnDirectory = false,
    this.throwOnPick = false,
  });

  String? directoryPath;
  String? filePath;
  bool throwOnDirectory;
  bool throwOnPick;

  @override
  Future<String?> getDirectoryPath() async {
    if (throwOnDirectory) {
      throw StateError('directory error');
    }
    return directoryPath;
  }

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    List<String>? allowedExtensions,
  }) async {
    return null;
  }

  @override
  Future<String?> pickFile({
    String? dialogTitle,
    List<String>? allowedExtensions,
  }) async {
    if (throwOnPick) {
      throw StateError('pick error');
    }
    return filePath;
  }
}

class FakeGadgetRepository implements GadgetRepository {
  @override
  Future<List<String>> listImageFiles(String directoryPath) async => [];

  @override
  Future<List<String>> listLabelFiles(String directoryPath) async => [];

  @override
  Future<List<String>> listVideoFiles(String directoryPath) async => [];

  @override
  Future<List<String>> readClassNames(String labelDir) async => [];

  @override
  Future<List<String>> readLines(String path) async => [];

  @override
  Future<void> renameFile(String from, String to) async {}

  @override
  Future<void> writeClassNames(
      String labelDir, List<String> classNames) async {}

  @override
  Future<void> writeLines(String path, List<String> lines) async {}
}

class FakeGadgetService extends GadgetService {
  FakeGadgetService() : super(repository: FakeGadgetRepository());

  List<String> imageFiles = const [];
  List<String> labelFiles = const [];
  List<String> classNames = const [];
  List<String> lines = const [];
  List<String> writtenClasses = const [];
  List<int> lastMapping = const [];
  String? lastDirectory;
  String? lastFilePath;
  double? lastRatioX;
  double? lastRatioY;
  double? lastBiasX;
  double? lastBiasY;
  bool throwOnList = false;
  bool throwOnRead = false;
  bool throwOnProcess = false;
  bool throwOnWrite = false;
  (int, int) result = (1, 0);

  @override
  Future<List<String>> getImageFiles(String directoryPath) async {
    lastDirectory = directoryPath;
    if (throwOnList) {
      throw StateError('list images');
    }
    return imageFiles;
  }

  @override
  Future<List<String>> getLabelFiles(String directoryPath) async {
    lastDirectory = directoryPath;
    if (throwOnList) {
      throw StateError('list labels');
    }
    return labelFiles;
  }

  @override
  Future<List<String>> readClassNames(
    String labelDir, {
    GadgetRepository? repository,
  }) async {
    lastDirectory = labelDir;
    if (throwOnRead) {
      throw StateError('read classes');
    }
    return classNames;
  }

  @override
  Future<List<String>> readLines(
    String path, {
    GadgetRepository? repository,
  }) async {
    lastFilePath = path;
    if (throwOnRead) {
      throw StateError('read lines');
    }
    return lines;
  }

  @override
  Future<void> writeClassNames(
    String labelDir,
    List<String> classNames, {
    GadgetRepository? repository,
  }) async {
    lastDirectory = labelDir;
    writtenClasses = classNames;
    if (throwOnWrite) {
      throw StateError('write classes');
    }
  }

  @override
  Future<(int, int)> batchRename(
    String directoryPath, {
    void Function(int current, int total)? onProgress,
    GadgetRepository? repository,
  }) async {
    lastDirectory = directoryPath;
    if (throwOnProcess) {
      throw StateError('batch rename');
    }
    onProgress?.call(1, 1);
    return result;
  }

  @override
  Future<(int, int)> xyxy2xywh(
    String directoryPath, {
    void Function(int current, int total)? onProgress,
    GadgetRepository? repository,
  }) async {
    lastDirectory = directoryPath;
    if (throwOnProcess) {
      throw StateError('xyxy');
    }
    onProgress?.call(1, 1);
    return result;
  }

  @override
  Future<(int, int)> bboxExpand(
    String directoryPath, {
    double ratioX = 1.0,
    double ratioY = 1.0,
    double biasX = 0.0,
    double biasY = 0.0,
    void Function(int current, int total)? onProgress,
    GadgetRepository? repository,
  }) async {
    lastDirectory = directoryPath;
    lastRatioX = ratioX;
    lastRatioY = ratioY;
    lastBiasX = biasX;
    lastBiasY = biasY;
    if (throwOnProcess) {
      throw StateError('bbox expand');
    }
    onProgress?.call(1, 1);
    return result;
  }

  @override
  Future<(int, int)> checkAndFix(
    String directoryPath, {
    void Function(int current, int total)? onProgress,
    GadgetRepository? repository,
  }) async {
    lastDirectory = directoryPath;
    if (throwOnProcess) {
      throw StateError('check and fix');
    }
    onProgress?.call(1, 1);
    return result;
  }

  @override
  Future<(int, int)> deleteKeypoints(
    String directoryPath, {
    void Function(int current, int total)? onProgress,
    GadgetRepository? repository,
  }) async {
    lastDirectory = directoryPath;
    if (throwOnProcess) {
      throw StateError('delete keypoints');
    }
    onProgress?.call(1, 1);
    return result;
  }

  @override
  Future<(int, int)> addBboxFromKeypoints(
    String directoryPath, {
    void Function(int current, int total)? onProgress,
    GadgetRepository? repository,
  }) async {
    lastDirectory = directoryPath;
    if (throwOnProcess) {
      throw StateError('add bbox');
    }
    onProgress?.call(1, 1);
    return result;
  }

  @override
  Future<(int, int)> convertLabels(
    String directoryPath,
    List<int> mapping, {
    void Function(int current, int total)? onProgress,
    GadgetRepository? repository,
  }) async {
    lastDirectory = directoryPath;
    lastMapping = mapping;
    if (throwOnProcess) {
      throw StateError('convert labels');
    }
    onProgress?.call(1, 1);
    return result;
  }
}

class FakeKeyboardStateReader implements KeyboardStateReader {
  FakeKeyboardStateReader({
    this.isControlPressed = false,
    this.isMetaPressed = false,
    this.isShiftPressed = false,
    this.isAltPressed = false,
    Set<LogicalKeyboardKey>? logicalKeysPressed,
  }) : logicalKeysPressed = logicalKeysPressed ?? <LogicalKeyboardKey>{};

  @override
  bool isControlPressed;

  @override
  bool isMetaPressed;

  @override
  bool isShiftPressed;

  @override
  bool isAltPressed;

  @override
  Set<LogicalKeyboardKey> logicalKeysPressed;
}

class FakeGpuDetector implements GpuDetector {
  FakeGpuDetector({
    this.available = false,
    this.info,
    this.providers = 'CPUExecutionProvider',
  });

  bool available;
  GpuInfo? info;
  String providers;

  @override
  Future<GpuDetectionResult> detect() async {
    return GpuDetectionResult(
      available: available,
      info: info,
      providers: providers,
    );
  }
}

class FakeSettingsStore implements SettingsStore {
  final Map<String, Object> values;

  FakeSettingsStore({Map<String, Object>? seed}) : values = seed ?? {};

  @override
  Future<int?> getInt(String key) async => values[key] as int?;

  @override
  Future<double?> getDouble(String key) async => values[key] as double?;

  @override
  Future<bool?> getBool(String key) async => values[key] as bool?;

  @override
  Future<void> setInt(String key, int value) async {
    values[key] = value;
  }

  @override
  Future<void> setDouble(String key, double value) async {
    values[key] = value;
  }

  @override
  Future<void> setBool(String key, bool value) async {
    values[key] = value;
  }
}

class FakeThemeStore implements ThemeStore {
  FakeThemeStore({this.isDark = true});

  bool isDark;

  @override
  Future<bool?> readIsDark() async => isDark;

  @override
  Future<void> writeIsDark(bool value) async {
    isDark = value;
  }
}

class FakeKeyBindingsStore implements KeyBindingsStore {
  @override
  Future<String?> read() async => null;

  @override
  Future<void> write(String value) async {}
}

Future<void> setLargeSurface(WidgetTester tester,
    {Size size = const Size(1200, 1600)}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Future<void> runWithSuppressedErrors(Future<void> Function() body) async {
  final original = FlutterError.onError;
  FlutterError.onError = (details) {};
  try {
    await body();
  } finally {
    FlutterError.onError = original;
  }
}

Future<void> sendSideButtonEvent({
  required MouseButton button,
  bool isDown = true,
}) async {
  final payload = <String, String>{
    'button': button == MouseButton.back ? 'back' : 'forward',
    'state': isDown ? 'down' : 'up',
  };
  const channel = MethodChannel('side_buttons');
  final message = channel.codec.encodeMethodCall(
    MethodCall('sideButton', payload),
  );
  final binding =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  await binding.handlePlatformMessage(channel.name, message, (ByteData? _) {});
}

AppServices buildAppServices({
  FakeGadgetService? gadgetService,
  FakeFilePickerService? filePickerService,
  KeyboardStateReader? keyboardStateReader,
}) {
  return AppServices(
    inferenceEngine: FakeInferenceEngine(),
    gadgetService: gadgetService,
    filePickerService: filePickerService,
    keyboardStateReader: keyboardStateReader,
  );
}

/// 加载指定语言的本地化资源（默认英文）。
Future<AppLocalizations> loadL10n([Locale locale = const Locale('en')]) async {
  return AppLocalizations.delegate.load(locale);
}

/// 构建通用对话框测试宿主，统一注入服务与 Provider。
Widget buildDialogTestApp({
  required Widget child,
  AppServices? services,
  List<SingleChildWidget> providers = const [],
  Locale locale = const Locale('en'),
  double? textScaleFactor,
  EdgeInsets? padding,
  bool scrollable = false,
}) {
  final appServices = services ?? buildAppServices();
  Widget body = child;
  if (padding != null) {
    body = Padding(padding: padding, child: body);
  }
  if (scrollable) {
    body = SingleChildScrollView(child: body);
  }

  return MultiProvider(
    providers: [
      Provider.value(value: appServices),
      ...providers,
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) {
        if (textScaleFactor == null) {
          return child ?? const SizedBox.shrink();
        }
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: TextScaler.linear(textScaleFactor),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: Scaffold(body: body),
    ),
  );
}
