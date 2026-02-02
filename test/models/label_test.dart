import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/models/label.dart';
import 'package:label_load/models/label_definition.dart';
import 'package:label_load/services/app/app_error.dart';

/// Label 模型单元测试
void main() {
  group('Label 模型测试', () {
    // ==================== 构造函数测试 ====================

    group('构造函数', () {
      test('默认值应正确初始化', () {
        final label = Label(id: 0);

        expect(label.id, 0);
        expect(label.name, '');
        expect(label.x, 0.5);
        expect(label.y, 0.5);
        expect(label.width, 0.1);
        expect(label.height, 0.1);
        expect(label.points, isEmpty);
        expect(label.confidence, isNull);
      });

      test('自定义值应正确设置', () {
        final points = [
          LabelPoint(x: 0.1, y: 0.2, visibility: 2),
          LabelPoint(x: 0.3, y: 0.4, visibility: 1),
        ];

        final label = Label(
          id: 1,
          name: 'person',
          x: 0.5,
          y: 0.6,
          width: 0.3,
          height: 0.4,
          points: points,
          confidence: 0.95,
        );

        expect(label.id, 1);
        expect(label.name, 'person');
        expect(label.x, 0.5);
        expect(label.y, 0.6);
        expect(label.width, 0.3);
        expect(label.height, 0.4);
        expect(label.points.length, 2);
        expect(label.confidence, 0.95);
      });
    });

    // ==================== YOLO 格式解析测试 ====================

    group('fromYoloLine - 检测格式解析', () {
      test('空行应抛出 labelLineEmpty', () {
        const line = '   ';
        String getName(int id) => 'class_$id';

        expect(
          () => Label.fromYoloLine(line, getName),
          throwsA(
            isA<AppError>().having(
              (e) => e.code,
              'code',
              AppErrorCode.labelLineEmpty,
            ),
          ),
        );
      });

      test('非法类别ID应抛出 labelInvalidClassId', () {
        const line = 'abc 0.5 0.5 0.2 0.3';
        String getName(int id) => 'class_$id';

        expect(
          () => Label.fromYoloLine(line, getName),
          throwsA(
            isA<AppError>().having(
              (e) => e.code,
              'code',
              AppErrorCode.labelInvalidClassId,
            ),
          ),
        );
      });

      test('应正确解析标准检测格式', () {
        const line = '0 0.512345 0.623456 0.234567 0.345678';
        const classNames = ['person', 'car', 'dog'];
        String getName(int id) => classNames[id];

        final label = Label.fromYoloLine(line, getName);

        expect(label.id, 0);
        expect(label.name, 'person');
        expect(label.x, closeTo(0.512345, 1e-6));
        expect(label.y, closeTo(0.623456, 1e-6));
        expect(label.width, closeTo(0.234567, 1e-6));
        expect(label.height, closeTo(0.345678, 1e-6));
        expect(label.points, isEmpty);
      });

      test('应正确解析不同类别ID', () {
        const line = '2 0.5 0.5 0.2 0.3';
        const classNames = ['person', 'car', 'dog'];
        String getName(int id) => classNames[id];

        final label = Label.fromYoloLine(line, getName);

        expect(label.id, 2);
        expect(label.name, 'dog');
      });

      test('类别ID超出范围时应使用默认名称', () {
        const line = '5 0.5 0.5 0.2 0.3';
        const classNames = ['person', 'car'];
        String getName(int id) =>
            id < classNames.length ? classNames[id] : 'class_$id';

        final label = Label.fromYoloLine(line, getName);

        expect(label.id, 5);
        expect(label.name, 'class_5');
      });

      test('应处理多余空格', () {
        const line = '  0   0.5   0.5   0.2   0.3  ';
        const classNames = ['person'];
        String getName(int id) => classNames[id];

        final label = Label.fromYoloLine(line, getName);

        expect(label.id, 0);
        expect(label.x, 0.5);
      });

      test('格式无效时应抛出异常', () {
        const line = '0 0.5 0.5'; // 缺少宽高
        const classNames = ['person'];
        String getName(int id) => classNames[id];

        expect(
          () => Label.fromYoloLine(line, getName),
          throwsA(
            isA<AppError>().having(
              (e) => e.code,
              'code',
              AppErrorCode.labelInvalidBox,
            ),
          ),
        );
      });

      test('检测格式有多余字段时应保留到extraData', () {
        const line = '0 0.5 0.5 0.2 0.3 extra1 extra2';
        const classNames = ['person'];
        String getName(int id) => classNames[id];

        final label = Label.fromYoloLine(line, getName);

        expect(label.extraData, ['extra1', 'extra2']);
      });
    });

    group('fromYoloLine - 姿态格式解析（带关键点）', () {
      test('应正确解析带关键点的格式', () {
        const line = '0 0.5 0.5 0.3 0.4 0.45 0.25 2 0.55 0.25 1 0.50 0.35 0';
        const classNames = ['person'];
        String getName(int id) => classNames[id];

        final label =
            Label.fromYoloLine(line, getName, type: LabelType.boxWithPoint);

        expect(label.id, 0);
        expect(label.x, 0.5);
        expect(label.y, 0.5);
        expect(label.width, 0.3);
        expect(label.height, 0.4);
        expect(label.points.length, 3);

        // 验证关键点
        expect(label.points[0].x, closeTo(0.45, 1e-6));
        expect(label.points[0].y, closeTo(0.25, 1e-6));
        expect(label.points[0].visibility, 2);

        expect(label.points[1].x, closeTo(0.55, 1e-6));
        expect(label.points[1].y, closeTo(0.25, 1e-6));
        expect(label.points[1].visibility, 1);

        expect(label.points[2].x, closeTo(0.50, 1e-6));
        expect(label.points[2].y, closeTo(0.35, 1e-6));
        expect(label.points[2].visibility, 0);
      });

      test('关键点可见性应正确钳制到0-2范围', () {
        const line = '0 0.5 0.5 0.3 0.4 0.1 0.2 5 0.3 0.4 -1';
        const classNames = ['person'];
        String getName(int id) => classNames[id];

        final label =
            Label.fromYoloLine(line, getName, type: LabelType.boxWithPoint);

        expect(label.points[0].visibility, 2); // 5 应钳制为 2
        expect(label.points[1].visibility, 0); // -1 应钳制为 0
      });

      test('关键点解析失败时应将剩余数据写入extraData', () {
        const line = '0 0.5 0.5 0.3 0.4 0.1 0.2 bad 0.3 0.4 1';
        const classNames = ['person'];
        String getName(int id) => classNames[id];

        final label =
            Label.fromYoloLine(line, getName, type: LabelType.boxWithPoint);

        expect(label.points, isEmpty);
        expect(label.extraData, ['0.1', '0.2', 'bad', '0.3', '0.4', '1']);
      });
    });

    group('fromYoloLine - 多边形格式解析', () {
      test('应正确解析多边形格式', () {
        const line = '0 0.1 0.2 0.3 0.2 0.4 0.5 0.2 0.6';
        const classNames = ['building'];
        String getName(int id) => classNames[id];

        final label =
            Label.fromYoloLine(line, getName, type: LabelType.polygon);

        expect(label.id, 0);
        expect(label.points.length, 4);

        // 验证顶点
        expect(label.points[0].x, closeTo(0.1, 1e-6));
        expect(label.points[0].y, closeTo(0.2, 1e-6));
        expect(label.points[1].x, closeTo(0.3, 1e-6));
        expect(label.points[1].y, closeTo(0.2, 1e-6));
        expect(label.points[2].x, closeTo(0.4, 1e-6));
        expect(label.points[2].y, closeTo(0.5, 1e-6));
        expect(label.points[3].x, closeTo(0.2, 1e-6));
        expect(label.points[3].y, closeTo(0.6, 1e-6));
      });

      test('多边形边界框应从顶点计算', () {
        const line = '0 0.1 0.2 0.5 0.2 0.5 0.8 0.1 0.8';
        const classNames = ['building'];
        String getName(int id) => classNames[id];

        final label =
            Label.fromYoloLine(line, getName, type: LabelType.polygon);

        // 边界框应包围所有顶点
        final bbox = label.bbox;
        expect(bbox[0], closeTo(0.1, 1e-6)); // left
        expect(bbox[1], closeTo(0.2, 1e-6)); // top
        expect(bbox[2], closeTo(0.5, 1e-6)); // right
        expect(bbox[3], closeTo(0.8, 1e-6)); // bottom
      });

      test('多边形顶点不足3个时应抛出异常', () {
        const line = '0 0.1 0.2 0.3 0.4'; // 只有2个点
        const classNames = ['building'];
        String getName(int id) => classNames[id];

        expect(
          () => Label.fromYoloLine(line, getName, type: LabelType.polygon),
          throwsA(
            isA<AppError>().having(
              (e) => e.code,
              'code',
              AppErrorCode.labelInvalidPolygon,
            ),
          ),
        );
      });

      test('多边形解析失败时应保留剩余数据', () {
        const line = '0 0.1 0.2 0.3 bad 0.4 0.5';
        const classNames = ['building'];
        String getName(int id) => classNames[id];

        final label =
            Label.fromYoloLine(line, getName, type: LabelType.polygon);

        expect(label.points.length, 1);
        expect(label.extraData, ['0.3', 'bad', '0.4', '0.5']);
      });
    });

    // ==================== YOLO 格式输出测试 ====================

    group('toYoloLine - 检测格式输出', () {
      test('应正确输出标准检测格式', () {
        final label = Label(
          id: 0,
          x: 0.512345,
          y: 0.623456,
          width: 0.234567,
          height: 0.345678,
        );

        final line = label.toYoloLine();

        expect(line, '0 0.512345 0.623456 0.234567 0.345678');
      });

      test('应保留6位小数精度', () {
        final label = Label(
          id: 1,
          x: 0.1234567890, // 超过6位
          y: 0.9,
          width: 0.5,
          height: 0.5,
        );

        final line = label.toYoloLine();

        expect(line, '1 0.123457 0.900000 0.500000 0.500000');
      });

      test('应在末尾追加extraData', () {
        final label = Label(
          id: 1,
          x: 0.1,
          y: 0.2,
          width: 0.3,
          height: 0.4,
          extraData: ['foo', 'bar'],
        );

        final line = label.toYoloLine();

        expect(line, '1 0.100000 0.200000 0.300000 0.400000 foo bar');
      });
    });

    group('toYoloLine - 姿态格式输出', () {
      test('应正确输出带关键点的格式', () {
        final label = Label(
          id: 0,
          x: 0.5,
          y: 0.5,
          width: 0.3,
          height: 0.4,
          points: [
            LabelPoint(x: 0.45, y: 0.25, visibility: 2),
            LabelPoint(x: 0.55, y: 0.35, visibility: 1),
          ],
        );

        final line = label.toYoloLine();

        expect(
          line,
          '0 0.500000 0.500000 0.300000 0.400000 '
          '0.450000 0.250000 2 0.550000 0.350000 1',
        );
      });
    });

    group('toYoloLine - 多边形格式输出', () {
      test('应正确输出多边形格式', () {
        final label = Label(id: 0);
        label.points.addAll([
          LabelPoint(x: 0.1, y: 0.2),
          LabelPoint(x: 0.3, y: 0.2),
          LabelPoint(x: 0.3, y: 0.5),
        ]);

        final line = label.toYoloLine(isPolygon: true);

        expect(line, '0 0.100000 0.200000 0.300000 0.200000 0.300000 0.500000');
      });
    });

    group('toYoloLineFull', () {
      test('应包含边界框、关键点和额外数据', () {
        final label = Label(
          id: 2,
          x: 0.5,
          y: 0.5,
          width: 0.2,
          height: 0.3,
          points: [LabelPoint(x: 0.1, y: 0.2, visibility: 1)],
          extraData: ['foo', 'bar'],
        );

        final line = label.toYoloLineFull();

        expect(
          line,
          '2 0.500000 0.500000 0.200000 0.300000 0.100000 0.200000 1 foo bar',
        );
      });
    });

    // ==================== 边界框操作测试 ====================

    group('bbox 属性', () {
      test('应正确计算边界框坐标', () {
        final label = Label(
          id: 0,
          x: 0.5,
          y: 0.5,
          width: 0.4,
          height: 0.6,
        );

        final bbox = label.bbox;

        expect(bbox[0], closeTo(0.3, 1e-6)); // left = x - width/2
        expect(bbox[1], closeTo(0.2, 1e-6)); // top = y - height/2
        expect(bbox[2], closeTo(0.7, 1e-6)); // right = x + width/2
        expect(bbox[3], closeTo(0.8, 1e-6)); // bottom = y + height/2
      });
    });

    group('setFromCorners', () {
      test('应从角点正确设置边界框', () {
        final label = Label(id: 0);
        label.setFromCorners(0.2, 0.3, 0.8, 0.9);

        expect(label.x, closeTo(0.5, 1e-6));
        expect(label.y, closeTo(0.6, 1e-6));
        expect(label.width, closeTo(0.6, 1e-6));
        expect(label.height, closeTo(0.6, 1e-6));
      });

      test('应处理反向角点（右下到左上）', () {
        final label = Label(id: 0);
        label.setFromCorners(0.8, 0.9, 0.2, 0.3);

        expect(label.x, closeTo(0.5, 1e-6));
        expect(label.y, closeTo(0.6, 1e-6));
        expect(label.width, closeTo(0.6, 1e-6));
        expect(label.height, closeTo(0.6, 1e-6));
      });
    });

    group('updateBboxFromPoints', () {
      test('应从关键点更新边界框', () {
        final label = Label(id: 0);
        label.points.addAll([
          LabelPoint(x: 0.1, y: 0.2),
          LabelPoint(x: 0.7, y: 0.2),
          LabelPoint(x: 0.7, y: 0.9),
          LabelPoint(x: 0.1, y: 0.9),
        ]);

        label.updateBboxFromPoints();

        expect(label.x, closeTo(0.4, 1e-6));
        expect(label.y, closeTo(0.55, 1e-6));
        expect(label.width, closeTo(0.6, 1e-6));
        expect(label.height, closeTo(0.7, 1e-6));
      });

      test('无关键点时不应修改边界框', () {
        final label = Label(id: 0, x: 0.5, y: 0.5, width: 0.3, height: 0.3);

        label.updateBboxFromPoints();

        expect(label.x, 0.5);
        expect(label.y, 0.5);
        expect(label.width, 0.3);
        expect(label.height, 0.3);
      });
    });

    // ==================== 辅助方法测试 ====================

    group('copyWith', () {
      test('应创建具有新值的副本', () {
        final original = Label(
          id: 0,
          name: 'person',
          x: 0.5,
          y: 0.5,
          width: 0.3,
          height: 0.4,
        );

        final copy = original.copyWith(id: 1, name: 'car');

        expect(copy.id, 1);
        expect(copy.name, 'car');
        expect(copy.x, 0.5); // 未修改
        expect(copy.y, 0.5); // 未修改
        expect(copy.width, 0.3); // 未修改
        expect(copy.height, 0.4); // 未修改
      });

      test('副本的关键点应独立于原始对象', () {
        final original = Label(
          id: 0,
          points: [LabelPoint(x: 0.1, y: 0.2)],
        );

        final copy = original.copyWith();
        copy.points.add(LabelPoint(x: 0.3, y: 0.4));

        expect(original.points.length, 1);
        expect(copy.points.length, 2);
      });
    });

    group('hasKeypoints', () {
      test('有关键点时应返回true', () {
        final label = Label(
          id: 0,
          points: [LabelPoint(x: 0.1, y: 0.2)],
        );

        expect(label.hasKeypoints, isTrue);
      });

      test('无关键点时应返回false', () {
        final label = Label(id: 0);

        expect(label.hasKeypoints, isFalse);
      });
    });
  });

  // ==================== LabelPoint 测试 ====================

  group('LabelPoint 模型测试', () {
    group('构造函数', () {
      test('默认可见性应为2', () {
        final point = LabelPoint(x: 0.5, y: 0.5);

        expect(point.x, 0.5);
        expect(point.y, 0.5);
        expect(point.visibility, 2);
      });

      test('自定义可见性应正确设置', () {
        final point = LabelPoint(x: 0.3, y: 0.4, visibility: 1);

        expect(point.visibility, 1);
      });
    });

    group('copyWith', () {
      test('应创建具有新值的副本', () {
        final original = LabelPoint(x: 0.1, y: 0.2, visibility: 2);

        final copy = original.copyWith(x: 0.5, visibility: 0);

        expect(copy.x, 0.5);
        expect(copy.y, 0.2); // 未修改
        expect(copy.visibility, 0);
      });
    });
  });
}
