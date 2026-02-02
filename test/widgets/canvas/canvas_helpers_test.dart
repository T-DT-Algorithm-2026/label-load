import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/widgets/canvas/canvas_helpers.dart';

Future<ui.Image> _createTestImage(int width, int height) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = Colors.red,
  );
  final picture = recorder.endRecording();
  return picture.toImage(width, height);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ImagePainter paints and detects repaint changes',
      (tester) async {
    final image1 = await _createTestImage(2, 2);
    addTearDown(image1.dispose);
    final image2 = await _createTestImage(2, 2);
    addTearDown(image2.dispose);

    final painter = ImagePainter(
      image: image1,
      colorFilter: const ColorFilter.mode(Colors.blue, BlendMode.srcIn),
      filterQuality: ui.FilterQuality.high,
    );

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    painter.paint(canvas, const Size(2, 2));
    recorder.endRecording();

    expect(
      painter.shouldRepaint(ImagePainter(image: image2)),
      isTrue,
    );
    expect(
      painter.shouldRepaint(ImagePainter(
        image: image1,
        colorFilter: const ColorFilter.mode(Colors.blue, BlendMode.srcIn),
        filterQuality: ui.FilterQuality.high,
      )),
      isFalse,
    );
    expect(
      painter.shouldRepaint(ImagePainter(
        image: image1,
        colorFilter: const ColorFilter.mode(Colors.red, BlendMode.srcIn),
      )),
      isTrue,
    );
  });

  testWidgets('ScreenCrosshairPainter paints and updates on position change',
      (tester) async {
    final painter = ScreenCrosshairPainter(position: const Offset(10, 20));

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    painter.paint(canvas, const Size(100, 100));
    recorder.endRecording();

    expect(
      painter.shouldRepaint(
          ScreenCrosshairPainter(position: const Offset(20, 30))),
      isTrue,
    );
    expect(
      painter.shouldRepaint(
          ScreenCrosshairPainter(position: const Offset(10, 20))),
      isFalse,
    );
  });
}
