import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/models/label_definition.dart';
import 'package:label_load/services/inference/inference_label_mapper.dart';

class FakeKeypoint {
  FakeKeypoint(this.x, this.y, this.visibility);

  final double x;
  final double y;
  final double visibility;
}

class FakeDetection {
  FakeDetection({
    required this.classId,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.keypoints,
  });

  final int classId;
  final double x;
  final double y;
  final double width;
  final double height;
  final List<FakeKeypoint>? keypoints;
}

void main() {
  group('InferenceLabelMapper', () {
    test('maps detections with class names and bbox', () {
      final detections = [
        FakeDetection(
          classId: 1,
          x: 0.2,
          y: 0.3,
          width: 0.4,
          height: 0.5,
        ),
      ];

      final defs = [
        LabelDefinition(
          classId: 1,
          name: 'person',
          color: const Color(0xFF000000),
        ),
      ];

      final labels = InferenceLabelMapper.fromDetections(detections, defs);

      expect(labels.length, 1);
      expect(labels.first.name, 'person');
      expect(labels.first.x, closeTo(0.2, 1e-6));
    });

    test('falls back to class_id when definition is missing', () {
      final detections = [
        FakeDetection(
          classId: 3,
          x: 0.1,
          y: 0.2,
          width: 0.3,
          height: 0.4,
        ),
      ];

      final labels = InferenceLabelMapper.fromDetections(detections, const []);

      expect(labels.first.name, 'class_3');
    });

    test('maps keypoints and visibility thresholds', () {
      final detections = [
        FakeDetection(
          classId: 0,
          x: 0.1,
          y: 0.2,
          width: 0.3,
          height: 0.4,
          keypoints: [
            FakeKeypoint(0.1, 0.2, 0.6),
            FakeKeypoint(0.2, 0.3, 0.3),
            FakeKeypoint(0.3, 0.4, 0.1),
          ],
        ),
      ];

      final labels = InferenceLabelMapper.fromDetections(detections, const []);
      final points = labels.first.points;

      expect(points.length, 3);
      expect(points[0].visibility, 2);
      expect(points[1].visibility, 1);
      expect(points[2].visibility, 0);
    });
  });
}
