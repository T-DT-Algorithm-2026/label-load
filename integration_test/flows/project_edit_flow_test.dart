/// Project edit integration tests.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:label_load/models/label_definition.dart';
import 'package:label_load/models/project_config.dart';
import 'package:label_load/pages/project_list_page.dart';
import 'package:label_load/pages/project_settings_page.dart';

import '../helpers/integration_test_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(configureIntegrationTestEnvironment);

  testWidgets('edit project updates list card and repository', (tester) async {
    final config = ProjectConfig(
      name: 'Initial Project',
      description: 'Initial description',
      imagePath: '/images',
      labelPath: '/labels',
      labelDefinitions: [
        LabelDefinition(
          classId: 0,
          name: 'Person',
          color: const Color(0xFF00AAFF),
        ),
      ],
    );

    final harness = TestAppHarness(initialProjects: [config]);

    await tester.pumpWidget(harness.buildApp());
    await pumpUntilFound(tester, find.byType(ProjectListPage));

    final context = tester.element(find.byType(ProjectListPage));
    final l10n = AppLocalizations.of(context)!;

    await pumpUntilFound(tester, find.text('Initial Project'));
    expect(find.text('Initial Project'), findsOneWidget);

    final card = find.byType(Card).first;
    await tester.tap(
      find.descendant(
        of: card,
        matching: find.byIcon(Icons.settings),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ProjectSettingsPage), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, l10n.projectName),
      'Renamed Project',
    );

    await tester.tap(find.byIcon(Icons.save));
    await tester.pumpAndSettle();

    expect(find.text('Renamed Project'), findsOneWidget);
    expect(find.text('Initial Project'), findsNothing);

    expect(harness.projectListRepository.projects.single.name,
        equals('Renamed Project'));
  });
}
