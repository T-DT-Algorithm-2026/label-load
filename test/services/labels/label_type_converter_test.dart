import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/models/label.dart';
import 'package:label_load/models/label_definition.dart';
import 'package:label_load/services/labels/label_type_converter.dart';

void main() {
  group('LabelTypeConverter', () {
    test('same type only updates class id', () {
      final label = Label(
        id: 0,
        x: 0.3,
        y: 0.4,
        width: 0.2,
        height: 0.1,
      );

      final converted = LabelTypeConverter.convert(
        label,
        9,
        LabelType.box,
        LabelType.box,
      );

      expect(converted.id, 9);
      expect(converted.x, closeTo(0.3, 1e-6));
      expect(converted.width, closeTo(0.2, 1e-6));
    });

    test('box to polygon uses bbox corners', () {
      final label = Label(
        id: 0,
        x: 0.5,
        y: 0.5,
        width: 0.2,
        height: 0.4,
      );

      final converted = LabelTypeConverter.convert(
        label,
        2,
        LabelType.box,
        LabelType.polygon,
      );

      expect(converted.id, 2);
      expect(converted.points.length, 4);
      expect(converted.points.first.x, closeTo(0.4, 1e-6));
      expect(converted.points.first.y, closeTo(0.3, 1e-6));
    });

    test('boxWithPoint to box clears points', () {
      final label = Label(
        id: 1,
        x: 0.4,
        y: 0.4,
        width: 0.3,
        height: 0.3,
        points: [LabelPoint(x: 0.1, y: 0.2)],
      );

      final converted = LabelTypeConverter.convert(
        label,
        3,
        LabelType.boxWithPoint,
        LabelType.box,
      );

      expect(converted.id, 3);
      expect(converted.points, isEmpty);
    });

    test('boxWithPoint to polygon keeps points and updates bbox', () {
      final label = Label(
        id: 1,
        x: 0.5,
        y: 0.5,
        width: 0.2,
        height: 0.2,
        points: [
          LabelPoint(x: 0.2, y: 0.2),
          LabelPoint(x: 0.3, y: 0.4),
          LabelPoint(x: 0.25, y: 0.35),
        ],
      );

      final converted = LabelTypeConverter.convert(
        label,
        4,
        LabelType.boxWithPoint,
        LabelType.polygon,
      );

      expect(converted.id, 4);
      expect(converted.points.length, 3);
      expect(converted.bbox[0], closeTo(0.2, 1e-6));
      expect(converted.bbox[3], closeTo(0.4, 1e-6));
    });

    test('boxWithPoint to polygon uses bbox when no points', () {
      final label = Label(
        id: 1,
        x: 0.5,
        y: 0.6,
        width: 0.2,
        height: 0.2,
        points: [],
      );

      final converted = LabelTypeConverter.convert(
        label,
        7,
        LabelType.boxWithPoint,
        LabelType.polygon,
      );

      expect(converted.id, 7);
      expect(converted.points.length, 4);
    });

    test('polygon to boxWithPoint keeps points', () {
      final label = Label(
        id: 2,
        x: 0.5,
        y: 0.6,
        width: 0.3,
        height: 0.2,
        points: [
          LabelPoint(x: 0.4, y: 0.5, visibility: 2),
          LabelPoint(x: 0.6, y: 0.7, visibility: 1),
        ],
      );

      final converted = LabelTypeConverter.convert(
        label,
        8,
        LabelType.polygon,
        LabelType.boxWithPoint,
      );

      expect(converted.id, 8);
      expect(converted.points.length, 2);
      expect(converted.points.first.visibility, 2);
    });

    test('polygon to boxWithPoint keeps id when no points', () {
      final label = Label(
        id: 2,
        x: 0.5,
        y: 0.6,
        width: 0.3,
        height: 0.2,
        points: [],
      );

      final converted = LabelTypeConverter.convert(
        label,
        6,
        LabelType.polygon,
        LabelType.boxWithPoint,
      );

      expect(converted.id, 6);
      expect(converted.points, isEmpty);
    });

    test('polygon to box keeps bbox and clears points', () {
      final label = Label(
        id: 2,
        x: 0.5,
        y: 0.6,
        width: 0.3,
        height: 0.2,
        points: [
          LabelPoint(x: 0.4, y: 0.5),
          LabelPoint(x: 0.6, y: 0.7),
          LabelPoint(x: 0.5, y: 0.6),
        ],
      );

      final converted = LabelTypeConverter.convert(
        label,
        5,
        LabelType.polygon,
        LabelType.box,
      );

      expect(converted.id, 5);
      expect(converted.points, isEmpty);
      expect(converted.x, closeTo(label.x, 1e-6));
      expect(converted.width, closeTo(label.width, 1e-6));
    });
  });
}
