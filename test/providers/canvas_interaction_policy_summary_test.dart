import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/providers/canvas_provider.dart';

void main() {
  test('CanvasProvider interactionPolicySummary includes allowed modes', () {
    final summary = CanvasProvider.interactionPolicySummary();
    expect(summary, contains('labeling='));
    expect(summary, contains('editing='));
    expect(summary, contains('drawing'));
    expect(summary, contains('panning'));
    expect(summary, contains('moving'));
    expect(summary, contains('resizing'));
    expect(summary, contains('movingKeypoint'));
  });
}
