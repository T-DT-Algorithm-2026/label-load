/// Gadgets dialog navigation and directory selection integration tests.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:label_load/pages/project_list_page.dart';
import 'package:label_load/widgets/dialogs/gadgets_dialog.dart';

import '../helpers/integration_test_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(configureIntegrationTestEnvironment);

  testWidgets('open gadgets dialog and switch tools', (tester) async {
    final harness = TestAppHarness();

    const imageDir = '/dataset/images';
    const labelDir = '/dataset/labels';

    harness.gadgetRepository.seedImages(imageDir, [
      '$imageDir/0001.jpg',
      '$imageDir/0002.jpg',
      '$imageDir/0003.jpg',
    ]);
    harness.gadgetRepository.seedLabels(labelDir, [
      '$labelDir/0001.txt',
      '$labelDir/0002.txt',
    ]);

    await tester.pumpWidget(harness.buildApp());
    await pumpUntilFound(tester, find.byType(ProjectListPage));

    final context = tester.element(find.byType(ProjectListPage));
    final l10n = AppLocalizations.of(context)!;

    await tester.tap(find.byTooltip(l10n.toolboxTooltip));
    await tester.pumpAndSettle();
    expect(find.byType(GadgetsDialog), findsOneWidget);

    // Batch rename (default)
    expect(find.text(l10n.gadgetRename), findsWidgets);
    harness.filePickerService.enqueueDirectoryPath(imageDir);
    await tester.tap(find.text(l10n.selectDirButton));
    await tester.pumpAndSettle();
    expect(find.text(l10n.foundNImages(3)), findsOneWidget);

    // Switch to XYXY -> XYWH tool.
    await tester.tap(find.text(l10n.gadgetCoord));
    await tester.pumpAndSettle();
    expect(find.text(l10n.gadgetCoord), findsWidgets);

    harness.filePickerService.enqueueDirectoryPath(labelDir);
    await tester.tap(find.text(l10n.selectDirButton));
    await tester.pumpAndSettle();
    expect(find.text(l10n.foundNLabels(2)), findsOneWidget);
  });
}
