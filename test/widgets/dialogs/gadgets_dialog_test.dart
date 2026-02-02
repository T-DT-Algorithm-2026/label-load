import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/widgets/dialogs/gadgets_dialog.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('GadgetsDialog switches indexed stack', (tester) async {
    await setLargeSurface(tester, size: const Size(1400, 900));
    final l10n = await loadL10n();
    final services = buildAppServices(
      gadgetService: FakeGadgetService(),
      filePickerService: FakeFilePickerService(),
    );

    await tester.pumpWidget(buildDialogTestApp(
      child: const GadgetsDialog(),
      services: services,
    ));

    var stack = tester.widget<IndexedStack>(find.byType(IndexedStack));
    expect(stack.index, 0);

    await tester.tap(find.text(l10n.gadgetExpand));
    await tester.pumpAndSettle();
    stack = tester.widget<IndexedStack>(find.byType(IndexedStack));
    expect(stack.index, 2);

    await tester.tap(find.text(l10n.gadgetConvert));
    await tester.pumpAndSettle();
    stack = tester.widget<IndexedStack>(find.byType(IndexedStack));
    expect(stack.index, 4);
  });
}
