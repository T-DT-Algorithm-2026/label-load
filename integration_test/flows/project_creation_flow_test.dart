/// Project creation integration tests.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:label_load/pages/home_page.dart';
import 'package:label_load/pages/project_list_page.dart';
import 'package:label_load/pages/project_settings_page.dart';
import 'package:label_load/providers/project_provider.dart';
import 'package:label_load/widgets/canvas/image_canvas.dart';

import '../helpers/integration_test_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(configureIntegrationTestEnvironment);

  testWidgets('create project with label definitions and open it',
      (tester) async {
    const imageDir = '/images';
    const labelDir = '/labels';
    final images = <String>[
      '$imageDir/img_001.png',
      '$imageDir/img_002.png',
    ];

    final harness = TestAppHarness(
      imageListing: {imageDir: images},
      imageBytesByPath: {
        for (final path in images) path: testPngBytes,
      },
    );
    harness.filePickerService.enqueueDirectoryPath(imageDir);
    harness.filePickerService.enqueueDirectoryPath(labelDir);

    await tester.pumpWidget(harness.buildApp());
    await pumpUntilFound(tester, find.byType(ProjectListPage));

    final context = tester.element(find.byType(ProjectListPage));
    final l10n = AppLocalizations.of(context)!;

    await pumpUntilFound(tester, find.text(l10n.noProjects));

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.byType(ProjectSettingsPage), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, l10n.projectName),
      'Demo Project',
    );
    await tester.enterText(
      find.widgetWithText(TextField, l10n.projectDesc),
      'Integration flow project',
    );

    final folderButtons = find.widgetWithIcon(IconButton, Icons.folder_open);
    await tester.tap(folderButtons.at(0));
    await tester.pumpAndSettle();
    await tester.tap(folderButtons.at(1));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithIcon(IconButton, Icons.add));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, l10n.labelName),
      'Person',
    );
    await tester.tap(find.text(l10n.save));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.save));
    await tester.pumpAndSettle();

    expect(find.text('Demo Project'), findsOneWidget);
    expect(find.text(l10n.labelsCount(1)), findsOneWidget);

    await tester.tap(find.byType(Card).first);
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);

    await pumpUntilFound(tester, find.byType(ImageCanvas));

    final projectProvider =
        Provider.of<ProjectProvider>(context, listen: false);
    expect(projectProvider.totalImages, images.length);
  });
}
