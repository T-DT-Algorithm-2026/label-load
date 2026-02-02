/// AI inference integration tests (manual and auto on navigation).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:label_load/models/ai_config.dart';
import 'package:label_load/models/label.dart';
import 'package:label_load/models/label_definition.dart';
import 'package:label_load/models/project_config.dart';
import 'package:label_load/pages/home_page.dart';
import 'package:label_load/pages/project_list_page.dart';
import 'package:label_load/widgets/canvas/image_canvas.dart';
import 'package:label_load/services/inference/project_inference_controller.dart';

import '../helpers/integration_test_harness.dart';

class StubInferenceRunner implements InferenceRunner {
  bool _hasModel = false;
  String? _loadedPath;

  @override
  bool get hasModel => _hasModel;

  @override
  String? get loadedModelPath => _loadedPath;

  @override
  Future<bool> loadModel(String path, {bool useGpu = false}) async {
    _loadedPath = path;
    _hasModel = true;
    return true;
  }

  @override
  Future<List<Label>> runInference(
    String imagePath,
    AiConfig config,
    List<LabelDefinition> labelDefinitions,
  ) async {
    return [
      Label(
        id: 0,
        name: 'Person',
        x: 0.5,
        y: 0.5,
        width: 0.2,
        height: 0.2,
      ),
    ];
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(configureIntegrationTestEnvironment);

  testWidgets('manual AI inference adds labels via keybinding', (tester) async {
    const imageDir = '/images';
    const labelDir = '/labels';
    const modelPath = '/models/dummy.onnx';

    final config = ProjectConfig(
      name: 'AI Project',
      imagePath: imageDir,
      labelPath: labelDir,
      labelDefinitions: [
        LabelDefinition(
          classId: 0,
          name: 'Person',
          color: const Color(0xFF3B82F6),
        ),
      ],
      aiConfig: AiConfig(modelPath: modelPath),
    );

    final runner = StubInferenceRunner();
    final harness = TestAppHarness(
      initialProjects: [config],
      imageListing: {
        imageDir: ['$imageDir/img_001.png'],
      },
      imageBytesByPath: {
        '$imageDir/img_001.png': testPngBytes,
      },
      inferenceRunner: runner,
    );

    await tester.pumpWidget(harness.buildApp());
    await pumpUntilFound(tester, find.byType(ProjectListPage));

    await pumpUntilFound(tester, find.text('AI Project'));
    await tester.tap(find.byType(Card).first);
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);

    await pumpUntilFound(tester, find.byType(ImageCanvas));

    final homeContext = tester.element(find.byType(HomePage));
    final focusFinder = find.byWidgetPredicate(
      (widget) => widget is Focus && widget.onKeyEvent != null,
    );
    final focusWidget = tester.widget<Focus>(focusFinder.first);
    FocusScope.of(homeContext).requestFocus(focusWidget.focusNode);
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyR);
    await tester.pumpAndSettle();

    expect(find.text('Person'), findsWidgets);
    expect(runner.loadedModelPath, equals(modelPath));
  });

  testWidgets('auto inference triggers on next image navigation',
      (tester) async {
    const imageDir = '/images';
    const labelDir = '/labels';
    const modelPath = '/models/dummy.onnx';

    final config = ProjectConfig(
      name: 'AI Auto Project',
      imagePath: imageDir,
      labelPath: labelDir,
      labelDefinitions: [
        LabelDefinition(
          classId: 0,
          name: 'Person',
          color: const Color(0xFF22C55E),
        ),
      ],
      aiConfig: AiConfig(
        modelPath: modelPath,
        autoInferOnNext: true,
      ),
    );

    final runner = StubInferenceRunner();
    final harness = TestAppHarness(
      initialProjects: [config],
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
      inferenceRunner: runner,
    );

    await tester.pumpWidget(harness.buildApp());
    await pumpUntilFound(tester, find.byType(ProjectListPage));

    await pumpUntilFound(tester, find.text('AI Auto Project'));
    await tester.tap(find.byType(Card).first);
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);

    await pumpUntilFound(tester, find.byType(ImageCanvas));

    final homeContext = tester.element(find.byType(HomePage));
    final focusFinder = find.byWidgetPredicate(
      (widget) => widget is Focus && widget.onKeyEvent != null,
    );
    final focusWidget = tester.widget<Focus>(focusFinder.first);
    FocusScope.of(homeContext).requestFocus(focusWidget.focusNode);
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyD);
    await tester.pumpAndSettle();

    expect(find.text('Person'), findsWidgets);
  });
}
