import '../../models/label.dart';
import '../../models/label_definition.dart';

/// 标签类型转换器。
///
/// 将标签在 Box / BoxWithPoint / Polygon 之间转换，并保留尽可能多的信息。
class LabelTypeConverter {
  /// 将标签转换为新类型并更新类别 ID。
  static Label convert(
    Label label,
    int newClassId,
    LabelType oldType,
    LabelType newType,
  ) {
    if (oldType == newType) {
      return label.copyWith(id: newClassId);
    }

    switch (oldType) {
      case LabelType.box:
        return _fromBox(label, newClassId, newType);
      case LabelType.boxWithPoint:
        return _fromBoxWithPoint(label, newClassId, newType);
      case LabelType.polygon:
        return _fromPolygon(label, newClassId, newType);
    }
  }

  /// 从 Box 类型转换为 [newType]。
  static Label _fromBox(Label label, int newClassId, LabelType newType) {
    switch (newType) {
      case LabelType.box:
      case LabelType.boxWithPoint:
        return label.copyWith(id: newClassId);
      case LabelType.polygon:
        final bbox = label.bbox;
        final polygonPoints = [
          LabelPoint(x: bbox[0], y: bbox[1]),
          LabelPoint(x: bbox[2], y: bbox[1]),
          LabelPoint(x: bbox[2], y: bbox[3]),
          LabelPoint(x: bbox[0], y: bbox[3]),
        ];
        return label.copyWith(id: newClassId, points: polygonPoints);
    }
  }

  /// 从 BoxWithPoint 类型转换为 [newType]。
  static Label _fromBoxWithPoint(
    Label label,
    int newClassId,
    LabelType newType,
  ) {
    switch (newType) {
      case LabelType.box:
        return label.copyWith(id: newClassId, points: []);
      case LabelType.boxWithPoint:
        return label.copyWith(id: newClassId);
      case LabelType.polygon:
        if (label.points.isEmpty) {
          final bbox = label.bbox;
          final polygonPoints = [
            LabelPoint(x: bbox[0], y: bbox[1]),
            LabelPoint(x: bbox[2], y: bbox[1]),
            LabelPoint(x: bbox[2], y: bbox[3]),
            LabelPoint(x: bbox[0], y: bbox[3]),
          ];
          return label.copyWith(id: newClassId, points: polygonPoints);
        }
        final newLabel = label.copyWith(id: newClassId);
        newLabel.updateBboxFromPoints();
        return newLabel;
    }
  }

  /// 从 Polygon 类型转换为 [newType]。
  static Label _fromPolygon(Label label, int newClassId, LabelType newType) {
    switch (newType) {
      case LabelType.box:
        return Label(
          id: newClassId,
          name: label.name,
          x: label.x,
          y: label.y,
          width: label.width,
          height: label.height,
          points: [],
        );
      case LabelType.boxWithPoint:
        if (label.points.isEmpty) {
          return label.copyWith(id: newClassId);
        }
        final keptPoints = label.points
            .map((p) => LabelPoint(
                  x: p.x,
                  y: p.y,
                  visibility: p.visibility,
                ))
            .toList();
        return label.copyWith(id: newClassId, points: keptPoints);
      case LabelType.polygon:
        return label.copyWith(id: newClassId);
    }
  }
}
