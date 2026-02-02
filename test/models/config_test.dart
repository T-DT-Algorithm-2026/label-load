import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/models/config.dart';

/// AppConfig 模型单元测试
void main() {
  group('AppConfig 模型测试', () {
    // ==================== 构造函数测试 ====================

    group('构造函数', () {
      test('默认值应正确初始化', () {
        final config = AppConfig();

        expect(config.imagePath, '');
        expect(config.labelPath, '');
        expect(config.classNames, isEmpty);
        expect(config.locale, 'zh');
      });

      test('自定义值应正确设置', () {
        final config = AppConfig(
          imagePath: '/path/to/images',
          labelPath: '/path/to/labels',
          classNames: ['person', 'car', 'dog'],
          locale: 'en',
        );

        expect(config.imagePath, '/path/to/images');
        expect(config.labelPath, '/path/to/labels');
        expect(config.classNames, ['person', 'car', 'dog']);
        expect(config.locale, 'en');
      });

      test('null classNames 应初始化为空列表', () {
        final config = AppConfig(classNames: null);

        expect(config.classNames, isNotNull);
        expect(config.classNames, isEmpty);
      });
    });

    // ==================== JSON 序列化测试 ====================

    group('fromJson', () {
      test('应正确解析完整JSON', () {
        final json = {
          'imagePath': '/images',
          'labelPath': '/labels',
          'classNames': ['a', 'b', 'c'],
          'locale': 'en',
        };

        final config = AppConfig.fromJson(json);

        expect(config.imagePath, '/images');
        expect(config.labelPath, '/labels');
        expect(config.classNames, ['a', 'b', 'c']);
        expect(config.locale, 'en');
      });

      test('缺少字段时应使用默认值', () {
        final json = <String, dynamic>{};

        final config = AppConfig.fromJson(json);

        expect(config.imagePath, '');
        expect(config.labelPath, '');
        expect(config.classNames, isEmpty);
        expect(config.locale, 'zh');
      });

      test('null字段应使用默认值', () {
        final json = {
          'imagePath': null,
          'labelPath': null,
          'classNames': null,
          'locale': null,
        };

        final config = AppConfig.fromJson(json);

        expect(config.imagePath, '');
        expect(config.labelPath, '');
        expect(config.classNames, isEmpty);
        expect(config.locale, 'zh');
      });
    });

    group('toJson', () {
      test('应正确序列化为JSON', () {
        final config = AppConfig(
          imagePath: '/images',
          labelPath: '/labels',
          classNames: ['person', 'car'],
          locale: 'en',
        );

        final json = config.toJson();

        expect(json['imagePath'], '/images');
        expect(json['labelPath'], '/labels');
        expect(json['classNames'], ['person', 'car']);
        expect(json['locale'], 'en');
      });

      test('JSON往返转换应保持数据一致', () {
        final original = AppConfig(
          imagePath: '/test/images',
          labelPath: '/test/labels',
          classNames: ['a', 'b', 'c'],
          locale: 'zh',
        );

        final json = original.toJson();
        final restored = AppConfig.fromJson(json);

        expect(restored.imagePath, original.imagePath);
        expect(restored.labelPath, original.labelPath);
        expect(restored.classNames, original.classNames);
        expect(restored.locale, original.locale);
      });
    });

    // ==================== copyWith 测试 ====================

    group('copyWith', () {
      test('应创建具有新值的副本', () {
        final original = AppConfig(
          imagePath: '/old/images',
          labelPath: '/old/labels',
          classNames: ['a'],
          locale: 'zh',
        );

        final copy = original.copyWith(
          imagePath: '/new/images',
          locale: 'en',
        );

        expect(copy.imagePath, '/new/images');
        expect(copy.labelPath, '/old/labels'); // 未修改
        expect(copy.classNames, ['a']); // 未修改
        expect(copy.locale, 'en');
      });

      test('不传参数应创建相同副本', () {
        final original = AppConfig(
          imagePath: '/images',
          labelPath: '/labels',
          classNames: ['a', 'b'],
          locale: 'en',
        );

        final copy = original.copyWith();

        expect(copy.imagePath, original.imagePath);
        expect(copy.labelPath, original.labelPath);
        expect(copy.classNames, original.classNames);
        expect(copy.locale, original.locale);
      });

      test('classNames副本应独立于原始对象', () {
        final original = AppConfig(classNames: ['a', 'b']);

        final copy = original.copyWith();
        copy.classNames.add('c');

        expect(original.classNames.length, 2);
        expect(copy.classNames.length, 3);
      });
    });

    // ==================== 可变性测试 ====================

    group('可变性', () {
      test('imagePath应可修改', () {
        final config = AppConfig();
        config.imagePath = '/new/path';

        expect(config.imagePath, '/new/path');
      });

      test('labelPath应可修改', () {
        final config = AppConfig();
        config.labelPath = '/new/labels';

        expect(config.labelPath, '/new/labels');
      });

      test('locale应可修改', () {
        final config = AppConfig();
        config.locale = 'en';

        expect(config.locale, 'en');
      });

      test('classNames应可修改', () {
        final config = AppConfig();
        config.classNames.add('test');

        expect(config.classNames, contains('test'));
      });
    });
  });
}
