import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/models/config.dart';
import 'package:label_load/providers/keybindings_provider.dart';
import 'package:label_load/providers/project_provider.dart';
import 'package:label_load/providers/settings_provider.dart';
import 'package:label_load/providers/theme_provider.dart';
import 'package:label_load/services/gpu/gpu_info.dart';
import 'package:label_load/widgets/dialogs/global_settings_dialog.dart';
import 'package:provider/provider.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('GlobalSettingsDialog updates providers and opens dialogs',
      (tester) async {
    await setLargeSurface(tester, size: const Size(1200, 1400));
    final l10n = await loadL10n();

    // Arrange providers with a fake GPU and persisted theme/settings.
    const gpuInfo = GpuInfo(
      cudaAvailable: true,
      tensorrtAvailable: false,
      coremlAvailable: false,
      directmlAvailable: false,
      deviceName: 'Fake GPU',
      cudaDeviceCount: 1,
    );

    final settingsProvider = SettingsProvider(
      store: FakeSettingsStore(),
      gpuDetector: FakeGpuDetector(
        available: true,
        info: gpuInfo,
        providers: 'CUDAExecutionProvider',
      ),
      autoLoad: false,
    );
    await settingsProvider.refreshGpuDetection();

    final themeProvider = ThemeProvider(store: FakeThemeStore(isDark: true));
    final projectProvider = ProjectProvider()
      ..updateConfig(AppConfig(locale: 'en'));
    final keyBindingsProvider =
        KeyBindingsProvider(store: FakeKeyBindingsStore());
    final services = buildAppServices(
      gadgetService: FakeGadgetService(),
      filePickerService: FakeFilePickerService(),
    );

    await tester.pumpWidget(buildDialogTestApp(
      child: const GlobalSettingsDialog(),
      services: services,
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: settingsProvider),
        ChangeNotifierProvider.value(value: projectProvider),
        ChangeNotifierProvider.value(value: keyBindingsProvider),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.text(l10n.globalSettingsTitle), findsOneWidget);
    expect(find.text('Fake GPU'), findsOneWidget);

    // Act: toggle flags and update numeric settings.
    await tester.tap(find.widgetWithText(SwitchListTile, l10n.darkMode));
    await tester.pump();
    expect(themeProvider.isDarkMode, isFalse);

    await tester.tap(find.widgetWithText(
        RadioListTile<BoxDrawMode>, l10n.boxDrawModeTwoClick));
    await tester.pump();
    expect(settingsProvider.boxDrawMode, BoxDrawMode.twoClick);

    final sliders = tester.widgetList<Slider>(find.byType(Slider)).toList();
    sliders[0].onChanged?.call(0.1);
    sliders[1].onChanged?.call(5.0);
    sliders[2].onChanged?.call(8.0);
    sliders[3].onChanged?.call(80.0);
    await tester.pump();

    await tester.ensureVisible(
        find.widgetWithText(SwitchListTile, l10n.imageInterpolation));
    await tester
        .tap(find.widgetWithText(SwitchListTile, l10n.imageInterpolation));
    await tester.pump();
    expect(settingsProvider.imageInterpolation, isFalse);

    await tester
        .ensureVisible(find.widgetWithText(SwitchListTile, l10n.fillShape));
    await tester.tap(find.widgetWithText(SwitchListTile, l10n.fillShape));
    await tester.pump();
    expect(settingsProvider.fillShape, isFalse);

    await tester.ensureVisible(
        find.widgetWithText(SwitchListTile, l10n.showUnlabeledPoints));
    await tester
        .tap(find.widgetWithText(SwitchListTile, l10n.showUnlabeledPoints));
    await tester.pump();
    expect(settingsProvider.showUnlabeledPoints, isFalse);

    await tester.tap(find.widgetWithText(
        RadioListTile<InferenceDevice>, l10n.inferenceDeviceGpu));
    await tester.pump();
    expect(settingsProvider.inferenceDevice, InferenceDevice.gpu);

    await tester
        .ensureVisible(find.widgetWithText(SwitchListTile, l10n.autoSave));
    await tester.tap(find.widgetWithText(SwitchListTile, l10n.autoSave));
    await tester.pump();
    expect(settingsProvider.autoSaveOnNavigate, isFalse);

    await tester.tap(find.text(l10n.english));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.chinese).last);
    await tester.pumpAndSettle();
    expect(projectProvider.config.locale, 'zh');
  });
}
