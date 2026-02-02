import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/models/project.dart';

/// Project 模型单元测试
void main() {
  group('Project 模型测试', () {
    // ==================== 构造函数测试 ====================

    group('构造函数', () {
      test('默认值应正确初始化', () {
        final project = Project(
          imagePath: '/images',
          labelPath: '/labels',
        );

        expect(project.imagePath, '/images');
        expect(project.labelPath, '/labels');
        expect(project.imageFiles, isEmpty);
        expect(project.currentIndex, 0);
      });

      test('自定义值应正确设置', () {
        final imageFiles = [
          '/images/001.jpg',
          '/images/002.jpg',
          '/images/003.jpg'
        ];

        final project = Project(
          imagePath: '/images',
          labelPath: '/labels',
          imageFiles: imageFiles,
          currentIndex: 1,
        );

        expect(project.imageFiles.length, 3);
        expect(project.currentIndex, 1);
      });
    });

    // ==================== 路径属性测试 ====================

    group('currentImagePath', () {
      test('有图片时应返回当前图片路径', () {
        final project = Project(
          imagePath: '/images',
          labelPath: '/labels',
          imageFiles: ['/images/001.jpg', '/images/002.jpg'],
          currentIndex: 0,
        );

        expect(project.currentImagePath, '/images/001.jpg');
      });

      test('索引改变后应返回对应路径', () {
        final project = Project(
          imagePath: '/images',
          labelPath: '/labels',
          imageFiles: ['/images/001.jpg', '/images/002.jpg'],
          currentIndex: 1,
        );

        expect(project.currentImagePath, '/images/002.jpg');
      });

      test('无图片时应返回null', () {
        final project = Project(
          imagePath: '/images',
          labelPath: '/labels',
        );

        expect(project.currentImagePath, isNull);
      });

      test('索引越界时应返回null', () {
        final project = Project(
          imagePath: '/images',
          labelPath: '/labels',
          imageFiles: ['/images/001.jpg'],
          currentIndex: 5, // 越界
        );

        expect(project.currentImagePath, isNull);
      });

      test('负索引时应返回null', () {
        final project = Project(
          imagePath: '/images',
          labelPath: '/labels',
          imageFiles: ['/images/001.jpg'],
          currentIndex: -1, // 负数
        );

        expect(project.currentImagePath, isNull);
      });
    });

    group('currentLabelPath', () {
      test('应正确生成标签文件路径', () {
        final project = Project(
          imagePath: '/images',
          labelPath: '/labels',
          imageFiles: ['/images/test.jpg'],
          currentIndex: 0,
        );

        expect(project.currentLabelPath, '/labels/test.txt');
      });

      test('应正确处理不同图片扩展名', () {
        final project = Project(
          imagePath: '/images',
          labelPath: '/labels',
          imageFiles: ['/images/photo.png'],
          currentIndex: 0,
        );

        expect(project.currentLabelPath, '/labels/photo.txt');
      });

      test('应正确处理无扩展名的文件', () {
        final project = Project(
          imagePath: '/images',
          labelPath: '/labels',
          imageFiles: ['/images/noext'],
          currentIndex: 0,
        );

        expect(project.currentLabelPath, '/labels/noext.txt');
      });

      test('应正确处理多个点的文件名', () {
        final project = Project(
          imagePath: '/images',
          labelPath: '/labels',
          imageFiles: ['/images/test.name.with.dots.jpg'],
          currentIndex: 0,
        );

        expect(project.currentLabelPath, '/labels/test.name.with.dots.txt');
      });

      test('无图片时应返回null', () {
        final project = Project(
          imagePath: '/images',
          labelPath: '/labels',
        );

        expect(project.currentLabelPath, isNull);
      });
    });

    // ==================== 状态属性测试 ====================

    group('hasImages', () {
      test('有图片时应返回true', () {
        final project = Project(
          imagePath: '/images',
          labelPath: '/labels',
          imageFiles: ['/images/001.jpg'],
        );

        expect(project.hasImages, true);
      });

      test('无图片时应返回false', () {
        final project = Project(
          imagePath: '/images',
          labelPath: '/labels',
        );

        expect(project.hasImages, false);
      });
    });

    group('canGoPrevious', () {
      test('在第一张图时应返回false', () {
        final project = Project(
          imagePath: '/images',
          labelPath: '/labels',
          imageFiles: ['/images/001.jpg', '/images/002.jpg'],
          currentIndex: 0,
        );

        expect(project.canGoPrevious, false);
      });

      test('不在第一张图时应返回true', () {
        final project = Project(
          imagePath: '/images',
          labelPath: '/labels',
          imageFiles: ['/images/001.jpg', '/images/002.jpg'],
          currentIndex: 1,
        );

        expect(project.canGoPrevious, true);
      });

      test('只有一张图时应返回false', () {
        final project = Project(
          imagePath: '/images',
          labelPath: '/labels',
          imageFiles: ['/images/001.jpg'],
          currentIndex: 0,
        );

        expect(project.canGoPrevious, false);
      });
    });

    group('canGoNext', () {
      test('在最后一张图时应返回false', () {
        final project = Project(
          imagePath: '/images',
          labelPath: '/labels',
          imageFiles: ['/images/001.jpg', '/images/002.jpg'],
          currentIndex: 1,
        );

        expect(project.canGoNext, false);
      });

      test('不在最后一张图时应返回true', () {
        final project = Project(
          imagePath: '/images',
          labelPath: '/labels',
          imageFiles: ['/images/001.jpg', '/images/002.jpg'],
          currentIndex: 0,
        );

        expect(project.canGoNext, true);
      });

      test('只有一张图时应返回false', () {
        final project = Project(
          imagePath: '/images',
          labelPath: '/labels',
          imageFiles: ['/images/001.jpg'],
          currentIndex: 0,
        );

        expect(project.canGoNext, false);
      });
    });

    // ==================== 导航方法测试 ====================

    group('nextImage', () {
      test('应前进到下一张图', () {
        final project = Project(
          imagePath: '/images',
          labelPath: '/labels',
          imageFiles: ['/images/001.jpg', '/images/002.jpg', '/images/003.jpg'],
          currentIndex: 0,
        );

        project.nextImage();

        expect(project.currentIndex, 1);
      });

      test('连续调用应依次前进', () {
        final project = Project(
          imagePath: '/images',
          labelPath: '/labels',
          imageFiles: ['/images/001.jpg', '/images/002.jpg', '/images/003.jpg'],
          currentIndex: 0,
        );

        project.nextImage();
        project.nextImage();

        expect(project.currentIndex, 2);
      });

      test('已在最后一张时不应前进', () {
        final project = Project(
          imagePath: '/images',
          labelPath: '/labels',
          imageFiles: ['/images/001.jpg', '/images/002.jpg'],
          currentIndex: 1,
        );

        project.nextImage();

        expect(project.currentIndex, 1); // 保持不变
      });

      test('空列表时不应改变索引', () {
        final project = Project(
          imagePath: '/images',
          labelPath: '/labels',
          currentIndex: 0,
        );

        project.nextImage();

        expect(project.currentIndex, 0);
      });
    });

    group('previousImage', () {
      test('应后退到上一张图', () {
        final project = Project(
          imagePath: '/images',
          labelPath: '/labels',
          imageFiles: ['/images/001.jpg', '/images/002.jpg', '/images/003.jpg'],
          currentIndex: 2,
        );

        project.previousImage();

        expect(project.currentIndex, 1);
      });

      test('连续调用应依次后退', () {
        final project = Project(
          imagePath: '/images',
          labelPath: '/labels',
          imageFiles: ['/images/001.jpg', '/images/002.jpg', '/images/003.jpg'],
          currentIndex: 2,
        );

        project.previousImage();
        project.previousImage();

        expect(project.currentIndex, 0);
      });

      test('已在第一张时不应后退', () {
        final project = Project(
          imagePath: '/images',
          labelPath: '/labels',
          imageFiles: ['/images/001.jpg', '/images/002.jpg'],
          currentIndex: 0,
        );

        project.previousImage();

        expect(project.currentIndex, 0); // 保持不变
      });

      test('空列表时不应改变索引', () {
        final project = Project(
          imagePath: '/images',
          labelPath: '/labels',
          currentIndex: 0,
        );

        project.previousImage();

        expect(project.currentIndex, 0);
      });
    });

    // ==================== 边界条件测试 ====================

    group('边界条件', () {
      test('大量图片导航应正常工作', () {
        final imageFiles = List.generate(1000, (i) => '/images/$i.jpg');

        final project = Project(
          imagePath: '/images',
          labelPath: '/labels',
          imageFiles: imageFiles,
          currentIndex: 0,
        );

        // 前进到中间
        for (int i = 0; i < 500; i++) {
          project.nextImage();
        }
        expect(project.currentIndex, 500);

        // 后退一些
        for (int i = 0; i < 100; i++) {
          project.previousImage();
        }
        expect(project.currentIndex, 400);
      });

      test('索引直接设置应工作', () {
        final project = Project(
          imagePath: '/images',
          labelPath: '/labels',
          imageFiles: ['/images/001.jpg', '/images/002.jpg', '/images/003.jpg'],
          currentIndex: 0,
        );

        project.currentIndex = 2;

        expect(project.currentIndex, 2);
        expect(project.currentImagePath, '/images/003.jpg');
      });

      test('应处理特殊字符的文件路径', () {
        final project = Project(
          imagePath: '/path with spaces/images',
          labelPath: '/path with spaces/labels',
          imageFiles: ['/path with spaces/images/测试图片.jpg'],
          currentIndex: 0,
        );

        expect(project.currentImagePath, '/path with spaces/images/测试图片.jpg');
        expect(project.currentLabelPath, '/path with spaces/labels/测试图片.txt');
      });
    });

    // ==================== 不可变属性测试 ====================

    group('不可变属性', () {
      test('imagePath应不可修改', () {
        final project = Project(
          imagePath: '/original',
          labelPath: '/labels',
        );

        // imagePath 是 final，无法修改
        expect(project.imagePath, '/original');
      });

      test('labelPath应不可修改', () {
        final project = Project(
          imagePath: '/images',
          labelPath: '/original',
        );

        // labelPath 是 final，无法修改
        expect(project.labelPath, '/original');
      });

      test('imageFiles应不可修改（列表引用）', () {
        final project = Project(
          imagePath: '/images',
          labelPath: '/labels',
          imageFiles: ['/images/001.jpg'],
        );

        // imageFiles 是 final，但列表内容可能可修改
        expect(project.imageFiles.length, 1);
      });
    });
  });
}
