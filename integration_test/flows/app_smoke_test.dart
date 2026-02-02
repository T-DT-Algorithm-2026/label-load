/// App startup and global settings integration tests.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:label_load/pages/project_list_page.dart';
import 'package:label_load/providers/theme_provider.dart';
import 'package:label_load/widgets/dialogs/global_settings_dialog.dart';

import '../helpers/integration_test_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(configureIntegrationTestEnvironment);

  testWidgets('launch shows project list and settings dialog toggles theme',
      (tester) async {
    final harness = TestAppHarness();

    await tester.pumpWidget(harness.buildApp());
    await pumpUntilFound(tester, find.byType(ProjectListPage));

    final context = tester.element(find.byType(ProjectListPage));
    final l10n = AppLocalizations.of(context)!;

    await pumpUntilFound(tester, find.text(l10n.noProjects));
    expect(find.text(l10n.noProjects), findsOneWidget);

    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final wasDark = themeProvider.isDarkMode;

    await tester.tap(find.byTooltip(l10n.globalSettingsTooltip));
    await tester.pumpAndSettle();
    expect(find.byType(GlobalSettingsDialog), findsOneWidget);

    final themeLabel = wasDark ? l10n.darkMode : l10n.lightMode;
    await tester.tap(find.widgetWithText(SwitchListTile, themeLabel));
    await tester.pumpAndSettle();

    expect(themeProvider.isDarkMode, isNot(equals(wasDark)));

    await tester.ensureVisible(find.text(l10n.close));
    await tester.tap(find.text(l10n.close));
    await tester.pumpAndSettle();
    expect(find.byType(GlobalSettingsDialog), findsNothing);
  });
}
