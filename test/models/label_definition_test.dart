import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/models/label_definition.dart';

/// LabelDefinition 模型单元测试
void main() {
  group('LabelDefinition 模型测试', () {
    // ==================== 构造函数测试 ====================

    group('构造函数', () {
      test('默认类型应为box', () {
        final def = LabelDefinition(
          classId: 0,
          name: 'person',
          color: Colors.red,
        );

        expect(def.classId, 0);
        expect(def.name, 'person');
        expect(def.color, Colors.red);
        expect(def.type, LabelType.box);
      });

      test('自定义类型应正确设置', () {
        final def = LabelDefinition(
          classId: 1,
          name: 'pose',
          color: Colors.blue,
          type: LabelType.boxWithPoint,
        );

        expect(def.type, LabelType.boxWithPoint);
      });
    });

    // ==================== JSON 序列化测试 ====================

    group('fromJson', () {
      test('应正确解析完整JSON', () {
        final json = {
          'classId': 2,
          'name': 'car',
          'color': LabelDefinition.encodeColor(Colors.green),
          'type': 1, // boxWithPoint
        };

        final def = LabelDefinition.fromJson(json);

        expect(def.classId, 2);
        expect(def.name, 'car');
        expect(LabelDefinition.encodeColor(def.color),
            LabelDefinition.encodeColor(Colors.green));
        expect(def.type, LabelType.boxWithPoint);
      });

      test('缺少type时应默认为box', () {
        final json = {
          'classId': 0,
          'name': 'person',
          'color': LabelDefinition.encodeColor(Colors.red),
        };

        final def = LabelDefinition.fromJson(json);

        expect(def.type, LabelType.box);
      });

      test('缺少classId时应使用fallbackClassId', () {
        final json = {
          'name': 'person',
          'color': LabelDefinition.encodeColor(Colors.red),
        };

        final def = LabelDefinition.fromJson(json, fallbackClassId: 5);

        expect(def.classId, 5);
      });

      test('无效type索引应回退到box', () {
        final json = {
          'classId': 0,
          'name': 'test',
          'color': LabelDefinition.encodeColor(Colors.red),
          'type': 99, // 无效索引
        };

        final def = LabelDefinition.fromJson(json);

        expect(def.type, LabelType.box);
      });

      test('负数type索引应回退到box', () {
        final json = {
          'classId': 0,
          'name': 'test',
          'color': LabelDefinition.encodeColor(Colors.red),
          'type': -1,
        };

        final def = LabelDefinition.fromJson(json);

        expect(def.type, LabelType.box);
      });
    });

    group('toJson', () {
      test('应正确序列化为JSON', () {
        final def = LabelDefinition(
          classId: 1,
          name: 'dog',
          color: const Color(0xFF123456),
          type: LabelType.polygon,
        );

        final json = def.toJson();

        expect(json['classId'], 1);
        expect(json['name'], 'dog');
        expect(json['color'], 0xFF123456);
        expect(json['type'], 2); // polygon.index
      });

      test('JSON往返转换应保持数据一致', () {
        final original = LabelDefinition(
          classId: 3,
          name: 'building',
          color: const Color(0xFFABCDEF),
          type: LabelType.polygon,
        );

        final json = original.toJson();
        final restored = LabelDefinition.fromJson(json);

        expect(restored.classId, original.classId);
        expect(restored.name, original.name);
        expect(LabelDefinition.encodeColor(restored.color),
            LabelDefinition.encodeColor(original.color));
        expect(restored.type, original.type);
      });
    });

    // ==================== copyWith 测试 ====================

    group('copyWith', () {
      test('应创建具有新值的副本', () {
        final original = LabelDefinition(
          classId: 0,
          name: 'person',
          color: Colors.red,
          type: LabelType.box,
        );

        final copy = original.copyWith(
          name: 'human',
          type: LabelType.boxWithPoint,
        );

        expect(copy.classId, 0); // 未修改
        expect(copy.name, 'human');
        expect(copy.color, Colors.red); // 未修改
        expect(copy.type, LabelType.boxWithPoint);
      });

      test('不传参数应创建相同副本', () {
        final original = LabelDefinition(
          classId: 1,
          name: 'car',
          color: Colors.blue,
          type: LabelType.polygon,
        );

        final copy = original.copyWith();

        expect(copy.classId, original.classId);
        expect(copy.name, original.name);
        expect(copy.color, original.color);
        expect(copy.type, original.type);
      });
    });

    // ==================== 相等性测试 ====================

    group('相等性', () {
      test('相同属性的对象应相等', () {
        final def1 = LabelDefinition(
          classId: 0,
          name: 'person',
          color: Colors.red,
          type: LabelType.box,
        );

        final def2 = LabelDefinition(
          classId: 0,
          name: 'person',
          color: Colors.red,
          type: LabelType.box,
        );

        expect(def1, equals(def2));
        expect(def1.hashCode, equals(def2.hashCode));
      });

      test('不同classId的对象不应相等', () {
        final def1 = LabelDefinition(
          classId: 0,
          name: 'person',
          color: Colors.red,
        );

        final def2 = LabelDefinition(
          classId: 1,
          name: 'person',
          color: Colors.red,
        );

        expect(def1, isNot(equals(def2)));
      });

      test('不同name的对象不应相等', () {
        final def1 = LabelDefinition(
          classId: 0,
          name: 'person',
          color: Colors.red,
        );

        final def2 = LabelDefinition(
          classId: 0,
          name: 'human',
          color: Colors.red,
        );

        expect(def1, isNot(equals(def2)));
      });

      test('不同color的对象不应相等', () {
        final def1 = LabelDefinition(
          classId: 0,
          name: 'person',
          color: Colors.red,
        );

        final def2 = LabelDefinition(
          classId: 0,
          name: 'person',
          color: Colors.blue,
        );

        expect(def1, isNot(equals(def2)));
      });

      test('不同type的对象不应相等', () {
        final def1 = LabelDefinition(
          classId: 0,
          name: 'person',
          color: Colors.red,
          type: LabelType.box,
        );

        final def2 = LabelDefinition(
          classId: 0,
          name: 'person',
          color: Colors.red,
          type: LabelType.polygon,
        );

        expect(def1, isNot(equals(def2)));
      });
    });

    // ==================== 扩展方法测试 ====================

    group('LabelDefinitionListExtension', () {
      test('typeForClassId 应返回匹配类型或fallback', () {
        final defs = [
          LabelDefinition(
            classId: 2,
            name: 'poly',
            color: Colors.green,
            type: LabelType.polygon,
          ),
        ];

        expect(defs.typeForClassId(2), LabelType.polygon);
        expect(defs.typeForClassId(99, fallback: LabelType.boxWithPoint),
            LabelType.boxWithPoint);
      });

      test('nameForClassId 应返回匹配名称或默认命名', () {
        final defs = [
          LabelDefinition(classId: 1, name: 'cat', color: Colors.red),
        ];

        expect(defs.nameForClassId(1), 'cat');
        expect(defs.nameForClassId(3), 'class_3');
      });

      test('colorForClassId 应优先定义颜色', () {
        final defs = [
          LabelDefinition(
            classId: 0,
            name: 'dog',
            color: const Color(0xFFABCDEF),
          ),
        ];

        expect(defs.colorForClassId(0), const Color(0xFFABCDEF));
        expect(
          defs.colorForClassId(LabelPalettes.defaultPalette.length + 1),
          LabelPalettes.defaultPalette[
              (LabelPalettes.defaultPalette.length + 1) %
                  LabelPalettes.defaultPalette.length],
        );
      });
    });
  });

  // ==================== 扩展方法测试 ====================

  group('LabelDefinitionListExtension 测试', () {
    group('findByClassId', () {
      test('应找到匹配的定义', () {
        final definitions = [
          LabelDefinition(classId: 0, name: 'person', color: Colors.red),
          LabelDefinition(classId: 1, name: 'car', color: Colors.blue),
          LabelDefinition(classId: 2, name: 'dog', color: Colors.green),
        ];

        final found = definitions.findByClassId(1);

        expect(found, isNotNull);
        expect(found!.name, 'car');
      });

      test('未找到时应返回null', () {
        final definitions = [
          LabelDefinition(classId: 0, name: 'person', color: Colors.red),
        ];

        final found = definitions.findByClassId(99);

        expect(found, isNull);
      });

      test('空列表应返回null', () {
        final definitions = <LabelDefinition>[];

        final found = definitions.findByClassId(0);

        expect(found, isNull);
      });

      test('应找到非连续classId', () {
        final definitions = [
          LabelDefinition(classId: 0, name: 'a', color: Colors.red),
          LabelDefinition(classId: 5, name: 'b', color: Colors.blue),
          LabelDefinition(classId: 10, name: 'c', color: Colors.green),
        ];

        final found = definitions.findByClassId(5);

        expect(found, isNotNull);
        expect(found!.name, 'b');
      });
    });

    group('nextClassId', () {
      test('空列表应返回0', () {
        final definitions = <LabelDefinition>[];

        expect(definitions.nextClassId, 0);
      });

      test('应返回最大ID加1', () {
        final definitions = [
          LabelDefinition(classId: 0, name: 'a', color: Colors.red),
          LabelDefinition(classId: 1, name: 'b', color: Colors.blue),
          LabelDefinition(classId: 2, name: 'c', color: Colors.green),
        ];

        expect(definitions.nextClassId, 3);
      });

      test('应处理非连续classId', () {
        final definitions = [
          LabelDefinition(classId: 0, name: 'a', color: Colors.red),
          LabelDefinition(classId: 5, name: 'b', color: Colors.blue),
          LabelDefinition(classId: 3, name: 'c', color: Colors.green),
        ];

        expect(definitions.nextClassId, 6); // 最大ID 5 + 1
      });

      test('单个元素应返回其ID加1', () {
        final definitions = [
          LabelDefinition(classId: 10, name: 'a', color: Colors.red),
        ];

        expect(definitions.nextClassId, 11);
      });
    });

    group('LabelPalettes', () {
      test('默认调色板不为空', () {
        expect(LabelPalettes.defaultPalette, isNotEmpty);
      });

      test('扩展调色板包含默认调色板', () {
        expect(
          LabelPalettes.extendedPalette.length,
          greaterThanOrEqualTo(LabelPalettes.defaultPalette.length),
        );
      });
    });
  });

  // ==================== LabelType 枚举测试 ====================

  group('LabelType 枚举测试', () {
    test('枚举值应正确定义', () {
      expect(LabelType.box.index, 0);
      expect(LabelType.boxWithPoint.index, 1);
      expect(LabelType.polygon.index, 2);
    });

    test('枚举数量应为3', () {
      expect(LabelType.values.length, 3);
    });
  });
}
