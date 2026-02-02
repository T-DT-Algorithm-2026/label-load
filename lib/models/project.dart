/// 项目运行时状态
///
/// 保存当前打开项目的图像列表和当前浏览位置。
/// 不包含配置信息，配置信息存储在 [ProjectConfig]。
class Project {
  /// 图片目录路径
  final String imagePath;

  /// 标签目录路径
  final String labelPath;

  /// 图片文件完整路径列表
  final List<String> imageFiles;

  /// 当前图片索引
  int currentIndex;

  Project({
    required this.imagePath,
    required this.labelPath,
    this.imageFiles = const [],
    this.currentIndex = 0,
  });

  /// 当前图片完整路径
  ///
  /// 当索引越界或图片列表为空时返回 null。
  String? get currentImagePath {
    if (currentIndex < 0 || currentIndex >= imageFiles.length) return null;
    return imageFiles[currentIndex];
  }

  /// 当前标签文件完整路径
  ///
  /// 使用当前图片文件名，将扩展名替换为 `.txt`；无扩展名时直接追加。
  String? get currentLabelPath {
    final imgPath = currentImagePath;
    if (imgPath == null) return null;

    // 将图片扩展名替换为 .txt
    final baseName = imgPath.split('/').last;
    final nameWithoutExt = baseName.contains('.')
        ? baseName.substring(0, baseName.lastIndexOf('.'))
        : baseName;
    return '$labelPath/$nameWithoutExt.txt';
  }

  /// 是否有图片
  bool get hasImages => imageFiles.isNotEmpty;

  /// 是否可以向前导航
  bool get canGoPrevious => currentIndex > 0;

  /// 是否可以向后导航
  bool get canGoNext => currentIndex < imageFiles.length - 1;

  /// 切换到下一张图片
  void nextImage() {
    if (canGoNext) currentIndex++;
  }

  /// 切换到上一张图片
  void previousImage() {
    if (canGoPrevious) currentIndex--;
  }
}
