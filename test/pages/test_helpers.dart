import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'package:label_load/services/gpu/gpu_detector.dart';
import 'package:label_load/services/gpu/gpu_info.dart';
import 'package:label_load/services/input/keybindings_store.dart';
import 'package:label_load/services/input/keyboard_state_reader.dart';
import 'package:label_load/services/settings/settings_store.dart';

/// Sets a large surface size for widget tests and restores it afterward.
Future<void> setLargeSurface(
  WidgetTester tester, {
  Size size = const Size(1400, 900),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

/// Builds a common test shell for pages with localization + optional providers.
Widget buildPageTestApp({
  required Widget child,
  Locale locale = const Locale('en'),
  List<SingleChildWidget> providers = const [],
  bool wrapInScaffold = true,
}) {
  return MultiProvider(
    providers: providers,
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: wrapInScaffold ? Scaffold(body: child) : child,
    ),
  );
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

/// Runs [body] with Flutter errors suppressed.
Future<T> runWithFlutterErrorsSuppressed<T>(Future<T> Function() body) {
  return runWithFlutterErrorOverride((_) {}, body);
}

/// In-memory keybinding storage for page tests.
class FakeKeyBindingsStore implements KeyBindingsStore {
  String? _value;

  @override
  Future<String?> read() async => _value;

  @override
  Future<void> write(String value) async {
    _value = value;
  }
}

/// Keyboard state reader with mutable modifier flags.
class FakeKeyboardStateReader implements KeyboardStateReader {
  @override
  bool isAltPressed = false;

  @override
  bool isControlPressed = false;

  @override
  bool isMetaPressed = false;

  @override
  bool isShiftPressed = false;

  @override
  Set<LogicalKeyboardKey> logicalKeysPressed = {};
}

/// No-op settings store for page tests.
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

/// GPU detector stub that reports CPU-only availability.
class FakeGpuDetector implements GpuDetector {
  @override
  Future<GpuDetectionResult> detect() async => const GpuDetectionResult(
        available: false,
        info: GpuInfo(
          cudaAvailable: false,
          tensorrtAvailable: false,
          coremlAvailable: false,
          directmlAvailable: false,
          deviceName: 'Fake',
          cudaDeviceCount: 0,
        ),
        providers: 'CPU',
      );
}
