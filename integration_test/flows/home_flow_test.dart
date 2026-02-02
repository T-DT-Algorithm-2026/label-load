/// Home page labeling and navigation integration tests.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:label_load/models/label.dart';
import 'package:label_load/models/label_definition.dart';
import 'package:label_load/models/project_config.dart';
import 'package:label_load/pages/home_page.dart';
import 'package:label_load/pages/project_list_page.dart';
import 'package:label_load/providers/project_provider.dart';
import 'package:label_load/widgets/canvas/image_canvas.dart';
import 'package:label_load/widgets/sidebar/sidebar.dart';

import '../helpers/integration_test_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(configureIntegrationTestEnvironment);

  testWidgets('label list, save, and image navigation work end-to-end',
      (tester) async {
    const imageDir = '/images';
    const labelDir = '/labels';
    const images = <String>[
      '$imageDir/img_001.png',
      '$imageDir/img_002.png',
    ];

    final definitions = [
      LabelDefinition(
        classId: 0,
        name: 'Person',
        color: const Color(0xFF22C55E),
      ),
    ];

    final config = ProjectConfig(
      name: 'Flow Project',
      imagePath: imageDir,
      labelPath: labelDir,
      labelDefinitions: definitions,
    );

    const labelPath = '$labelDir/img_001.txt';
    final labelsByPath = {
      labelPath: [
        Label(
          id: 0,
          name: 'Person',
          x: 0.5,
          y: 0.5,
          width: 0.2,
          height: 0.2,
        ),
      ],
    };

    final harness = TestAppHarness(
      initialProjects: [config],
      imageListing: {imageDir: images},
      imageBytesByPath: {
        for (final path in images) path: testPngBytes,
      },
      labelsByPath: labelsByPath,
    );

    await tester.pumpWidget(harness.buildApp());
    await pumpUntilFound(tester, find.byType(ProjectListPage));

    final context = tester.element(find.byType(ProjectListPage));
    final l10n = AppLocalizations.of(context)!;

    await pumpUntilFound(tester, find.text('Flow Project'));
    await tester.tap(find.byType(Card).first);
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);

    await pumpUntilFound(tester, find.byType(ImageCanvas));
    await pumpUntilFound(tester, find.text('Person'));

    final labelDeleteButtons = find.descendant(
      of: find.byType(Sidebar),
      matching: find.byIcon(Icons.delete_outline),
    );
    await tester.tap(labelDeleteButtons.first);
    await tester.pumpAndSettle();

    expect(find.text(l10n.noLabels), findsOneWidget);

    await tester.tap(find.byIcon(Icons.save_outlined));
    await tester.pumpAndSettle();

    final projectProvider =
        Provider.of<ProjectProvider>(context, listen: false);
    expect(projectProvider.isDirty, isFalse);

    final (savedLabels, _) =
        await harness.labelRepository.readLabels(labelPath, (_) => '');
    expect(savedLabels, isEmpty);

    await tester.tap(find.text(l10n.tabImages));
    await tester.pumpAndSettle();

    await tester.tap(find.text('img_002.png'));
    await tester.pumpAndSettle();
    expect(
      projectProvider.currentImagePath?.endsWith('img_002.png'),
      isTrue,
    );
  });
}
