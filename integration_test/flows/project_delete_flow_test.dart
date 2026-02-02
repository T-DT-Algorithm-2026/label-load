/// Project deletion integration tests.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:label_load/models/project_config.dart';
import 'package:label_load/pages/project_list_page.dart';

import '../helpers/integration_test_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(configureIntegrationTestEnvironment);

  testWidgets('delete project removes card and repository entry',
      (tester) async {
    final config = ProjectConfig(
      name: 'Delete Me',
      description: 'Disposable project',
      imagePath: '/images',
      labelPath: '/labels',
    );

    final harness = TestAppHarness(initialProjects: [config]);

    await tester.pumpWidget(harness.buildApp());
    await pumpUntilFound(tester, find.byType(ProjectListPage));

    final context = tester.element(find.byType(ProjectListPage));
    final l10n = AppLocalizations.of(context)!;

    await pumpUntilFound(tester, find.text('Delete Me'));
    expect(find.text('Delete Me'), findsOneWidget);

    final card = find.byType(Card).first;
    await tester
        .tap(find.descendant(of: card, matching: find.byIcon(Icons.delete)));
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.delete));
    await tester.pumpAndSettle();

    expect(find.text('Delete Me'), findsNothing);
    expect(harness.projectListRepository.projects, isEmpty);
  });
}
