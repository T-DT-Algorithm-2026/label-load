/// Batch inference integration test.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:label_load/models/ai_config.dart';
import 'package:label_load/models/label.dart';
import 'package:label_load/models/label_definition.dart';
import 'package:label_load/pages/project_list_page.dart';
import 'package:label_load/pages/project_settings_page.dart';
import 'package:label_load/services/inference/batch_inference_service.dart';

import '../helpers/integration_test_harness.dart';

class StubBatchInferenceRunner implements BatchInferenceRunner {
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
    return List<List<Label>>.generate(
      imagePaths.length,
      (_) => [
        Label(
          id: 1,
          name: 'class_1',
          x: 0.5,
          y: 0.5,
          width: 0.2,
          height: 0.2,
        ),
      ],
    );
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(configureIntegrationTestEnvironment);

  testWidgets('batch inference adds missing definitions', (tester) async {
    const imageDir = '/images';
    const labelDir = '/labels';
    const modelPath = '/models/dummy.onnx';

    final harness = TestAppHarness(
      imageListing: {
        imageDir: [
          '$imageDir/img_001.png',
          '$imageDir/img_002.png',
        ],
      },
      imageBytesByPath: {
        '$imageDir/img_001.png': testPngBytes,
        '$imageDir/img_002.png': testPngBytes,
      },
      batchInferenceRunner: StubBatchInferenceRunner(),
    );

    harness.filePickerService.enqueueDirectoryPath(imageDir);
    harness.filePickerService.enqueueDirectoryPath(labelDir);
    harness.filePickerService.enqueueFilePath(modelPath);

    await tester.pumpWidget(harness.buildApp());
    await pumpUntilFound(tester, find.byType(ProjectListPage));

    final context = tester.element(find.byType(ProjectListPage));
    final l10n = AppLocalizations.of(context)!;

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.byType(ProjectSettingsPage), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, l10n.projectName),
      'Batch Project',
    );

    final folderButtons = find.widgetWithIcon(IconButton, Icons.folder_open);
    await tester.tap(folderButtons.at(0));
    await tester.pumpAndSettle();
    await tester.tap(folderButtons.at(1));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip(l10n.selectModel));
    await tester.pumpAndSettle();

    await pumpUntilFound(tester, find.text(l10n.batchInference));
    final batchButton = find.byIcon(Icons.play_arrow).first;
    await tester.ensureVisible(batchButton);
    await tester.tap(batchButton);
    await tester.pumpAndSettle();

    await pumpUntilFound(tester, find.text('class_1'));
    expect(find.text('class_1'), findsWidgets);
  });
}
