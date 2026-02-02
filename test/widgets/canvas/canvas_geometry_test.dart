import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/models/label.dart';
import 'package:label_load/widgets/canvas/canvas_geometry.dart';

void main() {
  group('canvas geometry', () {
    test('distanceToSegment returns perpendicular distance', () {
      const p = Offset(0.5, 1.0);
      const s1 = Offset(0.0, 0.0);
      const s2 = Offset(1.0, 0.0);

      final dist = distanceToSegment(p, s1, s2);
      expect(dist, closeTo(1.0, 1e-6));
    });

    test('distanceToSegment clamps to segment end', () {
      const p = Offset(2.0, 0.0);
      const s1 = Offset(0.0, 0.0);
      const s2 = Offset(1.0, 0.0);

      final dist = distanceToSegment(p, s1, s2);
      expect(dist, closeTo(1.0, 1e-6));
    });

    test('distanceToSegment handles zero-length segment', () {
      const p = Offset(2.0, 3.0);
      const s1 = Offset(2.0, 0.0);
      const s2 = Offset(2.0, 0.0);

      final dist = distanceToSegment(p, s1, s2);
      expect(dist, closeTo(3.0, 1e-6));
    });

    test('distanceToSegmentPixels returns correct distance', () {
      const p = Offset(10.0, 20.0);
      const s1 = Offset(10.0, 10.0);
      const s2 = Offset(20.0, 10.0);

      final dist = distanceToSegmentPixels(p, s1, s2);
      expect(dist, closeTo(10.0, 1e-6));
    });

    test('distanceToSegmentPixels handles zero-length segment', () {
      const p = Offset(5.0, 5.0);
      const s1 = Offset(1.0, 1.0);

      final dist = distanceToSegmentPixels(p, s1, s1);
      expect(dist, closeTo(5.656854, 1e-5));
    });

    test('polygonEdgeDistance returns min edge distance', () {
      final polygon = [
        LabelPoint(x: 0.0, y: 0.0),
        LabelPoint(x: 1.0, y: 0.0),
        LabelPoint(x: 1.0, y: 1.0),
        LabelPoint(x: 0.0, y: 1.0),
      ];

      final dist = polygonEdgeDistance(const Offset(0.5, 0.5), polygon);
      expect(dist, closeTo(0.5, 1e-6));
    });

    test('polygonEdgeDistance returns infinity for insufficient points', () {
      final polygon = [
        LabelPoint(x: 0.0, y: 0.0),
      ];

      final dist = polygonEdgeDistance(const Offset(0.2, 0.2), polygon);
      expect(dist, double.infinity);
    });

    test('isPointInPolygon detects inside/outside', () {
      final polygon = [
        LabelPoint(x: 0.0, y: 0.0),
        LabelPoint(x: 1.0, y: 0.0),
        LabelPoint(x: 0.0, y: 1.0),
      ];

      expect(isPointInPolygon(const Offset(0.1, 0.1), polygon), isTrue);
      expect(isPointInPolygon(const Offset(0.9, 0.9), polygon), isFalse);
    });

    test('isPointInBBox detects containment', () {
      const bbox = [0.2, 0.3, 0.4, 0.5];

      expect(isPointInBBox(const Offset(0.3, 0.4), bbox), isTrue);
      expect(isPointInBBox(const Offset(0.1, 0.4), bbox), isFalse);
    });
  });
}
