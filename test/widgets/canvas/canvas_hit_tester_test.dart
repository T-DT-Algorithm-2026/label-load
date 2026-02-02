import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/models/label.dart';
import 'package:label_load/models/label_definition.dart';
import 'package:label_load/widgets/canvas/canvas_hit_tester.dart';

void main() {
  group('CanvasHitTester', () {
    test('findHandleAt returns nearest handle inside radius', () {
      final label = Label(
        id: 0,
        x: 0.5,
        y: 0.5,
        width: 0.4,
        height: 0.4,
      );

      final hit = CanvasHitTester.findHandleAt(
        localPos: const Offset(31, 31),
        label: label,
        imageSize: const Size(100, 100),
        pointHitRadius: 10,
        scale: 1,
      );

      expect(hit, 0);
    });

    test('findKeypointAt respects visibility flag', () {
      final label = Label(
        id: 0,
        points: [
          LabelPoint(x: 0.2, y: 0.2, visibility: 2),
          LabelPoint(x: 0.4, y: 0.4, visibility: 0),
        ],
      );

      final visibleHit = CanvasHitTester.findKeypointAt(
        normalized: const Offset(0.2, 0.2),
        labels: [label],
        imageSize: const Size(100, 100),
        pointHitRadius: 10,
        scale: 1,
        showUnlabeledPoints: false,
      );

      final hiddenHit = CanvasHitTester.findKeypointAt(
        normalized: const Offset(0.4, 0.4),
        labels: [label],
        imageSize: const Size(100, 100),
        pointHitRadius: 10,
        scale: 1,
        showUnlabeledPoints: false,
      );

      expect(visibleHit?.pointIndex, 0);
      expect(hiddenHit, isNull);
    });

    test('findEdgeAt detects closest polygon edge', () {
      final label = Label(
        id: 0,
        points: [
          LabelPoint(x: 0.1, y: 0.1),
          LabelPoint(x: 0.9, y: 0.1),
          LabelPoint(x: 0.9, y: 0.9),
          LabelPoint(x: 0.1, y: 0.9),
        ],
      );

      final edge = CanvasHitTester.findEdgeAt(
        localPos: const Offset(50, 11),
        label: label,
        imageSize: const Size(100, 100),
        pointHitRadius: 12,
        scale: 1,
      );

      expect(edge, 0);
    });

    test('findLabelAt prefers closest edge and handles polygon types', () {
      final polygon = Label(
        id: 0,
        points: [
          LabelPoint(x: 0.1, y: 0.1),
          LabelPoint(x: 0.9, y: 0.1),
          LabelPoint(x: 0.9, y: 0.9),
          LabelPoint(x: 0.1, y: 0.9),
        ],
      )..updateBboxFromPoints();

      final box = Label(
        id: 1,
        x: 0.5,
        y: 0.5,
        width: 0.2,
        height: 0.2,
      );

      final definitions = [
        LabelDefinition(
          classId: 0,
          name: 'poly',
          color: Colors.red,
          type: LabelType.polygon,
        ),
        LabelDefinition(
          classId: 1,
          name: 'box',
          color: Colors.blue,
          type: LabelType.box,
        ),
      ];

      final hit = CanvasHitTester.findLabelAt(
        normalized: const Offset(0.5, 0.5),
        labels: [polygon, box],
        definitions: definitions,
      );

      expect(hit, 1);
    });
  });
}
