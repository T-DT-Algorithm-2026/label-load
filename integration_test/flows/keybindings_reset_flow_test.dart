/// Key bindings reset integration test.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:label_load/pages/project_list_page.dart';
import 'package:label_load/providers/keybindings_provider.dart';
import 'package:label_load/widgets/dialogs/global_settings_dialog.dart';
import 'package:label_load/widgets/dialogs/keybindings_dialog.dart';

import '../helpers/integration_test_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(configureIntegrationTestEnvironment);

  testWidgets('reset key bindings restores defaults', (tester) async {
    final harness = TestAppHarness();

    await tester.pumpWidget(harness.buildApp());
    await pumpUntilFound(tester, find.byType(ProjectListPage));

    final context = tester.element(find.byType(ProjectListPage));
    final l10n = AppLocalizations.of(context)!;

    final keyBindingsProvider =
        Provider.of<KeyBindingsProvider>(context, listen: false);
    await keyBindingsProvider.setBinding(
      BindableAction.nextImage,
      KeyBinding.none,
    );
    expect(
      keyBindingsProvider.getBinding(BindableAction.nextImage).isNone,
      isTrue,
    );

    await tester.tap(find.byTooltip(l10n.globalSettingsTooltip));
    await tester.pumpAndSettle();
    expect(find.byType(GlobalSettingsDialog), findsOneWidget);

    await tester.ensureVisible(find.text(l10n.keyBindingsTitle));
    await tester.tap(find.text(l10n.keyBindingsTitle));
    await tester.pumpAndSettle();
    expect(find.byType(KeyBindingsDialog), findsOneWidget);

    await tester.tap(find.text(l10n.resetToDefault));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.reset));
    await tester.pumpAndSettle();

    expect(
      keyBindingsProvider.getBinding(BindableAction.nextImage).isNone,
      isFalse,
    );
  });
}
