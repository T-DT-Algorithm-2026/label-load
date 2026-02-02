/// Settings toggles and toolbar delete-image integration tests.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:label_load/models/label_definition.dart';
import 'package:label_load/models/project_config.dart';
import 'package:label_load/pages/home_page.dart';
import 'package:label_load/pages/project_list_page.dart';
import 'package:label_load/providers/project_provider.dart';
import 'package:label_load/providers/settings_provider.dart';
import 'package:label_load/widgets/dialogs/global_settings_dialog.dart';

import '../helpers/integration_test_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(configureIntegrationTestEnvironment);

  testWidgets('toggle settings and delete current image', (tester) async {
    const imageDir = '/images';
    const labelDir = '/labels';
    final images = <String>[
      '$imageDir/img_001.png',
      '$imageDir/img_002.png',
    ];

    final config = ProjectConfig(
      name: 'Toolbar Project',
      imagePath: imageDir,
      labelPath: labelDir,
      labelDefinitions: [
        LabelDefinition(
          classId: 0,
          name: 'Person',
          color: const Color(0xFFF59E0B),
        ),
      ],
    );

    final harness = TestAppHarness(
      initialProjects: [config],
      imageListing: {imageDir: images},
      imageBytesByPath: {
        for (final path in images) path: testPngBytes,
      },
    );

    await tester.pumpWidget(harness.buildApp());
    await pumpUntilFound(tester, find.byType(ProjectListPage));

    final listContext = tester.element(find.byType(ProjectListPage));
    final l10n = AppLocalizations.of(listContext)!;

    await tester.tap(find.byTooltip(l10n.globalSettingsTooltip));
    await tester.pumpAndSettle();
    expect(find.byType(GlobalSettingsDialog), findsOneWidget);

    final settingsProvider =
        Provider.of<SettingsProvider>(listContext, listen: false);
    final wasAutoSave = settingsProvider.autoSaveOnNavigate;

    await tester.ensureVisible(find.text(l10n.autoSave));
    await tester.tap(find.widgetWithText(SwitchListTile, l10n.autoSave));
    await tester.pumpAndSettle();
    expect(settingsProvider.autoSaveOnNavigate, isNot(equals(wasAutoSave)));

    await tester.ensureVisible(find.text(l10n.close));
    await tester.tap(find.text(l10n.close));
    await tester.pumpAndSettle();

    await pumpUntilFound(tester, find.text('Toolbar Project'));
    await tester.tap(find.byType(Card).first);
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);

    final context = tester.element(find.byType(HomePage));

    final projectProvider =
        Provider.of<ProjectProvider>(context, listen: false);
    expect(projectProvider.totalImages, equals(2));

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.delete));
    await tester.pumpAndSettle();

    expect(projectProvider.totalImages, equals(1));
    expect(
      projectProvider.currentImagePath?.endsWith('img_002.png'),
      isTrue,
    );
  });
}
