import '../../models/label.dart';
import '../../models/label_definition.dart';

/// Converts raw inference detections into domain [Label]s.
class InferenceLabelMapper {
  /// Maps [detections] using [definitions] to provide class names and types.
  static List<Label> fromDetections(
    Iterable<dynamic> detections,
    List<LabelDefinition> definitions,
  ) {
    final labels = <Label>[];
    for (final det in detections) {
      final classId = det.classId;
      final className = definitions.nameForClassId(classId);

      List<LabelPoint>? points;
      final rawKeypoints = det.keypoints;
      if (rawKeypoints is Iterable && rawKeypoints.isNotEmpty) {
        points = rawKeypoints.map<LabelPoint>((kp) {
          return LabelPoint(
            x: kp.x,
            y: kp.y,
            visibility: _visibilityFromScore(kp.visibility),
          );
        }).toList();
      }

      labels.add(Label(
        id: classId,
        name: className,
        x: det.x,
        y: det.y,
        width: det.width,
        height: det.height,
        points: points,
      ));
    }
    return labels;
  }

  static int _visibilityFromScore(num value) {
    if (value > 0.5) return 2;
    if (value > 0.2) return 1;
    return 0;
  }
}
