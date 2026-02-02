import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/widgets/canvas/pointer_hover_resolver.dart';

void main() {
  group('resolveHoverAction', () {
    test('clears hover when labeling and pointer outside image', () {
      expect(
        resolveHoverAction(
          isLabelingMode: true,
          inImage: false,
        ),
        HoverAction.clear,
      );
    });

    test('updates hover when labeling and pointer inside image', () {
      expect(
        resolveHoverAction(
          isLabelingMode: true,
          inImage: true,
        ),
        HoverAction.update,
      );
    });

    test('updates hover when not labeling', () {
      expect(
        resolveHoverAction(
          isLabelingMode: false,
          inImage: false,
        ),
        HoverAction.update,
      );
    });
  });
}
