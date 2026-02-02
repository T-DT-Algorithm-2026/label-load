import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/models/ai_config.dart';
import 'package:label_load/services/app/app_services.dart';
import 'package:label_load/widgets/dialogs/ai_settings_widget.dart';

import 'test_helpers.dart';

Widget buildAiSettingsApp({
  required AiConfig initial,
  required ValueChanged<AiConfig> onChanged,
  AppServices? services,
}) {
  return buildDialogTestApp(
    child: AiSettingsWidget(
      config: initial,
      onChanged: onChanged,
    ),
    services: services,
  );
}

void main() {
  testWidgets('AiSettingsWidget toggles model type and updates keypoints',
      (tester) async {
    await setLargeSurface(tester);
    AiConfig config = AiConfig(modelType: ModelType.yoloPose, numKeypoints: 17);
    final l10n = await loadL10n();
    late void Function(void Function()) setState;

    await tester.pumpWidget(StatefulBuilder(
      builder: (context, setter) {
        setState = setter;
        return buildAiSettingsApp(
          initial: config,
          onChanged: (next) => setState(() => config = next),
        );
      },
    ));

    expect(find.text(l10n.modelTypeYoloPose), findsOneWidget);

    final keypointsField = find.byType(TextField).first;
    await tester.enterText(keypointsField, '12');
    await tester.pump();
    expect(config.numKeypoints, 12);

    await tester.tap(find.text(l10n.modelTypeYolo));
    await tester.pump();
    expect(config.modelType, ModelType.yolo);
  });

  testWidgets('AiSettingsWidget updates sliders and label save mode',
      (tester) async {
    await setLargeSurface(tester);
    AiConfig config = AiConfig(modelType: ModelType.yoloPose);
    final l10n = await loadL10n();
    late void Function(void Function()) setState;

    await tester.pumpWidget(StatefulBuilder(
      builder: (context, setter) {
        setState = setter;
        return buildAiSettingsApp(
          initial: config,
          onChanged: (next) => setState(() => config = next),
        );
      },
    ));

    var sliders = tester.widgetList<Slider>(find.byType(Slider)).toList();
    sliders[0].onChanged?.call(0.7);
    await tester.pump();
    expect(config.keypointConfThreshold, 0.7);

    sliders = tester.widgetList<Slider>(find.byType(Slider)).toList();
    sliders[1].onChanged?.call(0.3);
    await tester.pump();
    expect(config.confidenceThreshold, 0.3);

    sliders = tester.widgetList<Slider>(find.byType(Slider)).toList();
    sliders[2].onChanged?.call(0.6);
    await tester.pump();
    expect(config.nmsThreshold, 0.6);

    await tester.tap(find.text(l10n.labelSaveModeOverwrite));
    await tester.pump();
    expect(config.labelSaveMode, LabelSaveMode.overwrite);
  });

  testWidgets('AiSettingsWidget updates classIdOffset and modelPath',
      (tester) async {
    await setLargeSurface(tester);
    AiConfig config = AiConfig(modelType: ModelType.yoloPose);
    late void Function(void Function()) setState;
    final filePicker = FakeFilePickerService(filePath: '/tmp/model.onnx');
    final services = buildAppServices(filePickerService: filePicker);

    await tester.pumpWidget(StatefulBuilder(
      builder: (context, setter) {
        setState = setter;
        return buildAiSettingsApp(
          initial: config,
          onChanged: (next) => setState(() => config = next),
          services: services,
        );
      },
    ));

    await tester.enterText(find.byType(TextField).last, '3');
    await tester.pump();
    expect(config.classIdOffset, 3);

    await tester.tap(find.byIcon(Icons.folder_open));
    await tester.pump();
    expect(config.modelPath, '/tmp/model.onnx');

    await tester.tap(find.byIcon(Icons.clear));
    await tester.pump();
    expect(config.modelPath, '');
  });

  testWidgets('AiSettingsWidget syncs controller text on update',
      (tester) async {
    await setLargeSurface(tester);
    AiConfig config = AiConfig(modelType: ModelType.yoloPose);
    late void Function(void Function()) setState;

    await tester.pumpWidget(StatefulBuilder(
      builder: (context, setter) {
        setState = setter;
        return buildAiSettingsApp(
          initial: config,
          onChanged: (next) => setState(() => config = next),
        );
      },
    ));

    setState(() {
      config = config.copyWith(numKeypoints: 5, classIdOffset: 9);
    });
    await tester.pump();

    final fields =
        tester.widgetList<TextField>(find.byType(TextField)).toList();
    final keypointsText = fields.first.controller?.text;
    final classIdText = fields.last.controller?.text;

    expect(keypointsText, '5');
    expect(classIdText, '9');
  });
}
