import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/models/label_definition.dart';
import 'package:label_load/widgets/canvas/pan_start_resolver.dart';

void main() {
  group('resolvePanStartAction', () {
    test('ignores when moveActive or create inactive', () {
      expect(
        resolvePanStartAction(
          isLabelingMode: true,
          inImage: true,
          createActive: false,
          moveActive: false,
          isTwoClickMode: false,
          labelType: LabelType.box,
        ),
        PanStartAction.none,
      );
      expect(
        resolvePanStartAction(
          isLabelingMode: true,
          inImage: true,
          createActive: true,
          moveActive: true,
          isTwoClickMode: false,
          labelType: LabelType.box,
        ),
        PanStartAction.none,
      );
    });

    test('labeling mode only allows drag for box types', () {
      expect(
        resolvePanStartAction(
          isLabelingMode: true,
          inImage: true,
          createActive: true,
          moveActive: false,
          isTwoClickMode: false,
          labelType: LabelType.box,
        ),
        PanStartAction.draw,
      );
      expect(
        resolvePanStartAction(
          isLabelingMode: true,
          inImage: true,
          createActive: true,
          moveActive: false,
          isTwoClickMode: false,
          labelType: LabelType.boxWithPoint,
        ),
        PanStartAction.draw,
      );
      expect(
        resolvePanStartAction(
          isLabelingMode: true,
          inImage: true,
          createActive: true,
          moveActive: false,
          isTwoClickMode: false,
          labelType: LabelType.polygon,
        ),
        PanStartAction.none,
      );
    });

    test('two-click mode suppresses drag even for boxes', () {
      expect(
        resolvePanStartAction(
          isLabelingMode: true,
          inImage: true,
          createActive: true,
          moveActive: false,
          isTwoClickMode: true,
          labelType: LabelType.box,
        ),
        PanStartAction.none,
      );
    });

    test('edit mode returns edit action', () {
      expect(
        resolvePanStartAction(
          isLabelingMode: false,
          inImage: true,
          createActive: true,
          moveActive: false,
          isTwoClickMode: false,
          labelType: LabelType.box,
        ),
        PanStartAction.edit,
      );
    });

    test('labeling mode rejects drag when out of image', () {
      expect(
        resolvePanStartAction(
          isLabelingMode: true,
          inImage: false,
          createActive: true,
          moveActive: false,
          isTwoClickMode: false,
          labelType: LabelType.box,
        ),
        PanStartAction.none,
      );
    });
  });
}
