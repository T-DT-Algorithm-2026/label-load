import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/widgets/canvas/handle_utils.dart';
import 'package:flutter/material.dart';

void main() {
  test('buildHandlePoints returns 8 points in expected order', () {
    const rect = Rect.fromLTWH(10, 20, 30, 40);
    final handles = buildHandlePoints(rect);

    expect(handles.length, 8);
    expect(handles[0], rect.topLeft);
    expect(handles[1], rect.topRight);
    expect(handles[2], rect.bottomRight);
    expect(handles[3], rect.bottomLeft);
    expect(handles[4], rect.topCenter);
    expect(handles[5], rect.centerRight);
    expect(handles[6], rect.bottomCenter);
    expect(handles[7], rect.centerLeft);
  });
}
