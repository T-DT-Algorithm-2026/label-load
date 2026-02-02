import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/widgets/dialogs/gadgets/gadget_common.dart';

import '../test_helpers.dart';

void main() {
  testWidgets('DirectorySelector and FileSelector render values and callbacks',
      (tester) async {
    await setLargeSurface(tester);
    final l10n = await loadL10n();
    var tapCount = 0;

    await tester.pumpWidget(buildDialogTestApp(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          DirectorySelector(
            label: 'dir',
            value: null,
            onSelect: () => tapCount += 1,
          ),
          const SizedBox(height: 12),
          FileSelector(
            label: l10n.gadgetTargetClasses,
            value: null,
            onSelect: () => tapCount += 1,
          ),
          const SizedBox(height: 12),
          FileSelector(
            label: l10n.gadgetTargetClasses,
            value: '/tmp/classes.txt',
            onSelect: () => tapCount += 1,
          ),
        ],
      ),
    ));

    expect(find.text(l10n.notSelected), findsOneWidget);
    expect(find.text(l10n.gadgetTargetClasses), findsOneWidget);
    expect(find.text('/tmp/classes.txt'), findsOneWidget);

    final dirSelector = find.byType(DirectorySelector);
    final dirButton = find.descendant(
      of: dirSelector,
      matching: find.byType(ElevatedButton),
    );
    await tester.tap(dirButton);
    await tester.pump();
    final fileSelector = find.byType(FileSelector).first;
    final fileButton = find.descendant(
      of: fileSelector,
      matching: find.byType(ElevatedButton),
    );
    await tester.tap(fileButton);
    await tester.pump();
    expect(tapCount, 2);
  });

  testWidgets('NumberField forwards text to controller', (tester) async {
    await setLargeSurface(tester);
    final controller = TextEditingController(text: '1.0');

    await tester.pumpWidget(buildDialogTestApp(
      padding: const EdgeInsets.all(16),
      child: NumberField(
        label: 'Ratio',
        controller: controller,
      ),
    ));

    await tester.enterText(find.byType(TextField), '2.5');
    await tester.pump();

    expect(controller.text, '2.5');
  });
}
