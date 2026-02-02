import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:label_load/models/label_definition.dart';
import 'package:label_load/widgets/dialogs/label_editor_dialog.dart';
import 'test_helpers.dart' as dialog_helpers;

/// Handle for awaiting dialog results.
class DialogHandle {
  DialogHandle(this.result);

  final Future<LabelDefinition?> result;
}

/// Opens the dialog and returns a handle for the result future.
Future<DialogHandle> openDialog(
  WidgetTester tester,
  LabelEditorDialog dialog,
) async {
  final completer = Completer<LabelDefinition?>();

  await tester.pumpWidget(
    dialog_helpers.buildDialogTestApp(
      child: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () {
                showDialog<LabelDefinition>(
                  context: context,
                  builder: (_) => dialog,
                ).then(completer.complete);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();

  return DialogHandle(completer.future);
}

void main() {
  testWidgets('LabelEditorDialog creates new definition and saves',
      (tester) async {
    final l10n = await dialog_helpers.loadL10n();
    final handle = await openDialog(
      tester,
      LabelEditorDialog(
        nextClassId: 3,
        usedColors: [LabelPalettes.extendedPalette.first],
      ),
    );

    final fields =
        tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields.length, 2);

    await tester.enterText(find.byType(TextField).first, '5');
    await tester.enterText(find.byType(TextField).last, 'Car');

    await tester.tap(find.text(l10n.save));
    await tester.pumpAndSettle();

    final result = await handle.result;
    expect(result, isNotNull);
    expect(result!.classId, 5);
    expect(result.name, 'Car');
    expect(result.type, LabelType.box);
  });

  testWidgets('LabelEditorDialog edits existing definition and type',
      (tester) async {
    final l10n = await dialog_helpers.loadL10n();
    final handle = await openDialog(
      tester,
      LabelEditorDialog(
        definition: LabelDefinition(
          classId: 1,
          name: 'Old',
          color: Colors.blue,
          type: LabelType.box,
        ),
      ),
    );

    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'New');

    await tester.tap(find.text(l10n.labelTypeBox));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.labelTypePolygon).last);
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.save));
    await tester.pumpAndSettle();

    final result = await handle.result;
    expect(result, isNotNull);
    expect(result!.classId, 1);
    expect(result.name, 'New');
    expect(result.type, LabelType.polygon);
  });

  testWidgets('LabelEditorDialog color picker updates color', (tester) async {
    final l10n = await dialog_helpers.loadL10n();
    final handle = await openDialog(
      tester,
      const LabelEditorDialog(
        nextClassId: 0,
        usedColors: [],
      ),
    );

    final colorPickerTap = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(GestureDetector),
    );
    await tester.tap(colorPickerTap.first);
    await tester.pumpAndSettle();

    final picker = tester.widget<BlockPicker>(find.byType(BlockPicker));
    picker.onColorChanged(Colors.green);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'Green');
    await tester.tap(find.text(l10n.save));
    await tester.pumpAndSettle();
    await handle.result;
  });

  testWidgets('LabelEditorDialog does not save with empty name',
      (tester) async {
    final l10n = await dialog_helpers.loadL10n();

    await openDialog(
      tester,
      const LabelEditorDialog(nextClassId: 0),
    );

    await tester.tap(find.text(l10n.save));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
  });
}
