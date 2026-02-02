/// Label definition import/export integration tests.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:label_load/pages/project_list_page.dart';
import 'package:label_load/pages/project_settings_page.dart';

import '../helpers/integration_test_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(configureIntegrationTestEnvironment);

  testWidgets('import and export label definitions from project settings',
      (tester) async {
    final harness = TestAppHarness();

    await tester.pumpWidget(harness.buildApp());
    await pumpUntilFound(tester, find.byType(ProjectListPage));

    final context = tester.element(find.byType(ProjectListPage));
    final l10n = AppLocalizations.of(context)!;

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.byType(ProjectSettingsPage), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, l10n.projectName),
      'Import Export Project',
    );

    const importPath = '/tmp/labels_import.json';
    const exportPath = '/tmp/labels_export.json';

    const importPayload = [
      {
        'classId': 0,
        'name': 'Cat',
        'color': 0xFF22C55E,
        'type': 0,
      },
      {
        'classId': 1,
        'name': 'Dog',
        'color': 0xFF0EA5E9,
        'type': 0,
      },
    ];

    await harness.textFileRepository.writeString(
      importPath,
      jsonEncode(importPayload),
    );

    harness.filePickerService.enqueueFilePath(importPath);
    await tester.tap(find.byIcon(Icons.file_upload));
    await tester.pumpAndSettle();

    await pumpUntilFound(tester, find.text('Cat'));
    expect(find.text('Cat'), findsOneWidget);
    expect(find.text('Dog'), findsOneWidget);

    harness.filePickerService.enqueueSavePath(exportPath);
    await tester.tap(find.byIcon(Icons.file_download));
    await tester.pumpAndSettle();

    final exported = harness.textFileRepository.peek(exportPath);
    expect(exported, isNotNull);
    final decoded = jsonDecode(exported!) as List<dynamic>;
    expect(decoded.length, equals(2));
  });
}
