import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:label_load/widgets/canvas/resize_utils.dart';

void main() {
  group('resizeRectFromHandle', () {
    test('resizes from top-left handle', () {
      const base = Rect.fromLTRB(0.1, 0.1, 0.3, 0.3);
      final rect = resizeRectFromHandle(
        base: base,
        current: const Offset(0.05, 0.05),
        handle: 0,
      );

      expect(rect.left, 0.05);
      expect(rect.top, 0.05);
      expect(rect.right, 0.3);
      expect(rect.bottom, 0.3);
    });

    test('resizes from bottom-right handle', () {
      const base = Rect.fromLTRB(0.1, 0.1, 0.3, 0.3);
      final rect = resizeRectFromHandle(
        base: base,
        current: const Offset(0.4, 0.4),
        handle: 2,
      );

      expect(rect.left, 0.1);
      expect(rect.top, 0.1);
      expect(rect.right, 0.4);
      expect(rect.bottom, 0.4);
    });

    test('resizes from top-right handle', () {
      const base = Rect.fromLTRB(0.1, 0.1, 0.3, 0.3);
      final rect = resizeRectFromHandle(
        base: base,
        current: const Offset(0.4, 0.0),
        handle: 1,
      );

      expect(rect.left, 0.1);
      expect(rect.top, 0.0);
      expect(rect.right, 0.4);
      expect(rect.bottom, 0.3);
    });

    test('crossing over keeps anchor at opposite corner', () {
      const base = Rect.fromLTRB(0.1, 0.1, 0.3, 0.3);
      final rect = resizeRectFromHandle(
        base: base,
        current: const Offset(0.5, 0.5),
        handle: 0,
      );

      expect(rect.left, 0.3);
      expect(rect.top, 0.3);
      expect(rect.right, 0.5);
      expect(rect.bottom, 0.5);
    });
  });
}
