import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:label_load/models/project_config.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:label_load/services/projects/project_list_repository.dart';

import '../test_helpers.dart';

class TempPathProvider implements ProjectsPathProvider {
  TempPathProvider(this.dir);

  final Directory dir;

  @override
  Future<String> getProjectsFilePath() async {
    return p.join(dir.path, 'projects.json');
  }
}

void main() {
  group('ProjectListRepository', () {
    test('returns empty list when file missing', () async {
      final dir = await createTempDir('projects_repo_');

      final repo = ProjectListRepository(pathProvider: TempPathProvider(dir));
      final projects = await repo.loadProjects();

      expect(projects, isEmpty);
    });

    test('saves and loads projects', () async {
      final dir = await createTempDir('projects_repo_');

      final repo = ProjectListRepository(pathProvider: TempPathProvider(dir));
      final saved = [
        ProjectConfig(name: 'A'),
        ProjectConfig(name: 'B'),
      ];

      await repo.saveProjects(saved);
      final loaded = await repo.loadProjects();

      expect(loaded.length, 2);
      expect(loaded.map((p) => p.name), ['A', 'B']);
    });

    test('AppDocumentsPathProvider builds projects path', () async {
      final dir = await createTempDir('projects_path_');

      final original = PathProviderPlatform.instance;
      PathProviderPlatform.instance = FakePathProviderPlatform(dir.path);
      addTearDown(() => PathProviderPlatform.instance = original);

      final provider = AppDocumentsPathProvider();
      final result = await provider.getProjectsFilePath();

      expect(result, p.join(dir.path, 'LabelLoad', 'projects.json'));
    });
  });
}

class FakePathProviderPlatform extends PathProviderPlatform {
  FakePathProviderPlatform(this.documentsPath);

  final String documentsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}
