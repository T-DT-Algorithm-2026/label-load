import 'dart:convert';
import '../../models/label_definition.dart';
import '../files/text_file_repository.dart';

/// Imports and exports label definitions to JSON files.
class LabelDefinitionIo {
  LabelDefinitionIo({TextFileRepository? repository})
      : _repository = repository ?? FileTextRepository();

  final TextFileRepository _repository;

  /// Writes [labels] into [path] as formatted JSON.
  Future<void> exportToFile(
    String path,
    List<LabelDefinition> labels,
  ) async {
    final jsonData = labels.map((e) => e.toJson()).toList();
    final encoded = const JsonEncoder.withIndent('  ').convert(jsonData);
    await _repository.writeString(path, encoded);
  }

  /// Reads [path] and returns the parsed label definitions.
  Future<List<LabelDefinition>> importFromFile(String path) async {
    final content = await _repository.readString(path);
    final jsonData = json.decode(content) as List<dynamic>;

    final imported = <LabelDefinition>[];
    for (int i = 0; i < jsonData.length; i++) {
      imported.add(LabelDefinition.fromJson(
        jsonData[i] as Map<String, dynamic>,
        fallbackClassId: i,
      ));
    }
    return imported;
  }
}
