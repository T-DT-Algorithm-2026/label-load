import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/models/label_definition.dart';
import 'package:label_load/widgets/canvas/pointer_up_resolver.dart';

void main() {
  group('resolvePointerUpAction', () {
    test('returns none when labeling and pointer out of image', () {
      final action = resolvePointerUpAction(
        wasClick: true,
        isPolygonClose: false,
        isLabelingMode: true,
        inImage: false,
        lastButtons: 1,
        createButton: 1,
        deleteButton: 2,
        moveButton: 4,
        isTwoClickMode: true,
        labelType: LabelType.boxWithPoint,
      );

      expect(action, PointerUpAction.none);
    });

    test('prefers create when create button is pressed', () {
      final action = resolvePointerUpAction(
        wasClick: true,
        isPolygonClose: false,
        isLabelingMode: false,
        inImage: true,
        lastButtons: 1,
        createButton: 1,
        deleteButton: 2,
        moveButton: 4,
        isTwoClickMode: false,
        labelType: LabelType.box,
      );

      expect(action, PointerUpAction.create);
    });

    test('returns delete when delete button is pressed', () {
      final action = resolvePointerUpAction(
        wasClick: true,
        isPolygonClose: true,
        isLabelingMode: true,
        inImage: true,
        lastButtons: 2,
        createButton: 1,
        deleteButton: 2,
        moveButton: 4,
        isTwoClickMode: false,
        labelType: LabelType.box,
      );

      expect(action, PointerUpAction.delete);
    });

    test('returns moveKeypoint only in two-click boxWithPoint mode', () {
      final action = resolvePointerUpAction(
        wasClick: true,
        isPolygonClose: false,
        isLabelingMode: true,
        inImage: true,
        lastButtons: 4,
        createButton: 1,
        deleteButton: 2,
        moveButton: 4,
        isTwoClickMode: true,
        labelType: LabelType.boxWithPoint,
      );

      expect(action, PointerUpAction.moveKeypoint);
    });

    test('returns none when not a click or polygon close', () {
      final action = resolvePointerUpAction(
        wasClick: false,
        isPolygonClose: false,
        isLabelingMode: false,
        inImage: true,
        lastButtons: 1,
        createButton: 1,
        deleteButton: 2,
        moveButton: 4,
        isTwoClickMode: false,
        labelType: LabelType.box,
      );

      expect(action, PointerUpAction.none);
    });
  });
}
