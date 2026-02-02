import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/widgets/canvas/label_text_metrics.dart';

void main() {
  group('LabelTextMetrics', () {
    test('buildTextRect positions above label rect', () {
      final rect = LabelTextMetrics.buildTextRect(
        labelRect: const ui.Rect.fromLTWH(10, 20, 50, 40),
        text: 'class_0',
        maxWidth: 200,
      );

      expect(rect.left, 10);
      expect(rect.top, 0);
      expect(rect.height, 18);
    });

    test('isHovered returns true when mouse is inside', () {
      const rect = ui.Rect.fromLTWH(0, 0, 50, 18);
      final hovered = LabelTextMetrics.isHovered(
        textRect: rect,
        mousePosition: const ui.Offset(0.1, 0.05),
        canvasSize: const ui.Size(100, 100),
      );

      expect(hovered, isTrue);
    });

    test('isHovered returns false when mouse is null', () {
      const rect = ui.Rect.fromLTWH(0, 0, 50, 18);
      final hovered = LabelTextMetrics.isHovered(
        textRect: rect,
        mousePosition: null,
        canvasSize: const ui.Size(100, 100),
      );

      expect(hovered, isFalse);
    });
  });
}
