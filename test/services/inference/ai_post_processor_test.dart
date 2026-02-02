import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/services/inference/ai_post_processor.dart';
import 'package:label_load/models/label.dart';
import 'package:label_load/models/label_definition.dart';

void main() {
  group('AiPostProcessor', () {
    const processor = AiPostProcessor();

    test('applyClassIdOffset should shift label ids', () {
      final labels = [Label(id: 1), Label(id: 2)];
      processor.applyClassIdOffset(labels, 2);
      expect(labels[0].id, 3);
      expect(labels[1].id, 4);
    });

    test('applyClassIdOffset with 0 should keep ids', () {
      final labels = [Label(id: 1), Label(id: 2)];
      processor.applyClassIdOffset(labels, 0);
      expect(labels[0].id, 1);
      expect(labels[1].id, 2);
    });

    test('sanitizeLabels clears points and extraData for box type', () {
      final labels = [
        Label(
          id: 1,
          points: [LabelPoint(x: 0.1, y: 0.2, visibility: 2)],
          extraData: ['a', 'b'],
        ),
        Label(
          id: 2,
          points: [LabelPoint(x: 0.3, y: 0.4, visibility: 1)],
          extraData: ['x'],
        ),
      ];
      final definitions = [
        LabelDefinition(
          classId: 1,
          name: 'box',
          color: const Color(0xFF000000),
          type: LabelType.box,
        ),
        LabelDefinition(
          classId: 2,
          name: 'pose',
          color: const Color(0xFF111111),
          type: LabelType.boxWithPoint,
        ),
      ];

      processor.sanitizeLabels(labels, definitions);

      expect(labels[0].points, isEmpty);
      expect(labels[0].extraData, isEmpty);
      expect(labels[1].points, isNotEmpty);
      expect(labels[1].extraData, isNotEmpty);
    });

    test('sanitizeLabels keeps points when definition is missing', () {
      final labels = [
        Label(
          id: 5,
          points: [LabelPoint(x: 0.1, y: 0.2, visibility: 2)],
          extraData: ['a'],
        ),
      ];

      const definitions = <LabelDefinition>[];

      processor.sanitizeLabels(labels, definitions);

      expect(labels[0].points, isNotEmpty);
      expect(labels[0].extraData, isNotEmpty);
    });

    test('fillMissingDefinitions adds inferred definitions and keeps order',
        () {
      final labels = [
        Label(id: 0),
        Label(
          id: 3,
          points: [LabelPoint(x: 0.2, y: 0.3, visibility: 2)],
        ),
      ];
      final definitions = [
        LabelDefinition(
          classId: 0,
          name: 'class_0',
          color: const Color(0xFF123456),
          type: LabelType.box,
        ),
      ];

      final updated = processor.fillMissingDefinitions(labels, definitions);

      expect(updated.length, 2);
      expect(updated[0].classId, 0);
      expect(updated[1].classId, 3);
      expect(updated[1].type, LabelType.boxWithPoint);
      expect(
        updated[1].color,
        LabelPalettes.defaultPalette[3 % LabelPalettes.defaultPalette.length],
      );
    });

    test('fillMissingDefinitions returns same list when no missing ids', () {
      final labels = [Label(id: 0)];
      final definitions = [
        LabelDefinition(
          classId: 0,
          name: 'class_0',
          color: const Color(0xFF123456),
          type: LabelType.box,
        ),
      ];

      final updated = processor.fillMissingDefinitions(labels, definitions);

      expect(identical(updated, definitions), isTrue);
    });
  });
}
