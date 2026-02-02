import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/widgets/dialogs/gadgets/add_bbox_widget.dart';
import 'package:label_load/widgets/dialogs/gadgets/batch_rename_widget.dart';
import 'package:label_load/widgets/dialogs/gadgets/bbox_expand_widget.dart';
import 'package:label_load/widgets/dialogs/gadgets/check_and_fix_widget.dart';
import 'package:label_load/widgets/dialogs/gadgets/convert_labels_widget.dart';
import 'package:label_load/widgets/dialogs/gadgets/delete_keypoints_widget.dart';
import 'package:label_load/widgets/dialogs/gadgets/xyxy2xywh_widget.dart';

import '../test_helpers.dart';

void main() {
  testWidgets('BatchRenameWidget handles errors and success', (tester) async {
    await setLargeSurface(tester);
    await runWithSuppressedErrors(() async {
      final l10n = await loadL10n();
      final filePicker = FakeFilePickerService(
        directoryPath: '/data',
        throwOnDirectory: true,
      );
      final gadgetService = FakeGadgetService()
        ..imageFiles = ['a.jpg', 'b.jpg']
        ..result = (2, 0);
      final services = buildAppServices(
        gadgetService: gadgetService,
        filePickerService: filePicker,
      );

      await tester.pumpWidget(buildDialogTestApp(
        child: const BatchRenameWidget(),
        services: services,
        padding: const EdgeInsets.all(16),
        scrollable: true,
      ));

      await tester
          .tap(find.widgetWithText(ElevatedButton, l10n.selectDirButton).first);
      await tester.pumpAndSettle();

      filePicker.throwOnDirectory = false;
      await tester
          .tap(find.widgetWithText(ElevatedButton, l10n.selectDirButton).first);
      await tester.pumpAndSettle();
      expect(find.text(l10n.foundNImages(2)), findsOneWidget);

      gadgetService.throwOnProcess = true;
      await tester.tap(find.text(l10n.startProcess));
      await tester.pumpAndSettle();

      gadgetService.throwOnProcess = false;
      await tester.tap(find.text(l10n.startProcess));
      await tester.pumpAndSettle();

      expect(find.text(l10n.successNFailedM(2, 0)), findsOneWidget);
    });
  });

  testWidgets('Xyxy2XywhWidget handles warning flow and errors',
      (tester) async {
    await setLargeSurface(tester);
    await runWithSuppressedErrors(() async {
      final l10n = await loadL10n();
      final filePicker = FakeFilePickerService(
        directoryPath: '/labels',
        throwOnDirectory: true,
      );
      final gadgetService = FakeGadgetService()
        ..labelFiles = ['a.txt']
        ..result = (1, 0);
      final services = buildAppServices(
        gadgetService: gadgetService,
        filePickerService: filePicker,
      );

      await tester.pumpWidget(buildDialogTestApp(
        child: const Xyxy2XywhWidget(),
        services: services,
        padding: const EdgeInsets.all(16),
        scrollable: true,
      ));

      await tester
          .tap(find.widgetWithText(ElevatedButton, l10n.selectDirButton).first);
      await tester.pumpAndSettle();

      filePicker.throwOnDirectory = false;
      await tester
          .tap(find.widgetWithText(ElevatedButton, l10n.selectDirButton).first);
      await tester.pumpAndSettle();
      expect(find.text(l10n.foundNLabels(1)), findsOneWidget);

      gadgetService.throwOnProcess = true;
      await tester.tap(find.text(l10n.startProcess));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.confirm));
      await tester.pumpAndSettle();

      gadgetService.throwOnProcess = false;
      await tester.tap(find.text(l10n.startProcess));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.confirm));
      await tester.pumpAndSettle();

      expect(find.text(l10n.successNFailedM(1, 0)), findsOneWidget);
    });
  });

  testWidgets('BboxExpandWidget parses inputs and handles errors',
      (tester) async {
    await setLargeSurface(tester);
    await runWithSuppressedErrors(() async {
      final l10n = await loadL10n();
      final filePicker = FakeFilePickerService(
        directoryPath: '/labels',
        throwOnDirectory: true,
      );
      final gadgetService = FakeGadgetService()
        ..labelFiles = ['a.txt']
        ..result = (3, 1);
      final services = buildAppServices(
        gadgetService: gadgetService,
        filePickerService: filePicker,
      );

      await tester.pumpWidget(buildDialogTestApp(
        child: const BboxExpandWidget(),
        services: services,
        padding: const EdgeInsets.all(16),
        scrollable: true,
      ));

      await tester
          .tap(find.widgetWithText(ElevatedButton, l10n.selectDirButton).first);
      await tester.pumpAndSettle();

      filePicker.throwOnDirectory = false;
      await tester.tap(find.text(l10n.selectDirButton));
      await tester.pumpAndSettle();
      expect(find.text(l10n.foundNLabels(1)), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(0), '1.2');
      await tester.enterText(find.byType(TextField).at(1), '1.1');
      await tester.enterText(find.byType(TextField).at(2), '0.2');
      await tester.enterText(find.byType(TextField).at(3), 'bad');
      await tester.pump();

      gadgetService.throwOnProcess = true;
      await tester.tap(find.text(l10n.startProcess));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.confirm));
      await tester.pumpAndSettle();

      gadgetService.throwOnProcess = false;
      await tester.tap(find.text(l10n.startProcess));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.confirm));
      await tester.pumpAndSettle();

      expect(find.text(l10n.successNFailedM(3, 1)), findsOneWidget);
      expect(gadgetService.lastRatioX, 1.2);
      expect(gadgetService.lastRatioY, 1.1);
      expect(gadgetService.lastBiasX, 0.2);
      expect(gadgetService.lastBiasY, 0.0);
    });
  });

  testWidgets('CheckAndFixWidget handles errors and success', (tester) async {
    await setLargeSurface(tester);
    await runWithSuppressedErrors(() async {
      final l10n = await loadL10n();
      final filePicker = FakeFilePickerService(
        directoryPath: '/labels',
        throwOnDirectory: true,
      );
      final gadgetService = FakeGadgetService()
        ..labelFiles = ['a.txt', 'b.txt']
        ..result = (2, 0);
      final services = buildAppServices(
        gadgetService: gadgetService,
        filePickerService: filePicker,
      );

      await tester.pumpWidget(buildDialogTestApp(
        child: const CheckAndFixWidget(),
        services: services,
        padding: const EdgeInsets.all(16),
        scrollable: true,
      ));

      await tester.tap(find.text(l10n.selectDirButton));
      await tester.pumpAndSettle();

      filePicker.throwOnDirectory = false;
      await tester.tap(find.text(l10n.selectDirButton));
      await tester.pumpAndSettle();
      expect(find.text(l10n.foundNLabels(2)), findsOneWidget);

      gadgetService.throwOnProcess = true;
      await tester.tap(find.text(l10n.checkAndFix));
      await tester.pumpAndSettle();

      gadgetService.throwOnProcess = false;
      await tester.tap(find.text(l10n.checkAndFix));
      await tester.pumpAndSettle();

      expect(find.text(l10n.successNFailedM(2, 0)), findsOneWidget);
    });
  });

  testWidgets('DeleteKeypointsWidget handles errors and success',
      (tester) async {
    await setLargeSurface(tester);
    await runWithSuppressedErrors(() async {
      final l10n = await loadL10n();
      final filePicker = FakeFilePickerService(
        directoryPath: '/labels',
        throwOnDirectory: true,
      );
      final gadgetService = FakeGadgetService()
        ..labelFiles = ['a.txt']
        ..result = (1, 2);
      final services = buildAppServices(
        gadgetService: gadgetService,
        filePickerService: filePicker,
      );

      await tester.pumpWidget(buildDialogTestApp(
        child: const DeleteKeypointsWidget(),
        services: services,
        padding: const EdgeInsets.all(16),
        scrollable: true,
      ));

      await tester.tap(find.text(l10n.selectDirButton));
      await tester.pumpAndSettle();

      filePicker.throwOnDirectory = false;
      await tester.tap(find.text(l10n.selectDirButton));
      await tester.pumpAndSettle();
      expect(find.text(l10n.foundNLabels(1)), findsOneWidget);

      gadgetService.throwOnProcess = true;
      await tester.tap(find.text(l10n.startProcess));
      await tester.pumpAndSettle();

      gadgetService.throwOnProcess = false;
      await tester.tap(find.text(l10n.startProcess));
      await tester.pumpAndSettle();

      expect(find.text(l10n.successNFailedM(1, 2)), findsOneWidget);
    });
  });

  testWidgets('AddBboxWidget handles errors and success', (tester) async {
    await setLargeSurface(tester);
    await runWithSuppressedErrors(() async {
      final l10n = await loadL10n();
      final filePicker = FakeFilePickerService(
        directoryPath: '/labels',
        throwOnDirectory: true,
      );
      final gadgetService = FakeGadgetService()
        ..labelFiles = ['a.txt', 'b.txt', 'c.txt']
        ..result = (3, 0);
      final services = buildAppServices(
        gadgetService: gadgetService,
        filePickerService: filePicker,
      );

      await tester.pumpWidget(buildDialogTestApp(
        child: const AddBboxWidget(),
        services: services,
        padding: const EdgeInsets.all(16),
        scrollable: true,
      ));

      await tester.tap(find.text(l10n.selectDirButton));
      await tester.pumpAndSettle();

      filePicker.throwOnDirectory = false;
      await tester.tap(find.text(l10n.selectDirButton));
      await tester.pumpAndSettle();
      expect(find.text(l10n.foundNLabels(3)), findsOneWidget);

      gadgetService.throwOnProcess = true;
      await tester.tap(find.text(l10n.startProcess));
      await tester.pumpAndSettle();

      gadgetService.throwOnProcess = false;
      await tester.tap(find.text(l10n.startProcess));
      await tester.pumpAndSettle();

      expect(find.text(l10n.successNFailedM(3, 0)), findsOneWidget);
    });
  });

  testWidgets('ConvertLabelsWidget maps classes and processes', (tester) async {
    await setLargeSurface(tester);
    await runWithSuppressedErrors(() async {
      final l10n = await loadL10n();
      final filePicker = FakeFilePickerService(
        directoryPath: '/labels',
        filePath: '/labels/classes.txt',
        throwOnDirectory: true,
      );
      final gadgetService = FakeGadgetService()
        ..classNames = ['cat', 'doge', 'wolf']
        ..lines = ['cat', 'dog']
        ..result = (5, 1);
      final services = buildAppServices(
        gadgetService: gadgetService,
        filePickerService: filePicker,
      );

      await tester.pumpWidget(buildDialogTestApp(
        child: const ConvertLabelsWidget(),
        services: services,
        padding: const EdgeInsets.all(16),
        scrollable: true,
      ));

      await tester
          .tap(find.widgetWithText(ElevatedButton, l10n.selectDirButton).first);
      await tester.pumpAndSettle();

      filePicker.throwOnDirectory = false;
      await tester
          .tap(find.widgetWithText(ElevatedButton, l10n.selectDirButton).first);
      await tester.pumpAndSettle();

      filePicker.throwOnPick = true;
      await tester
          .tap(find.widgetWithText(ElevatedButton, l10n.selectFileButton).last);
      await tester.pumpAndSettle();

      filePicker.throwOnPick = false;
      await tester
          .tap(find.widgetWithText(ElevatedButton, l10n.selectFileButton).last);
      await tester.pumpAndSettle();

      final dropdown = find.byType(DropdownButtonFormField<int>).first;
      final widget = tester.widget<DropdownButtonFormField<int>>(dropdown);
      widget.onChanged?.call(0);
      await tester.pump();

      gadgetService.throwOnProcess = true;
      await tester.tap(find.text(l10n.startProcess));
      await tester.pumpAndSettle();

      gadgetService.throwOnProcess = false;
      await tester.tap(find.text(l10n.startProcess));
      await tester.pumpAndSettle();

      expect(find.text(l10n.successNFailedM(5, 1)), findsOneWidget);
      expect(gadgetService.writtenClasses, ['cat', 'dog']);
      expect(gadgetService.lastMapping.length, 3);
    });
  });
}
