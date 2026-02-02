import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/models/project_config.dart';
import 'package:label_load/models/label_definition.dart';
import 'package:label_load/models/ai_config.dart';

/// ProjectConfig 模型单元测试
void main() {
  group('ProjectConfig 模型测试', () {
    // ==================== 构造函数测试 ====================

    group('构造函数', () {
      test('默认值应正确初始化', () {
        final config = ProjectConfig(name: '测试项目');

        expect(config.id, isNotEmpty); // UUID 自动生成
        expect(config.name, '测试项目');
        expect(config.description, '');
        expect(config.imagePath, '');
        expect(config.labelPath, '');
        expect(config.labelDefinitions, isEmpty);
        expect(config.createdAt, isNotNull);
        expect(config.aiConfig, isNotNull);
      });

      test('自定义值应正确设置', () {
        final definitions = [
          LabelDefinition(classId: 0, name: 'person', color: Colors.red),
        ];
        final aiConfig = AiConfig(modelPath: '/model.onnx');
        final createdAt = DateTime(2024, 1, 1);

        final config = ProjectConfig(
          id: 'test-uuid',
          name: '自定义项目',
          description: '项目描述',
          imagePath: '/images',
          labelPath: '/labels',
          labelDefinitions: definitions,
          createdAt: createdAt,
          aiConfig: aiConfig,
        );

        expect(config.id, 'test-uuid');
        expect(config.name, '自定义项目');
        expect(config.description, '项目描述');
        expect(config.imagePath, '/images');
        expect(config.labelPath, '/labels');
        expect(config.labelDefinitions.length, 1);
        expect(config.createdAt, createdAt);
        expect(config.aiConfig.modelPath, '/model.onnx');
      });

      test('不指定id时应自动生成UUID', () {
        final config1 = ProjectConfig(name: '项目1');
        final config2 = ProjectConfig(name: '项目2');

        expect(config1.id, isNotEmpty);
        expect(config2.id, isNotEmpty);
        expect(config1.id, isNot(equals(config2.id)));
      });
    });

    // ==================== JSON 序列化测试 ====================

    group('fromJson', () {
      test('应正确解析完整JSON', () {
        final json = {
          'id': 'test-id',
          'name': '测试项目',
          'description': '描述',
          'imagePath': '/images',
          'labelPath': '/labels',
          'labelDefinitions': [
            {
              'classId': 0,
              'name': 'person',
              'color': LabelDefinition.encodeColor(Colors.red),
              'type': 0
            },
            {
              'classId': 1,
              'name': 'car',
              'color': LabelDefinition.encodeColor(Colors.blue),
              'type': 1
            },
          ],
          'createdAt': '2024-01-01T12:00:00.000',
          'aiConfig': {
            'modelType': 0,
            'modelPath': '/model.onnx',
          },
          'lastViewedIndex': 12,
          'inferredImages': ['a.jpg', 'b.jpg'],
        };

        final config = ProjectConfig.fromJson(json);

        expect(config.id, 'test-id');
        expect(config.name, '测试项目');
        expect(config.description, '描述');
        expect(config.imagePath, '/images');
        expect(config.labelPath, '/labels');
        expect(config.labelDefinitions.length, 2);
        expect(config.labelDefinitions[0].name, 'person');
        expect(config.labelDefinitions[1].type, LabelType.boxWithPoint);
        expect(config.aiConfig.modelPath, '/model.onnx');
        expect(config.lastViewedIndex, 12);
        expect(config.inferredImages, ['a.jpg', 'b.jpg']);
      });

      test('缺少字段时应使用默认值', () {
        final json = {
          'id': 'test-id',
          'name': '项目',
        };

        final config = ProjectConfig.fromJson(json);

        expect(config.description, '');
        expect(config.imagePath, '');
        expect(config.labelPath, '');
        expect(config.labelDefinitions, isEmpty);
        expect(config.aiConfig, isNotNull);
        expect(config.lastViewedIndex, 0);
        expect(config.inferredImages, isEmpty);
      });

      test('应支持旧格式（基于索引的classId）', () {
        final json = {
          'id': 'test-id',
          'name': '旧项目',
          'labelDefinitions': [
            {
              'name': 'person',
              'color': LabelDefinition.encodeColor(Colors.red)
            }, // 无classId
            {
              'name': 'car',
              'color': LabelDefinition.encodeColor(Colors.blue)
            }, // 无classId
          ],
        };

        final config = ProjectConfig.fromJson(json);

        expect(config.labelDefinitions[0].classId, 0); // 使用索引
        expect(config.labelDefinitions[1].classId, 1); // 使用索引
      });

      test('无效日期应使用当前时间', () {
        final json = {
          'id': 'test-id',
          'name': '项目',
          'createdAt': 'invalid-date',
        };

        final before = DateTime.now();
        final config = ProjectConfig.fromJson(json);
        final after = DateTime.now();

        expect(
            config.createdAt
                .isAfter(before.subtract(const Duration(seconds: 1))),
            true);
        expect(config.createdAt.isBefore(after.add(const Duration(seconds: 1))),
            true);
      });
    });

    group('toJson', () {
      test('应正确序列化为JSON', () {
        final config = ProjectConfig(
          id: 'test-id',
          name: '测试项目',
          description: '描述',
          imagePath: '/images',
          labelPath: '/labels',
          labelDefinitions: [
            LabelDefinition(classId: 0, name: 'person', color: Colors.red),
          ],
          aiConfig: AiConfig(modelPath: '/model.onnx'),
          lastViewedIndex: 3,
          inferredImages: ['x.png'],
        );

        final json = config.toJson();

        expect(json['id'], 'test-id');
        expect(json['name'], '测试项目');
        expect(json['description'], '描述');
        expect(json['imagePath'], '/images');
        expect(json['labelPath'], '/labels');
        expect((json['labelDefinitions'] as List).length, 1);
        expect(json['createdAt'], isNotNull);
        expect((json['aiConfig'] as Map)['modelPath'], '/model.onnx');
        expect(json['lastViewedIndex'], 3);
        expect(json['inferredImages'], ['x.png']);
      });

      test('JSON往返转换应保持数据一致', () {
        final original = ProjectConfig(
          id: 'test-uuid',
          name: '测试项目',
          description: '项目描述',
          imagePath: '/test/images',
          labelPath: '/test/labels',
          labelDefinitions: [
            LabelDefinition(
              classId: 0,
              name: 'person',
              color: Colors.red,
              type: LabelType.boxWithPoint,
            ),
            LabelDefinition(
              classId: 5,
              name: 'car',
              color: Colors.blue,
              type: LabelType.polygon,
            ),
          ],
          aiConfig: AiConfig(
            modelType: ModelType.yoloPose,
            modelPath: '/model.onnx',
            confidenceThreshold: 0.5,
          ),
          lastViewedIndex: 7,
          inferredImages: ['1.jpg', '2.jpg'],
        );

        final json = original.toJson();
        final restored = ProjectConfig.fromJson(json);

        expect(restored.id, original.id);
        expect(restored.name, original.name);
        expect(restored.description, original.description);
        expect(restored.imagePath, original.imagePath);
        expect(restored.labelPath, original.labelPath);
        expect(
            restored.labelDefinitions.length, original.labelDefinitions.length);
        expect(restored.labelDefinitions[0].classId, 0);
        expect(restored.labelDefinitions[0].type, LabelType.boxWithPoint);
        expect(restored.labelDefinitions[1].classId, 5);
        expect(restored.labelDefinitions[1].type, LabelType.polygon);
        expect(restored.aiConfig.modelType, original.aiConfig.modelType);
        expect(restored.aiConfig.modelPath, original.aiConfig.modelPath);
        expect(restored.lastViewedIndex, 7);
        expect(restored.inferredImages, ['1.jpg', '2.jpg']);
      });
    });

    // ==================== copyWith 测试 ====================

    group('copyWith', () {
      test('应创建具有新值的副本', () {
        final original = ProjectConfig(
          id: 'test-id',
          name: '原始名称',
          description: '原始描述',
          imagePath: '/old/images',
        );

        final copy = original.copyWith(
          name: '新名称',
          imagePath: '/new/images',
        );

        expect(copy.id, 'test-id'); // id 不应改变
        expect(copy.name, '新名称');
        expect(copy.description, '原始描述'); // 未修改
        expect(copy.imagePath, '/new/images');
      });

      test('不传参数应创建相同副本', () {
        final original = ProjectConfig(
          name: '项目',
          description: '描述',
          imagePath: '/images',
          labelPath: '/labels',
        );

        final copy = original.copyWith();

        expect(copy.id, original.id);
        expect(copy.name, original.name);
        expect(copy.description, original.description);
        expect(copy.imagePath, original.imagePath);
        expect(copy.labelPath, original.labelPath);
      });

      test('labelDefinitions副本应独立于原始对象', () {
        final original = ProjectConfig(
          name: '项目',
          labelDefinitions: [
            LabelDefinition(classId: 0, name: 'a', color: Colors.red),
          ],
        );

        final copy = original.copyWith();

        // 修改副本不应影响原始对象
        expect(copy.labelDefinitions, isNot(same(original.labelDefinitions)));
      });

      test('inferredImages副本应独立于原始对象', () {
        final original = ProjectConfig(
          name: '项目',
          inferredImages: ['a.jpg'],
        );

        final copy = original.copyWith();
        copy.inferredImages.add('b.jpg');

        expect(original.inferredImages, ['a.jpg']);
        expect(copy.inferredImages, ['a.jpg', 'b.jpg']);
      });

      test('aiConfig副本应独立于原始对象', () {
        final original = ProjectConfig(
          name: '项目',
          aiConfig: AiConfig(modelPath: '/old.onnx'),
        );

        final copy = original.copyWith();

        // 修改副本
        copy.aiConfig.modelPath = '/new.onnx';

        // 原始对象不应受影响
        expect(original.aiConfig.modelPath, '/old.onnx');
      });
    });

    // ==================== 可变性测试 ====================

    group('可变性', () {
      test('name应可修改', () {
        final config = ProjectConfig(name: '原始');
        config.name = '新名称';

        expect(config.name, '新名称');
      });

      test('description应可修改', () {
        final config = ProjectConfig(name: '项目');
        config.description = '新描述';

        expect(config.description, '新描述');
      });

      test('imagePath应可修改', () {
        final config = ProjectConfig(name: '项目');
        config.imagePath = '/new/path';

        expect(config.imagePath, '/new/path');
      });

      test('labelPath应可修改', () {
        final config = ProjectConfig(name: '项目');
        config.labelPath = '/new/labels';

        expect(config.labelPath, '/new/labels');
      });

      test('labelDefinitions应可修改', () {
        final config = ProjectConfig(name: '项目');
        config.labelDefinitions.add(
          LabelDefinition(classId: 0, name: 'test', color: Colors.red),
        );

        expect(config.labelDefinitions.length, 1);
      });
    });

    // ==================== 不可变属性测试 ====================

    group('不可变属性', () {
      test('id应不可修改', () {
        final config = ProjectConfig(name: '项目');
        final originalId = config.id;

        // id 是 final，无法修改
        expect(config.id, originalId);
      });

      test('createdAt应不可修改', () {
        final config = ProjectConfig(name: '项目');
        final originalCreatedAt = config.createdAt;

        // createdAt 是 final，无法修改
        expect(config.createdAt, originalCreatedAt);
      });
    });
  });
}
