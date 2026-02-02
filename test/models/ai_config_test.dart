import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/models/ai_config.dart';

/// AiConfig 模型单元测试
void main() {
  group('AiConfig 模型测试', () {
    // ==================== 构造函数测试 ====================

    group('构造函数', () {
      test('默认值应正确初始化', () {
        final config = AiConfig();

        expect(config.modelType, ModelType.yolo);
        expect(config.modelPath, '');
        expect(config.confidenceThreshold, 0.25);
        expect(config.nmsThreshold, 0.45);
        expect(config.autoInferOnNext, false);
        expect(config.labelSaveMode, LabelSaveMode.append);
        expect(config.numKeypoints, 0);
        expect(config.keypointConfThreshold, 0.5);
      });

      test('自定义值应正确设置', () {
        final config = AiConfig(
          modelType: ModelType.yoloPose,
          modelPath: '/path/to/model.onnx',
          confidenceThreshold: 0.5,
          nmsThreshold: 0.6,
          autoInferOnNext: true,
          labelSaveMode: LabelSaveMode.overwrite,
          numKeypoints: 17,
          keypointConfThreshold: 0.3,
        );

        expect(config.modelType, ModelType.yoloPose);
        expect(config.modelPath, '/path/to/model.onnx');
        expect(config.confidenceThreshold, 0.5);
        expect(config.nmsThreshold, 0.6);
        expect(config.autoInferOnNext, true);
        expect(config.labelSaveMode, LabelSaveMode.overwrite);
        expect(config.numKeypoints, 17);
        expect(config.keypointConfThreshold, 0.3);
      });
    });

    // ==================== JSON 序列化测试 ====================

    group('fromJson', () {
      test('应正确解析完整JSON', () {
        final json = {
          'modelType': 1, // yoloPose
          'modelPath': '/model.onnx',
          'confidenceThreshold': 0.4,
          'nmsThreshold': 0.5,
          'autoInferOnNext': true,
          'labelSaveMode': 1, // overwrite
          'numKeypoints': 17,
          'keypointConfThreshold': 0.6,
          'classIdOffset': 3,
        };

        final config = AiConfig.fromJson(json);

        expect(config.modelType, ModelType.yoloPose);
        expect(config.modelPath, '/model.onnx');
        expect(config.confidenceThreshold, 0.4);
        expect(config.nmsThreshold, 0.5);
        expect(config.autoInferOnNext, true);
        expect(config.labelSaveMode, LabelSaveMode.overwrite);
        expect(config.numKeypoints, 17);
        expect(config.keypointConfThreshold, 0.6);
        expect(config.classIdOffset, 3);
      });

      test('缺少字段时应使用默认值', () {
        final json = <String, dynamic>{};

        final config = AiConfig.fromJson(json);

        expect(config.modelType, ModelType.yolo);
        expect(config.modelPath, '');
        expect(config.confidenceThreshold, 0.25);
        expect(config.nmsThreshold, 0.45);
        expect(config.autoInferOnNext, false);
        expect(config.labelSaveMode, LabelSaveMode.append);
        expect(config.numKeypoints, 0);
        expect(config.keypointConfThreshold, 0.5);
        expect(config.classIdOffset, 0);
      });

      test('null字段应使用默认值', () {
        final json = {
          'modelType': null,
          'modelPath': null,
          'confidenceThreshold': null,
          'nmsThreshold': null,
          'autoInferOnNext': null,
          'labelSaveMode': null,
          'numKeypoints': null,
          'keypointConfThreshold': null,
          'classIdOffset': null,
        };

        final config = AiConfig.fromJson(json);

        expect(config.modelType, ModelType.yolo);
        expect(config.modelPath, '');
        expect(config.confidenceThreshold, 0.25);
        expect(config.nmsThreshold, 0.45);
        expect(config.classIdOffset, 0);
      });

      test('整数阈值应正确转换为double', () {
        final json = {
          'confidenceThreshold': 1, // 整数
          'nmsThreshold': 0, // 整数
        };

        final config = AiConfig.fromJson(json);

        expect(config.confidenceThreshold, 1.0);
        expect(config.nmsThreshold, 0.0);
      });
    });

    group('toJson', () {
      test('应正确序列化为JSON', () {
        final config = AiConfig(
          modelType: ModelType.yoloPose,
          modelPath: '/test/model.onnx',
          confidenceThreshold: 0.35,
          nmsThreshold: 0.55,
          autoInferOnNext: true,
          labelSaveMode: LabelSaveMode.overwrite,
          numKeypoints: 17,
          keypointConfThreshold: 0.4,
          classIdOffset: 2,
        );

        final json = config.toJson();

        expect(json['modelType'], 1); // yoloPose.index
        expect(json['modelPath'], '/test/model.onnx');
        expect(json['confidenceThreshold'], 0.35);
        expect(json['nmsThreshold'], 0.55);
        expect(json['autoInferOnNext'], true);
        expect(json['labelSaveMode'], 1); // overwrite.index
        expect(json['numKeypoints'], 17);
        expect(json['keypointConfThreshold'], 0.4);
        expect(json['classIdOffset'], 2);
      });

      test('JSON往返转换应保持数据一致', () {
        final original = AiConfig(
          modelType: ModelType.yoloPose,
          modelPath: '/model.onnx',
          confidenceThreshold: 0.3,
          nmsThreshold: 0.4,
          autoInferOnNext: true,
          labelSaveMode: LabelSaveMode.overwrite,
          numKeypoints: 21,
          keypointConfThreshold: 0.6,
          classIdOffset: 5,
        );

        final json = original.toJson();
        final restored = AiConfig.fromJson(json);

        expect(restored.modelType, original.modelType);
        expect(restored.modelPath, original.modelPath);
        expect(restored.confidenceThreshold, original.confidenceThreshold);
        expect(restored.nmsThreshold, original.nmsThreshold);
        expect(restored.autoInferOnNext, original.autoInferOnNext);
        expect(restored.labelSaveMode, original.labelSaveMode);
        expect(restored.numKeypoints, original.numKeypoints);
        expect(restored.keypointConfThreshold, original.keypointConfThreshold);
        expect(restored.classIdOffset, original.classIdOffset);
      });
    });

    // ==================== copyWith 测试 ====================

    group('copyWith', () {
      test('应创建具有新值的副本', () {
        final original = AiConfig(
          modelType: ModelType.yolo,
          modelPath: '/old/model.onnx',
          confidenceThreshold: 0.25,
          classIdOffset: 1,
        );

        final copy = original.copyWith(
          modelType: ModelType.yoloPose,
          confidenceThreshold: 0.5,
          classIdOffset: 4,
        );

        expect(copy.modelType, ModelType.yoloPose);
        expect(copy.modelPath, '/old/model.onnx'); // 未修改
        expect(copy.confidenceThreshold, 0.5);
        expect(copy.classIdOffset, 4);
      });

      test('不传参数应创建相同副本', () {
        final original = AiConfig(
          modelType: ModelType.yoloPose,
          modelPath: '/model.onnx',
          confidenceThreshold: 0.4,
          nmsThreshold: 0.5,
          autoInferOnNext: true,
          labelSaveMode: LabelSaveMode.overwrite,
          numKeypoints: 17,
          keypointConfThreshold: 0.6,
          classIdOffset: 2,
        );

        final copy = original.copyWith();

        expect(copy.modelType, original.modelType);
        expect(copy.modelPath, original.modelPath);
        expect(copy.confidenceThreshold, original.confidenceThreshold);
        expect(copy.nmsThreshold, original.nmsThreshold);
        expect(copy.autoInferOnNext, original.autoInferOnNext);
        expect(copy.labelSaveMode, original.labelSaveMode);
        expect(copy.numKeypoints, original.numKeypoints);
        expect(copy.keypointConfThreshold, original.keypointConfThreshold);
        expect(copy.classIdOffset, original.classIdOffset);
      });
    });

    // ==================== 辅助属性测试 ====================

    group('hasModel', () {
      test('有模型路径时应返回true', () {
        final config = AiConfig(modelPath: '/path/to/model.onnx');

        expect(config.hasModel, true);
      });

      test('空模型路径时应返回false', () {
        final config = AiConfig(modelPath: '');

        expect(config.hasModel, false);
      });

      test('默认应返回false', () {
        final config = AiConfig();

        expect(config.hasModel, false);
      });
    });

    group('hasKeypoints', () {
      test('yoloPose模型应返回true', () {
        final config = AiConfig(modelType: ModelType.yoloPose);

        expect(config.hasKeypoints, true);
      });

      test('yolo模型应返回false', () {
        final config = AiConfig(modelType: ModelType.yolo);

        expect(config.hasKeypoints, false);
      });
    });
  });

  // ==================== 枚举测试 ====================

  group('ModelType 枚举测试', () {
    test('枚举值应正确定义', () {
      expect(ModelType.yolo.index, 0);
      expect(ModelType.yoloPose.index, 1);
    });

    test('枚举数量应为2', () {
      expect(ModelType.values.length, 2);
    });
  });

  group('LabelSaveMode 枚举测试', () {
    test('枚举值应正确定义', () {
      expect(LabelSaveMode.append.index, 0);
      expect(LabelSaveMode.overwrite.index, 1);
    });

    test('枚举数量应为2', () {
      expect(LabelSaveMode.values.length, 2);
    });
  });
}
