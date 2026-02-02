import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/models/label.dart';
import 'package:label_load/models/label_definition.dart';
import 'package:label_load/widgets/canvas/label_painter.dart';

void main() {
  testWidgets('LabelPainter paints box labels with handles and keypoints',
      (tester) async {
    final label = Label(
      id: 0,
      x: 0.5,
      y: 0.5,
      width: 0.3,
      height: 0.3,
      points: [
        LabelPoint(x: 0.45, y: 0.45, visibility: 2),
        LabelPoint(x: 0.55, y: 0.55, visibility: 0),
      ],
    );

    final definitions = [
      LabelDefinition(
        classId: 0,
        name: 'box',
        color: Colors.orange,
        type: LabelType.box,
      ),
    ];

    final painter = LabelPainter(
      labels: [label],
      selectedIndex: 0,
      activeKeypointIndex: 0,
      hoveredIndex: 0,
      drawingRect: const Rect.fromLTWH(0.1, 0.1, 0.2, 0.2),
      currentClassId: 0,
      definitions: definitions,
      activeHandle: 0,
      isLabelingMode: true,
      showCrosshair: true,
      mousePosition: const Offset(0.11, 0.11),
      polygonPoints: const [
        Offset(0.1, 0.1),
        Offset(0.2, 0.1),
        Offset(0.2, 0.2),
      ],
      hoveredHandle: 0,
      hoveredKeypointIndex: 0,
      hoveredKeypointLabelIndex: 0,
      hoveredVertexIndex: null,
      pointSize: 6,
      currentScale: 1,
      pointHitRadius: 60,
      fillShape: true,
      showUnlabeledPoints: false,
    );

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    painter.paint(canvas, const Size(100, 100));
    recorder.endRecording();

    expect(
      painter.shouldRepaint(LabelPainter(
        labels: [label],
        currentClassId: 0,
        definitions: definitions,
        polygonPoints: const [],
        isLabelingMode: false,
      )),
      isTrue,
    );
  });

  testWidgets('LabelPainter paints polygon labels with vertices',
      (tester) async {
    final polygon = Label(
      id: 1,
      points: [
        LabelPoint(x: 0.2, y: 0.2),
        LabelPoint(x: 0.8, y: 0.2),
        LabelPoint(x: 0.8, y: 0.8),
        LabelPoint(x: 0.2, y: 0.8),
      ],
    )..updateBboxFromPoints();

    final definitions = [
      LabelDefinition(
        classId: 1,
        name: 'poly',
        color: Colors.green,
        type: LabelType.polygon,
      ),
    ];

    final painter = LabelPainter(
      labels: [polygon],
      selectedIndex: 0,
      activeKeypointIndex: 1,
      hoveredIndex: 0,
      drawingRect: null,
      currentClassId: 1,
      definitions: definitions,
      activeHandle: null,
      isLabelingMode: false,
      showCrosshair: false,
      mousePosition: const Offset(0.4, 0.4),
      polygonPoints: const [],
      hoveredHandle: null,
      hoveredKeypointIndex: null,
      hoveredKeypointLabelIndex: null,
      hoveredVertexIndex: 2,
      pointSize: 6,
      currentScale: 1,
      pointHitRadius: 60,
      fillShape: true,
      showUnlabeledPoints: true,
    );

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    painter.paint(canvas, const Size(100, 100));
    recorder.endRecording();
  });
}
