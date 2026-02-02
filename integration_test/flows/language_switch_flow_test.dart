/// Language switch integration test.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:label_load/pages/project_list_page.dart';
import 'package:label_load/providers/project_provider.dart';
import 'package:label_load/widgets/dialogs/global_settings_dialog.dart';

import '../helpers/integration_test_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(configureIntegrationTestEnvironment);

  testWidgets('switch language updates project locale', (tester) async {
    final harness = TestAppHarness();

    await tester.pumpWidget(harness.buildApp());
    await pumpUntilFound(tester, find.byType(ProjectListPage));

    final context = tester.element(find.byType(ProjectListPage));
    final l10n = AppLocalizations.of(context)!;

    final projectProvider =
        Provider.of<ProjectProvider>(context, listen: false);
    expect(projectProvider.config.locale, equals('zh'));

    await tester.tap(find.byTooltip(l10n.globalSettingsTooltip));
    await tester.pumpAndSettle();
    expect(find.byType(GlobalSettingsDialog), findsOneWidget);

    await tester.ensureVisible(find.text(l10n.language));
    await tester.tap(find.text(l10n.chinese));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.english).last);
    await tester.pumpAndSettle();

    expect(projectProvider.config.locale, equals('en'));
  });
}
