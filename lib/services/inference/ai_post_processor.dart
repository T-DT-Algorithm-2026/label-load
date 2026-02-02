import '../../models/label.dart';
import '../../models/label_definition.dart';

/// Post-processes inference labels to align with project metadata.
class AiPostProcessor {
  const AiPostProcessor();

  /// Applies a class id offset in-place to align model outputs.
  void applyClassIdOffset(List<Label> labels, int offset) {
    if (offset == 0) return;
    for (final label in labels) {
      label.id += offset;
    }
  }

  /// Removes incompatible fields based on the resolved label type.
  void sanitizeLabels(List<Label> labels, List<LabelDefinition> definitions) {
    for (final label in labels) {
      final type = definitions.typeForClassId(
        label.id,
        fallback: LabelType.boxWithPoint,
      );
      if (type == LabelType.box) {
        label.points.clear();
        label.extraData.clear();
      }
    }
  }

  /// Ensures every class id appearing in [labels] has a definition.
  ///
  /// Missing definitions are appended with auto-generated names and colors.
  List<LabelDefinition> fillMissingDefinitions(
    List<Label> labels,
    List<LabelDefinition> definitions,
  ) {
    if (labels.isEmpty) return definitions;

    final newIds = <int>{};
    for (final label in labels) {
      newIds.add(label.id);
    }

    final existingIds = definitions.map((e) => e.classId).toSet();
    final missingIds = newIds.difference(existingIds);

    if (missingIds.isEmpty) return definitions;

    final updated = List<LabelDefinition>.from(definitions);

    LabelType inferType(int classId) {
      final samples = labels.where((l) => l.id == classId);
      if (samples.isEmpty) return LabelType.box;
      final hasPoints = samples.any((l) => l.points.isNotEmpty);
      return hasPoints ? LabelType.boxWithPoint : LabelType.box;
    }

    for (final classId in missingIds) {
      updated.add(LabelDefinition(
        classId: classId,
        name: 'class_$classId',
        color: LabelPalettes
            .defaultPalette[classId % LabelPalettes.defaultPalette.length],
        type: inferType(classId),
      ));
    }

    updated.sort((a, b) => a.classId.compareTo(b.classId));
    return updated;
  }
}
