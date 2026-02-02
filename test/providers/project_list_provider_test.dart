import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/models/project_config.dart';
import 'package:label_load/providers/project_list_provider.dart';
import 'package:label_load/services/app/app_error.dart';
import 'package:label_load/services/projects/project_list_repository.dart';

import 'test_helpers.dart';

class ThrowingProjectListRepository implements ProjectListRepository {
  @override
  Future<List<ProjectConfig>> loadProjects() async {
    throw Exception('load failed');
  }

  @override
  Future<void> saveProjects(List<ProjectConfig> projects) async {
    throw Exception('save failed');
  }
}

class MemoryProjectListRepository implements ProjectListRepository {
  List<ProjectConfig> stored = [];

  @override
  Future<List<ProjectConfig>> loadProjects() async => List.from(stored);

  @override
  Future<void> saveProjects(List<ProjectConfig> projects) async {
    stored = List.from(projects);
  }
}

void main() {
  test('ProjectListProvider reports load failure', () async {
    await runWithFlutterErrorsSuppressed(() async {
      final provider = ProjectListProvider(
        repository: ThrowingProjectListRepository(),
      );

      await provider.loadProjects();

      expect(provider.error, isNotNull);
      expect(provider.error!.code, AppErrorCode.projectListLoadFailed);
    });
  });

  test('ProjectListProvider reports save failure', () async {
    await runWithFlutterErrorsSuppressed(() async {
      final provider = ProjectListProvider(
        repository: ThrowingProjectListRepository(),
      );

      await provider.addProject(ProjectConfig(
        id: 'id',
        name: 'name',
        imagePath: '/tmp/images',
        labelPath: '/tmp/labels',
        labelDefinitions: const [],
      ));

      expect(provider.error, isNotNull);
      expect(provider.error!.code, AppErrorCode.projectListSaveFailed);
    });
  });

  test('ProjectListProvider loads, updates, and removes projects', () async {
    final repo = MemoryProjectListRepository()
      ..stored = [
        ProjectConfig(id: '1', name: 'A'),
        ProjectConfig(id: '2', name: 'B'),
      ];
    final provider = ProjectListProvider(repository: repo);

    await provider.loadProjects();
    expect(provider.projects.length, 2);

    await provider.updateProject(ProjectConfig(id: '2', name: 'B2'));
    expect(provider.projects.firstWhere((p) => p.id == '2').name, 'B2');

    await provider.removeProject('1');
    expect(provider.projects.length, 1);
    expect(repo.stored.length, 1);
  });
}
