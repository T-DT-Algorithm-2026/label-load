import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/models/label_definition.dart';
import 'package:label_load/models/project_config.dart';
import 'package:label_load/providers/project_provider.dart';
import 'package:label_load/services/projects/project_repository.dart';

class FakeProjectRepository extends ProjectRepository {
  @override
  Future<List<String>> listImageFiles(String imagePath) async => [];
}

void main() {
  test('ProjectProvider label helpers use config names and fallback', () async {
    final provider = ProjectProvider(repository: FakeProjectRepository());

    final config = ProjectConfig(
      id: 'id',
      name: 'name',
      imagePath: '/images',
      labelPath: '/labels',
      labelDefinitions: [
        LabelDefinition(
          classId: 0,
          name: 'cat',
          color: const Color(0xFF000000),
        ),
      ],
    );

    await provider.loadProject(config);

    expect(provider.labelNameForClass(0), 'cat');
    expect(provider.labelNameForClass(2), 'class_2');

    final label =
        provider.createLabelFromRect(0, const Rect.fromLTWH(0, 0, 1, 1));
    expect(label.name, 'cat');
  });
}
