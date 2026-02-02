import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/widgets/canvas/pointer_down_resolver.dart';

void main() {
  group('resolvePointerDownAction', () {
    test('rejects when create inactive or disallowed', () {
      expect(
        resolvePointerDownAction(
          isLabelingMode: false,
          inImage: true,
          createActive: false,
          allowCreate: true,
        ),
        PointerDownAction.none,
      );
      expect(
        resolvePointerDownAction(
          isLabelingMode: false,
          inImage: true,
          createActive: true,
          allowCreate: false,
        ),
        PointerDownAction.none,
      );
    });

    test('labeling mode requires pointer inside image', () {
      expect(
        resolvePointerDownAction(
          isLabelingMode: true,
          inImage: false,
          createActive: true,
          allowCreate: true,
        ),
        PointerDownAction.none,
      );
      expect(
        resolvePointerDownAction(
          isLabelingMode: true,
          inImage: true,
          createActive: true,
          allowCreate: true,
        ),
        PointerDownAction.startCreateDrag,
      );
    });

    test('editing mode allows when create active and allowed', () {
      expect(
        resolvePointerDownAction(
          isLabelingMode: false,
          inImage: false,
          createActive: true,
          allowCreate: true,
        ),
        PointerDownAction.startCreateDrag,
      );
    });
  });
}
